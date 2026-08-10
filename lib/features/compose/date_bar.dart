import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.3 플로팅 날짜 바 — 키보드 바로 위 고정.
///
/// ```
/// [calendar]             [ ‹  오늘  › ]  [(→)]
/// ```
///
/// 함정 1 대응: 모든 버튼은 GestureDetector라 포커스를 만들지 않는다 —
/// 키보드가 절대 내려가지 않는다.
class DateBar extends StatelessWidget {
  final String dateKey;
  final String todayKey;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onCalendarTap;
  final VoidCallback onSave;
  final UnwindHaptics haptics;

  const DateBar({
    super.key,
    required this.dateKey,
    required this.todayKey,
    required this.onDateChanged,
    required this.onCalendarTap,
    required this.onSave,
    required this.haptics,
  });

  /// 라벨은 의미 우선 (§6.3): 오늘 / 내일 / 모레 → 그 이후는 '10월 27일 (월)'
  String _label(AppLocalizations l10n) {
    final diff = parseDayKey(dateKey).difference(parseDayKey(todayKey)).inDays;
    switch (diff) {
      case 0:
        return l10n.dateToday;
      case 1:
        return l10n.dateTomorrow;
      case 2:
        return l10n.dateDayAfter;
      default:
        final d = parseDayKey(dateKey);
        final weekday = l10n.weekdaysShort.split(',')[d.weekday - 1];
        final monthName = l10n.monthsShort.split(',')[d.month - 1];
        return '${l10n.monthDay(monthName, d.month, d.day)} ($weekday)';
    }
  }

  void _shift(int days) {
    final next = dayKey(addDays(parseDayKey(dateKey), days));
    // 오늘 이전으로는 내려가지 않는다 (지난 방에는 등을 놓을 수 없다, §2)
    if (parseDayKey(next).isBefore(parseDayKey(todayKey))) return;
    haptics.selection(); // §6.3 날짜 변경 햅틱
    onDateChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final isToday = dateKey == todayKey;

    // §6.3: 날짜가 오늘이 아닐 때는 바 전체 배경이 눈에 띄게 달라진다.
    final barColor = isToday
        ? colors.surfaceRaised
        : Color.lerp(colors.surfaceRaised, colors.lamp, 0.28)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UnwindSpacing.s8,
          vertical: UnwindSpacing.s4,
        ),
        child: Row(
          children: [
            _IconButton(
              icon: Icons.calendar_today_rounded,
              onTap: onCalendarTap,
              colors: colors,
              semanticsLabel: l10n.chooseDate,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconButton(
                    icon: Icons.chevron_left_rounded,
                    iconSize: 34,
                    onTap: isToday ? null : () => _shift(-1),
                    colors: colors,
                  ),
                  GestureDetector(
                    onTap: onCalendarTap,
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 88,
                        minHeight: UnwindTouch.minTarget,
                      ),
                      child: Center(
                        child: Text(
                          _label(l10n),
                          style: UnwindType.bodyStrong.copyWith(
                            color: colors.textPrimarySnap,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _IconButton(
                    icon: Icons.chevron_right_rounded,
                    iconSize: 34,
                    onTap: () => _shift(1),
                    colors: colors,
                  ),
                ],
              ),
            ),
            Semantics(
              label: l10n.save,
              button: true,
              child: GestureDetector(
                onTap: onSave,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.square(
                  dimension: UnwindTouch.minTarget,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.lamp,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 24,
                          color: colors.textPrimaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;
  final UnwindColors colors;
  final String? semanticsLabel;

  const _IconButton({
    required this.icon,
    this.iconSize = 24,
    required this.onTap,
    required this.colors,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: UnwindTouch.minTarget,
          height: UnwindTouch.minTarget,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: onTap == null ? colors.textMuted : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
