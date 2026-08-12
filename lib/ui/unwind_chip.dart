import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';

/// 선택 가능한 알약. 반복 규칙, 날짜 프리셋, 데모 프리뷰 등에 쓴다.
/// 선택되면 앰버 테두리 + 앰버 채움 — 다른 강조색은 쓰지 않는다.
class UnwindChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const UnwindChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = !enabled
        ? UnwindColors.textDisabled
        : selected
        ? UnwindColors.accent
        : UnwindColors.textSecondary;
    final br = BorderRadius.circular(UnwindRadius.pill);

    return UnwindPressable(
      onTap: onTap,
      depth: 0,
      borderRadius: br,
      haptic: UnwindHapticKind.selection,
      semanticLabel: label,
      isToggled: selected,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(
          horizontal: UnwindSpacing.s16,
          vertical: UnwindSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? UnwindColors.accentSoft : UnwindColors.surfaceAlt,
          borderRadius: br,
          border: Border.all(
            color: selected ? UnwindColors.accent : UnwindColors.border,
            width: UnwindStroke.base,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: UnwindSpacing.s4),
            ],
            Text(label, style: UnwindType.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
