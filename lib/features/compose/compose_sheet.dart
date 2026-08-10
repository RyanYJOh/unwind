import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        Checkbox,
        Icons,
        InputBorder,
        InputDecoration,
        Material,
        MaterialLocalizations,
        MaterialType,
        TextField,
        TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/design_variant.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../widgets/top_toast.dart';
import '../today/providers.dart';
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
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(_ComposeSheetRoute(existing: existing, initialDate: initialDate));
}

/// 커스텀 모달 라우트 — Material 바텀시트 대신 §9.4 시트 모션(320ms, theme)
class _ComposeSheetRoute extends PopupRoute<void> {
  final Todo? existing;
  final String? initialDate;
  _ComposeSheetRoute({this.existing, this.initialDate});

  @override
  Color? get barrierColor => const Color(0x66000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '닫기';

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: UnwindMotion.sheetMs);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: UnwindMotion.theme)),
      child: ComposeSheet(existing: existing, initialDate: initialDate),
    );
  }
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
  bool _memoOpen = false;
  bool _calendarOpen = false;
  bool _autoDefer = false;
  int? _scheduledTimeMinutes;
  bool _timeOpen = false;

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
      _memoOpen = widget.existing!.memo?.isNotEmpty == true;
      _autoDefer =
          widget.existing!.recurrenceId == null && widget.existing!.autoDefer;
      _scheduledTimeMinutes = widget.existing!.scheduledTimeMinutes;
    }
  }

  @override
  void dispose() {
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

    // 추가 확인 토스트 — 푸시 알림 형태, 상단 (개편 2026-08-08)
    if (mounted) {
      showTopToast(
        context,
        title: title,
        body: AppLocalizations.of(context).toastTaskAdded,
      );
    }

    // 저장 후 시트는 유지하되 키보드는 닫는다.
    _titleController.clear();
    _memoController.clear();
    setState(() {
      _memoOpen = false;
      _calendarOpen = false;
      _rule = null;
      _autoDefer = false;
      _scheduledTimeMinutes = null;
      _timeOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(brightnessProvider);
    final colors = kRoomDesign == RoomDesign.darkGlow
        ? lerpRamp(1.0)
        : lerpRamp(t);
    final l10n = AppLocalizations.of(context);
    final todayKey = ref.watch(todayKeyProvider);
    final asleep = ref.watch(isAsleepProvider);
    final haptics = ref.watch(hapticsProvider);

    // §6.3 함정 2: viewInsets를 직접 읽어 Padding에 즉시 반영
    // (AnimatedPadding을 쓰면 iOS 키보드 곡선과 어긋난다 — 실기기 검증 필요)
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return UnwindTheme(
      colors: colors,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(UnwindRadius.lg),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (asleep && !_isEdit)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: UnwindSpacing.s24,
                                right: UnwindSpacing.s24,
                                top: UnwindSpacing.s16,
                              ),
                              child: Text(
                                l10n.lumiSleepingNotice,
                                style: UnwindType.caption.copyWith(
                                  color: colors.textSecondary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              UnwindSpacing.s24,
                              UnwindSpacing.s16,
                              UnwindSpacing.s24,
                              0,
                            ),
                            child: TextField(
                              controller: _titleController,
                              focusNode: _titleFocus,
                              autofocus: true, // §6.3 키보드 즉시
                              maxLength: 200,
                              style: UnwindType.body.copyWith(
                                color: colors.textPrimarySnap,
                              ),
                              cursorColor: colors.lamp,
                              decoration: InputDecoration(
                                hintText: l10n.taskHint,
                                hintStyle: UnwindType.body.copyWith(
                                  color: colors.textMuted,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _save(),
                              onEditingComplete: () {}, // 포커스 유지 (연속 입력)
                            ),
                          ),
                          // 메모 (선택, 접힌 상태 — §6.3 구조)
                          if (_memoOpen)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UnwindSpacing.s24,
                              ),
                              child: TextField(
                                controller: _memoController,
                                maxLength: 2000,
                                maxLines: 3,
                                minLines: 1,
                                style: UnwindType.label.copyWith(
                                  color: colors.textSecondary,
                                ),
                                cursorColor: colors.lamp,
                                decoration: InputDecoration(
                                  hintText: l10n.memoHint,
                                  hintStyle: UnwindType.label.copyWith(
                                    color: colors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => setState(() => _memoOpen = true),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: UnwindSpacing.s24,
                                  vertical: UnwindSpacing.s8,
                                ),
                                child: Text(
                                  l10n.addMemo,
                                  style: UnwindType.caption.copyWith(
                                    color: colors.textMuted,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UnwindSpacing.s16,
                              vertical: UnwindSpacing.s4,
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap:
                                  (_rule != null ||
                                      widget.existing?.recurrenceId != null)
                                  ? null
                                  : () => setState(() {
                                      _autoDefer = !_autoDefer;
                                      if (_autoDefer) _rule = null;
                                    }),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _autoDefer,
                                    activeColor: colors.lamp,
                                    checkColor: colors.textPrimaryDark,
                                    side: BorderSide(color: colors.border),
                                    onChanged:
                                        (_rule != null ||
                                            widget.existing?.recurrenceId !=
                                                null)
                                        ? null
                                        : (value) => setState(() {
                                            _autoDefer = value ?? false;
                                            if (_autoDefer) _rule = null;
                                          }),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.autoDeferTitle,
                                          style: UnwindType.label.copyWith(
                                            color: colors.textPrimarySnap,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                        Text(
                                          l10n.autoDeferSubtitle,
                                          style: UnwindType.caption.copyWith(
                                            color: colors.textMuted,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              _timeOpen = !_timeOpen;
                              _scheduledTimeMinutes ??= 9 * 60;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UnwindSpacing.s24,
                                vertical: UnwindSpacing.s12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.taskTime,
                                      style: UnwindType.label.copyWith(
                                        color: colors.textSecondary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _scheduledTimeMinutes == null
                                        ? l10n.taskTimeNone
                                        : MaterialLocalizations.of(
                                            context,
                                          ).formatTimeOfDay(
                                            TimeOfDay(
                                              hour:
                                                  _scheduledTimeMinutes! ~/ 60,
                                              minute:
                                                  _scheduledTimeMinutes! % 60,
                                            ),
                                            alwaysUse24HourFormat:
                                                MediaQuery.alwaysUse24HourFormatOf(
                                                  context,
                                                ),
                                          ),
                                    style: UnwindType.label.copyWith(
                                      color: _scheduledTimeMinutes == null
                                          ? colors.textMuted
                                          : colors.textPrimarySnap,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  if (_scheduledTimeMinutes != null)
                                    CupertinoButton(
                                      padding: const EdgeInsets.only(
                                        left: UnwindSpacing.s12,
                                      ),
                                      minimumSize: const Size(
                                        UnwindTouch.minTarget,
                                        UnwindTouch.minTarget,
                                      ),
                                      onPressed: () => setState(() {
                                        _scheduledTimeMinutes = null;
                                        _timeOpen = false;
                                      }),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_timeOpen)
                            SizedBox(
                              height: 150,
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                use24hFormat:
                                    MediaQuery.alwaysUse24HourFormatOf(context),
                                initialDateTime: DateTime(
                                  2000,
                                  1,
                                  1,
                                  (_scheduledTimeMinutes ?? 9 * 60) ~/ 60,
                                  (_scheduledTimeMinutes ?? 9 * 60) % 60,
                                ),
                                onDateTimeChanged: (value) => setState(() {
                                  _scheduledTimeMinutes =
                                      value.hour * 60 + value.minute;
                                }),
                              ),
                            ),
                          // 반복 (선택, 접힌 상태 — §6.3 구조). 편집 모드에서는 숨김.
                          if (!_isEdit)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UnwindSpacing.s24,
                                vertical: UnwindSpacing.s4,
                              ),
                              child: Wrap(
                                spacing: UnwindSpacing.s8,
                                runSpacing: UnwindSpacing.s4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  for (final (label, rule) in [
                                    (l10n.repeatNone, null),
                                    (l10n.repeatDaily, RecurrenceRule.daily),
                                    (
                                      l10n.repeatWeekdays,
                                      RecurrenceRule.weekdays,
                                    ),
                                    (_weeklyLabel(l10n), RecurrenceRule.weekly),
                                    (
                                      _monthlyLabel(context, l10n),
                                      RecurrenceRule.monthly,
                                    ),
                                  ])
                                    _RuleChip(
                                      label: label,
                                      selected: _rule == rule,
                                      colors: colors,
                                      onTap: () => setState(() {
                                        _rule = rule;
                                        if (rule != null) _autoDefer = false;
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          if (_calendarOpen)
                            SizedBox(
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
                        ],
                      ),
                    ),
                  ),
                  // 플로팅 날짜 바 — 키보드 바로 위 (§6.3)
                  DateBar(
                    dateKey: _dateKey,
                    todayKey: todayKey,
                    haptics: haptics,
                    onDateChanged: (d) => setState(() => _dateKey = d),
                    onCalendarTap: () =>
                        setState(() => _calendarOpen = !_calendarOpen),
                    onSave: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 반복 선택 칩 — 액센트는 lamp 하나뿐 (§8.1)
class _RuleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final UnwindColors colors;
  final VoidCallback onTap;

  const _RuleChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colors.lamp.withValues(alpha: 0.22)
              : colors.surfaceRaised,
          borderRadius: BorderRadius.circular(UnwindRadius.pill),
          border: Border.all(
            color: selected ? colors.lamp : colors.border,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnwindSpacing.s12,
            vertical: UnwindSpacing.s4,
          ),
          child: Text(
            label,
            style: UnwindType.caption.copyWith(
              color: selected ? colors.textPrimarySnap : colors.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
