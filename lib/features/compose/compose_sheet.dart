import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Icons, MaterialLocalizations, TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../ui/ui.dart';
import '../premium/paywall_screen.dart';
import '../premium/premium_providers.dart';
import '../today/providers.dart';
import '../today/pull_cord_coach.dart';
import 'date_bar.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.3 입력 시트 — FAB 탭 시 하단에서 올라오고 키보드가 즉시 함께 올라온다.
///
/// - 저장: 입력창 비움 + 시트·날짜 유지, 키보드는 닫힘
/// - 시트를 닫았다 열면 날짜는 기본값(오늘, 취침 후엔 내일)으로 리셋
/// - 편집 모드([existing] 전달 시): 저장 후 닫힘
Future<void> showComposeSheet(
  BuildContext context, {
  Todo? existing,
  String? initialDate,
}) {
  return showUnwindSheet<void>(
    context,
    builder: (_) => ComposeSheet(existing: existing, initialDate: initialDate),
  );
}

class ComposeSheet extends ConsumerStatefulWidget {
  final Todo? existing;
  final String? initialDate;
  const ComposeSheet({super.key, this.existing, this.initialDate});

  @override
  ConsumerState<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<ComposeSheet> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  final _titleFocus = FocusNode();
  late String _dateKey;
  bool _calendarOpen = false;
  bool _autoDefer = false;
  int? _scheduledTimeMinutes;
  bool _timeOpen = false;

  /// 저장 CTA 활성 여부 — 제목이 비면 누를 수 없다
  bool _canSave = false;

  /// §6.3 반복 (접힌 상태). null = 반복 없음.
  RecurrenceRule? _rule;

  bool get _isEdit => widget.existing != null;

  String _ordinal(int day) {
    final mod100 = day % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }

  String _weeklyLabel(AppLocalizations l10n) {
    final date = parseDayKey(_dateKey);
    final weekday = l10n.weekdaysLong.split(',')[date.weekday - 1];
    return l10n.repeatEveryWeekday(weekday);
  }

  String _monthlyLabel(BuildContext context, AppLocalizations l10n) {
    final day = parseDayKey(_dateKey).day;
    final locale = Localizations.localeOf(context).languageCode;
    return l10n.repeatEveryMonthDay(locale == 'en' ? _ordinal(day) : '$day');
  }

