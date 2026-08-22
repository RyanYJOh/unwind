import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_icon_button.dart';
import 'unwind_pressable.dart';

/// 월 그리드 달력 (2026-08-22) — 입력 시트의 날짜 선택.
///
/// 입력 시트는 키보드 위에 얹혀 좁으므로(§6.3 "높이는 계속 짧게"), 달력은
/// 인라인이 아니라 **별도 바텀시트**로 띄우는 전제로 만들었다 — 날짜 셀이
/// §12 터치 44pt를 온전히 갖는다. 주는 앱 규칙대로 월요일에 시작한다.
///
/// ui/ 규칙(§5.5)에 따라 l10n을 모른다 — 요일·월 라벨은 호출자가 넣는다.
class UnwindCalendar extends StatefulWidget {
  final DateTime selected;

  /// 논리적 오늘 (기상시간 기준 todayKey) — 링으로 표시
  final DateTime today;

  /// 고를 수 있는 범위 (양 끝 포함)
  final DateTime min;
  final DateTime max;

  /// 월~일 7개 라벨
  final List<String> weekdayLabels;

  /// 헤더 라벨 (예: "Aug 2026" / "2026년 8월")
  final String Function(int year, int month) monthLabel;

  final ValueChanged<DateTime> onPick;

  const UnwindCalendar({
    super.key,
    required this.selected,
    required this.today,
    required this.min,
    required this.max,
    required this.weekdayLabels,
    required this.monthLabel,
    required this.onPick,
  });

  @override
  State<UnwindCalendar> createState() => _UnwindCalendarState();
}

class _UnwindCalendarState extends State<UnwindCalendar> {
  late DateTime _month = DateTime(
    widget.selected.year,
    widget.selected.month,
  );

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  bool get _canPrev => _month.isAfter(_monthOf(widget.min));
  bool get _canNext => _month.isBefore(_monthOf(widget.max));

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(DateTime d) =>
      !d.isBefore(DateTime(widget.min.year, widget.min.month, widget.min.day)) &&
      !d.isAfter(DateTime(widget.max.year, widget.max.month, widget.max.day));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // 월요일 시작 (앱 규칙 §6.2) — 1일이 놓일 칸의 앞 공백 수
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final rowCount = ((leading + daysInMonth) / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 헤더 — ‹ 월 이름 ›
        Row(
          children: [
            UnwindIconButton(
              icon: Icons.chevron_left_rounded,
              semanticLabel: null,
              onPressed: _canPrev ? () => _shiftMonth(-1) : null,
            ),
            Expanded(
              child: Text(
                widget.monthLabel(_month.year, _month.month),
                textAlign: TextAlign.center,
                style: UnwindType.headline.copyWith(
                  color: UnwindColors.textPrimary,
                ),
              ),
            ),
            UnwindIconButton(
              icon: Icons.chevron_right_rounded,
              semanticLabel: null,
              onPressed: _canNext ? () => _shiftMonth(1) : null,
            ),
          ],
        ),
        const SizedBox(height: UnwindSpacing.s8),
        // 요일 줄
        Row(
          children: [
            for (final w in widget.weekdayLabels)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: UnwindType.caption.copyWith(
                    color: UnwindColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: UnwindSpacing.s4),
        for (var row = 0; row < rowCount; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _cell(row * 7 + col - leading + 1, daysInMonth)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: UnwindTouch.minTarget);
    }
    final date = DateTime(_month.year, _month.month, day);
    final enabled = _inRange(date);
    final selected = _sameDay(date, widget.selected);
    final isToday = _sameDay(date, widget.today);

    final Color fg;
    if (selected) {
      fg = UnwindColors.onAccent;
    } else if (!enabled) {
      fg = UnwindColors.textDisabled;
    } else if (isToday) {
      fg = UnwindColors.accent;
    } else {
      fg = UnwindColors.textPrimary;
    }

    return UnwindPressable(
      onTap: enabled ? () => widget.onPick(date) : null,
      depth: 0,
      pressScale: 0.88,
      haptic: UnwindHapticKind.selection,
      semanticLabel: '$day',
      isToggled: selected,
      child: SizedBox(
        height: UnwindTouch.minTarget,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? UnwindColors.accent : null,
              shape: BoxShape.circle,
              // 오늘은 링으로 — 선택과 헷갈리지 않게 채우지 않는다
              border: isToday && !selected
                  ? Border.all(
                      color: UnwindColors.accent,
                      width: UnwindStroke.base,
                    )
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: UnwindType.bodyStrong.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
