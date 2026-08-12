import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import 'unwind_pressable.dart';

enum UnwindIconButtonStyle {
  /// 배경 없는 아이콘 (상단바·행 내부)
  plain,

  /// 중립 면 + 테두리 + 압출
  filled,

  /// 앰버 면 + 압출 (FAB 성격)
  accent,
}

/// 아이콘 하나짜리 탭 타깃. 항상 44pt 이상, 항상 햅틱.
class UnwindIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final UnwindIconButtonStyle style;
  final double iconSize;
  final double size;
  final String? semanticLabel;
  final Color? color;
  final UnwindHapticKind haptic;

  const UnwindIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.style = UnwindIconButtonStyle.plain,
    this.iconSize = 24,
    this.size = UnwindTouch.minTarget,
    this.semanticLabel,
    this.color,
    this.haptic = UnwindHapticKind.tap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(UnwindRadius.sm);

    final (Color? fill, Color? border, Color fg, Color deep) = switch (style) {
      UnwindIconButtonStyle.plain => (
        null,
        null,
        color ??
            (enabled ? UnwindColors.textSecondary : UnwindColors.textDisabled),
        UnwindColors.solid,
      ),
      UnwindIconButtonStyle.filled => (
        UnwindColors.surfaceAlt,
        UnwindColors.borderStrong,
        color ??
            (enabled ? UnwindColors.textPrimary : UnwindColors.textDisabled),
        UnwindColors.solid,
      ),
      UnwindIconButtonStyle.accent => (
        enabled ? UnwindColors.accent : UnwindColors.surfaceAlt,
        null,
        enabled ? UnwindColors.onAccent : UnwindColors.textDisabled,
        enabled ? UnwindColors.accentDeep : UnwindColors.solid,
      ),
    };

    return UnwindPressable(
      onTap: onPressed,
      depth: style == UnwindIconButtonStyle.plain ? 0 : UnwindDepth.small,
      shadowColor: deep,
      borderRadius: radius,
      haptic: haptic,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: fill == null
            ? null
            : BoxDecoration(
                color: fill,
                borderRadius: radius,
                border: border == null
                    ? null
                    : Border.all(color: border, width: UnwindStroke.base),
              ),
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );
  }
}