  @override
  void initState() {
    super.initState();
    _dateKey =
        widget.existing?.date ??
        widget.initialDate ??
        ref.read(composeDefaultDateProvider); // 취침 후엔 내일 (§6.1)
    if (widget.existing != null) {
      _titleController.text = widget.existing!.title;
      _memoController.text = widget.existing!.memo ?? '';
      _autoDefer =
          widget.existing!.recurrenceId == null && widget.existing!.autoDefer;
      _scheduledTimeMinutes = widget.existing!.scheduledTimeMinutes;
    }
    _canSave = _titleController.text.trim().isNotEmpty;
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    final can = _titleController.text.trim().isNotEmpty;
    if (can != _canSave && mounted) setState(() => _canSave = can);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _memoController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    FocusScope.of(context).unfocus();
    final memo = _memoController.text.trim();
    final repo = ref.read(todoRepositoryProvider);

    if (_isEdit) {
      await repo.edit(
        widget.existing!,
        title: title,
        memo: memo.isEmpty ? null : memo,
        date: _dateKey,
        autoDefer: _autoDefer,
        scheduledTimeMinutes: _scheduledTimeMinutes,
        updateScheduledTime: true,
      );
      final recurrenceId = widget.existing!.recurrenceId;
      if (recurrenceId != null) {
        await ref
            .read(databaseProvider)
            .recurrenceDao
            .updateRule(
              recurrenceId,
              memo: memo.isEmpty ? null : memo,
              fromDate: widget.existing!.date,
              scheduledTimeMinutes: _scheduledTimeMinutes,
              updateScheduledTime: true,
            );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (_rule != null) {
      // 반복 규칙 생성 → 인스턴스는 전개 서비스가 materialize (§4.2)
      final db = ref.read(databaseProvider);

      // 무료 티어는 반복 규칙 3개까지 (수익화 2026-08-22) — 네 번째를
      // 저장하려는 바로 그 순간이 페이월의 자리다. 시트는 열어 둔다:
      // 구독하고 돌아오면 쓰던 내용 그대로 저장할 수 있다.
      // (온보딩은 이 시트를 거치지 않아 게이트 밖 — 황금 경로를 막지 않는다)
      if (!ref.read(premiumProvider)) {
        final activeRules = await db.recurrenceDao.getActive();
        if (activeRules.length >= kFreeRecurrenceLimit) {
          if (mounted) await showPaywall(context);
          return;
        }
      }

      final d = parseDayKey(_dateKey);
      await db.recurrenceDao.create(
        title: title,
        memo: memo.isEmpty ? null : memo,
        rule: _rule!,
        weekdayMask: _rule == RecurrenceRule.weekly
            ? 1 << (d.weekday - 1)
            : null,
        dayOfMonth: _rule == RecurrenceRule.monthly ? d.day : null,
        startDate: _dateKey,
        scheduledTimeMinutes: _scheduledTimeMinutes,
      );
      await ref
          .read(recurrenceExpanderProvider)
          .expand(ref.read(todayKeyProvider));
    } else {
      await repo.add(
        title: title,
        memo: memo.isEmpty ? null : memo,
        date: _dateKey,
        autoDefer: _autoDefer,
        scheduledTimeMinutes: _scheduledTimeMinutes,
      );
    }

    // 저장하면 키보드와 함께 시트도 닫힌다 (개정 2026-08-12).
    // 확인 토스트는 없앴다 — 방에 등이 하나 늘어난 것이 곧 피드백이다.
    final coach = ref.read(pullCordCoachVisibleProvider.notifier);
    final date = _dateKey;
    if (mounted) {
      ref.read(hapticsProvider).success();
      Navigator.of(context).pop();
    }
    await coach.onNewTodoAdded(date);
  }

  List<(String, RecurrenceRule?)> _repeatOptions(
    BuildContext context,
    AppLocalizations l10n,
  ) => [
    (l10n.repeatNone, null),
    (l10n.repeatDaily, RecurrenceRule.daily),
    (l10n.repeatWeekdays, RecurrenceRule.weekdays),
    (_weeklyLabel(l10n), RecurrenceRule.weekly),
    (_monthlyLabel(context, l10n), RecurrenceRule.monthly),
  ];

  String _timeText(BuildContext context) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(
          hour: _scheduledTimeMinutes! ~/ 60,
          minute: _scheduledTimeMinutes! % 60,
        ),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayKey = ref.watch(todayKeyProvider);
    final asleep = ref.watch(isAsleepProvider);
    final recurring = _rule != null || widget.existing?.recurrenceId != null;

    return UnwindSheet(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(
        UnwindSpacing.s20,
        0,
        UnwindSpacing.s20,
        UnwindSpacing.s8,
      ),
      bottomBar: DateBar(
        dateKey: _dateKey,
        todayKey: todayKey,
        onDateChanged: (d) => setState(() => _dateKey = d),
        onCalendarTap: () => setState(() => _calendarOpen = !_calendarOpen),
        onSave: _save,
        canSave: _canSave,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (asleep && !_isEdit) ...[
              Text(
                l10n.toddSleepingNotice,
                style: UnwindType.caption.copyWith(
                  color: UnwindColors.textSecondary,
                ),
              ),
              const SizedBox(height: UnwindSpacing.s16),
            ],
            // ── 무엇을 ─────────────────────────────────────────
            // 주 입력 — 시트의 주인공이라 테두리 없이 크게
            UnwindTextField(
              controller: _titleController,
              focusNode: _titleFocus,
              hint: l10n.taskHint,
              autofocus: true, // §6.3 키보드 즉시
              maxLength: 200,
              bare: true,
              textStyle: UnwindType.headline,
              // 첫 글자 자동 대문자 (개정 2026-08-15)
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: UnwindSpacing.s8),
            // 메모 — 항상 열려 있는 진짜 입력란 (개정 2026-08-15).
            // 이전의 "탭하면 펼쳐지는 라벨"은 눌러도 입력란이 바로 활성화되지
            // 않았고, 라벨("Add a note")과 힌트("Note")가 이중으로 보였다.
            // 힌트 하나("Add a note")를 단 필드로 통일 — 탭하면 즉시 입력.
            UnwindTextField(
              controller: _memoController,
              hint: l10n.addMemo,
              maxLength: 2000,
              minLines: 1,
              maxLines: 3,
              bare: true,
              textStyle: UnwindType.body,
              // 첫 글자 자동 대문자 (개정 2026-08-15)
              textCapitalization: TextCapitalization.sentences,
            ),

            // ── 언제 ───────────────────────────────────────────
            const _SectionGap(),
            UnwindListRow(
              label: l10n.taskTime,
              padding: _rowPadding,
              onTap: () => setState(() {
                _timeOpen = !_timeOpen;
                if (_timeOpen) _scheduledTimeMinutes ??= 9 * 60;
              }),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _scheduledTimeMinutes == null
                        ? l10n.taskTimeNone
                        : _timeText(context),
                    style: UnwindType.label.copyWith(
                      color: _scheduledTimeMinutes == null
                          ? UnwindColors.textMuted
                          : UnwindColors.accent,
                    ),
                  ),
                  if (_scheduledTimeMinutes != null)
                    UnwindIconButton(
                      icon: Icons.close_rounded,
                      iconSize: 18,
                      size: UnwindTouch.minTarget - UnwindSpacing.s8,
                      semanticLabel: l10n.taskTimeNone,
                      onPressed: () => setState(() {
                        _scheduledTimeMinutes = null;
                        _timeOpen = false;
                      }),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: UnwindColors.textMuted,
                    ),
                ],
              ),
            ),
            if (_timeOpen)
              _PickerBox(
                height: 150,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    (_scheduledTimeMinutes ?? 9 * 60) ~/ 60,
                    (_scheduledTimeMinutes ?? 9 * 60) % 60,
                  ),
                  onDateTimeChanged: (value) => setState(() {
                    _scheduledTimeMinutes = value.hour * 60 + value.minute;
                  }),
                ),
              ),
            if (_calendarOpen)
              _PickerBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: parseDayKey(_dateKey),
                  minimumDate: parseDayKey(todayKey),
                  maximumDate: parseDayKey(
                    todayKey,
                  ).add(const Duration(days: 365)),
                  onDateTimeChanged: (d) =>
                      setState(() => _dateKey = dayKey(d)),
                ),
              ),

            // ── 못 끝내면 ──────────────────────────────────────
            const _SectionGap(),
            UnwindListRow.toggle(
              label: l10n.autoDeferTitle,
              caption: l10n.autoDeferSubtitle,
              padding: _rowPadding,
              value: _autoDefer,
              onChanged: recurring
                  ? null
                  : (v) => setState(() {
                      _autoDefer = v;
                      if (_autoDefer) _rule = null;
                    }),
            ),

            // ── 반복 ───────────────────────────────────────────
            if (!_isEdit) ...[
              const _SectionGap(),
              UnwindSectionLabel(
                l10n.repeatSection,
                padding: const EdgeInsets.only(bottom: UnwindSpacing.s8),
              ),
              // 한 줄로만 늘어놓고 가로로 넘긴다 (개정 2026-08-13) —
              // 여러 줄로 접히면 키보드까지 올라왔을 때 시트가 화면을 넘긴다.
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _repeatOptions(context, l10n).length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: UnwindSpacing.s8),
                  itemBuilder: (context, i) {
                    final (label, rule) = _repeatOptions(context, l10n)[i];
                    return UnwindChip(
                      label: label,
                      selected: _rule == rule,
                      onTap: () => setState(() {
                        _rule = _rule == rule ? null : rule;
                        if (_rule != null) _autoDefer = false;
                      }),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: UnwindSpacing.s8),
          ],
        ),
      ),
    );
  }
}

/// 시트 안의 행은 좌우 여백을 시트가 이미 갖고 있어 0으로 둔다.
const _rowPadding = EdgeInsets.symmetric(vertical: UnwindSpacing.s4);

/// 영역 구분 — 여백 + 얇은 선 + 여백. 기능 묶음이 섞여 보이지 않게 한다.
/// 키보드까지 올라오면 시트가 화면을 넘겨서 s20 → s12로 줄였다 (2026-08-13).
class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: UnwindSpacing.s12),
    child: UnwindDivider(indent: 0),
  );
}

/// Cupertino 피커를 다크 팔레트 안에 앉힌다.
class _PickerBox extends StatelessWidget {
  final double height;
  final Widget child;

  const _PickerBox({required this.height, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: UnwindSpacing.s8),
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: UnwindColors.surfaceAlt,
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        border: Border.all(
          color: UnwindColors.border,
          width: UnwindStroke.base,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: UnwindColors.accent,
        ),
        child: child,
      ),
    ),
  );
}
