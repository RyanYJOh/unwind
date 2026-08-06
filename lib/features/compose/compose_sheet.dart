import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Material, MaterialType, TextField, InputDecoration, InputBorder;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../today/providers.dart';
import 'date_bar.dart';

/// §6.3 입력 시트 — FAB 탭 시 하단에서 올라오고 키보드가 즉시 함께 올라온다.
///
/// - 연속 입력이 기본: 엔터 → 저장 + 입력창 비움 + 시트·키보드·날짜 유지
/// - 시트를 닫았다 열면 날짜는 기본값(오늘, 취침 후엔 내일)으로 리셋
/// - 편집 모드([existing] 전달 시): 저장 후 닫힘
Future<void> showComposeSheet(BuildContext context, {Todo? existing}) {
  return Navigator.of(context, rootNavigator: true).push(
    _ComposeSheetRoute(existing: existing),
  );
}

/// 커스텀 모달 라우트 — Material 바텀시트 대신 §9.4 시트 모션(320ms, theme)
class _ComposeSheetRoute extends PopupRoute<void> {
  final Todo? existing;
  _ComposeSheetRoute({this.existing});

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
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: UnwindMotion.theme)),
      child: ComposeSheet(existing: existing),
    );
  }
}

class ComposeSheet extends ConsumerStatefulWidget {
  final Todo? existing;
  const ComposeSheet({super.key, this.existing});

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

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _dateKey = widget.existing?.date ??
        ref.read(composeDefaultDateProvider); // 취침 후엔 내일 (§6.1)
    if (widget.existing != null) {
      _titleController.text = widget.existing!.title;
      _memoController.text = widget.existing!.memo ?? '';
      _memoOpen = widget.existing!.memo?.isNotEmpty == true;
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
    final memo = _memoController.text.trim();
    final repo = ref.read(todoRepositoryProvider);

    if (_isEdit) {
      await repo.edit(widget.existing!,
          title: title, memo: memo.isEmpty ? null : memo);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await repo.add(
        title: title, memo: memo.isEmpty ? null : memo, date: _dateKey);

    // §6.3 함정 3: 연속 입력 — 입력창만 비우고 시트·키보드·날짜는 유지
    _titleController.clear();
    _memoController.clear();
    setState(() => _memoOpen = false);
    _titleFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(brightnessProvider);
    final colors = lerpRamp(t);
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
                    top: Radius.circular(UnwindRadius.lg)),
                boxShadow: [
                  BoxShadow(
                      color: colors.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, -6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (asleep && !_isEdit)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: UnwindSpacing.s24,
                          right: UnwindSpacing.s24,
                          top: UnwindSpacing.s16),
                      child: Text(
                        'Lumi가 자고 있어요. 내일 방에 놓아둘게요',
                        style: UnwindType.caption.copyWith(
                            color: colors.textSecondary,
                            decoration: TextDecoration.none),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(UnwindSpacing.s24,
                        UnwindSpacing.s16, UnwindSpacing.s24, 0),
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      autofocus: true, // §6.3 키보드 즉시
                      maxLength: 200,
                      style: UnwindType.body
                          .copyWith(color: colors.textPrimarySnap),
                      cursorColor: colors.lamp,
                      decoration: InputDecoration(
                        hintText: '할 일',
                        hintStyle: UnwindType.body
                            .copyWith(color: colors.textMuted),
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
                          horizontal: UnwindSpacing.s24),
                      child: TextField(
                        controller: _memoController,
                        maxLength: 2000,
                        maxLines: 3,
                        minLines: 1,
                        style: UnwindType.label
                            .copyWith(color: colors.textSecondary),
                        cursorColor: colors.lamp,
                        decoration: InputDecoration(
                          hintText: '메모',
                          hintStyle: UnwindType.label
                              .copyWith(color: colors.textMuted),
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
                            vertical: UnwindSpacing.s8),
                        child: Text('메모 추가',
                            style: UnwindType.caption.copyWith(
                                color: colors.textMuted,
                                decoration: TextDecoration.none)),
                      ),
                    ),
                  // TODO(unwind): 반복 규칙 UI — M2 (§6.3 구조의 세 번째 접힘 영역)
                  if (_calendarOpen)
                    SizedBox(
                      height: 180,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: parseDayKey(_dateKey),
                        minimumDate: parseDayKey(todayKey),
                        maximumDate:
                            parseDayKey(todayKey).add(const Duration(days: 365)),
                        onDateTimeChanged: (d) =>
                            setState(() => _dateKey = dayKey(d)),
                      ),
                    ),
                  // 플로팅 날짜 바 — 키보드 바로 위 (§6.3)
                  DateBarHost(
                    dateKey: _dateKey,
                    todayKey: todayKey,
                    haptics: haptics,
                    isEdit: _isEdit,
                    onDateChanged: (d) => setState(() => _dateKey = d),
                    onCalendarTap: () =>
                        setState(() => _calendarOpen = !_calendarOpen),
                    onClose: () => Navigator.of(context).pop(),
                    onSaveEdit: _save,
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

/// 날짜 바 래퍼 — 편집 모드에서는 저장 버튼을 함께 노출
class DateBarHost extends StatelessWidget {
  final String dateKey;
  final String todayKey;
  final dynamic haptics;
  final bool isEdit;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onCalendarTap;
  final VoidCallback onClose;
  final VoidCallback onSaveEdit;

  const DateBarHost({
    super.key,
    required this.dateKey,
    required this.todayKey,
    required this.haptics,
    required this.isEdit,
    required this.onDateChanged,
    required this.onCalendarTap,
    required this.onClose,
    required this.onSaveEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEdit)
          GestureDetector(
            onTap: onSaveEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: UnwindSpacing.s8),
              child: Center(
                child: Text('저장', // 버튼은 동사로 (§8.5)
                    style: UnwindType.bodyStrong.copyWith(
                        color: colors.lamp,
                        decoration: TextDecoration.none)),
              ),
            ),
          ),
        DateBar(
          dateKey: dateKey,
          todayKey: todayKey,
          onDateChanged: onDateChanged,
          onClose: onClose,
          onCalendarTap: onCalendarTap,
          haptics: haptics,
        ),
      ],
    );
  }
}
