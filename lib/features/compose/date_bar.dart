import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../ui/ui.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.3 플로팅 날짜 바 — 키보드 바로 위 고정.
///
/// ```
/// [calendar]        [ ‹  오늘  › ]        [ 방에 놓기 → ]
/// ```
///
/// 함정 1 대응: 모든 버튼은 GestureDetector 기반([UnwindPressable])이라
/// 포커스를 만들지 않는다 — 키보드가 절대 내려가지 않는다.
class DateBar extends StatelessWidget {
  final String dateKey;
  final String todayKey;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onCalendarTap;
  final VoidCallback onSave;

  /// 제목이 비어 있으면 저장 CTA가 죽는다
  final bool canSave;

  const DateBar({
    super.key,
    required this.dateKey,
    required this.todayKey,
    required this.onDateChanged,
    required this.onCalendarTap,
    required this.onSave,
    this.canSave = true,
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
    onDateChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isToday = dateKey == todayKey;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: UnwindColors.ink,
        border: Border(
          top: BorderSide(color: UnwindColors.border, width: UnwindStroke.base),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnwindSpacing.s12,
          UnwindSpacing.s8,
          UnwindSpacing.s12,
          UnwindSpacing.s8,
        ),
        child: Row(
          children: [
            UnwindIconButton(
              icon: Icons.calendar_today_rounded,
              iconSize: 20,
              onPressed: onCalendarTap,
              semanticLabel: l10n.chooseDate,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UnwindIconButton(
                    icon: Icons.chevron_left_rounded,
                    iconSize: 30,
                    onPressed: isToday ? null : () => _shift(-1),
                    haptic: UnwindHapticKind.selection,
                  ),
                  UnwindPressable(
                    onTap: onCalendarTap,
                    depth: 0,
                    pressScale: 0.94,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 92,
                        minHeight: UnwindTouch.minTarget,
                      ),
                      child: Center(
                        child: Text(
                          _label(l10n),
                          textAlign: TextAlign.center,
                          style: UnwindType.label.copyWith(
                            color: isToday
                                ? UnwindColors.textPrimary
                                : UnwindColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  UnwindIconButton(
                    icon: Icons.chevron_right_rounded,
                    iconSize: 30,
                    onPressed: () => _shift(1),
                    haptic: UnwindHapticKind.selection,
                  ),
                ],
              ),
            ),
            // 저장 CTA — 라벨 없이 화살표 하나 (개정 2026-08-12)
            UnwindIconButton(
              icon: Icons.arrow_forward_rounded,
              iconSize: 26,
              size: 48,
              style: UnwindIconButtonStyle.accent,
              semanticLabel: l10n.save,
              haptic: UnwindHapticKind.none, // 저장 성공 햅틱은 시트가 쏜다
              onPressed: canSave ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }
}
