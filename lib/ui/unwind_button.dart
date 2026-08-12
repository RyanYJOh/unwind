import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';

enum UnwindButtonVariant {
  /// 주 CTA — 앰버. 한 화면에 하나만.
  primary,

  /// 보조 — 중립 면 + 굵은 테두리
  secondary,

  /// 파괴적 — 코랄
  danger,

  /// 텍스트만. 압출 없음.
  ghost,
}

/// 듀오링고 문법의 버튼. 누르면 4px 내려앉는다.
///
/// 크기는 두 가지뿐이다: 기본(CTA, 56pt)과 [small](44pt).
/// 라벨은 동사로 쓴다 (§8.5 — "저장" 말고 "방에 놓기").
class UnwindButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final UnwindButtonVariant variant;
  final IconData? icon;

  /// 가로를 꽉 채운다 (기본). false면 내용만큼만.
  final bool expand;
  final bool small;
  final UnwindHapticKind haptic;

  const UnwindButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = UnwindButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.small = false,
    this.haptic = UnwindHapticKind.tap,
  });

  const UnwindButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.small = false,
    this.haptic = UnwindHapticKind.tap,
  }) : variant = UnwindButtonVariant.secondary;

  const UnwindButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.small = false,
    this.haptic = UnwindHapticKind.warning,
  }) : variant = UnwindButtonVariant.danger;

  const UnwindButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.small = false,
    this.haptic = UnwindHapticKind.tap,
  }) : variant = UnwindButtonVariant.ghost;

  bool get _enabled => onPressed != null;

  ({Color fill, Color deep, Color fg, Color? border}) get _skin {
    if (!_enabled) {
      return (
        fill: UnwindColors.surfaceAlt,
        deep: UnwindColors.solid,
        fg: UnwindColors.textDisabled,
        border: UnwindColors.border,
      );
    }
    return switch (variant) {
      UnwindButtonVariant.primary => (
        fill: UnwindColors.accent,
        deep: UnwindColors.accentDeep,
        fg: UnwindColors.onAccent,
        border: null,
      ),
      UnwindButtonVariant.secondary => (
        fill: UnwindColors.surfaceAlt,
        deep: UnwindColors.solid,
        fg: UnwindColors.textPrimary,
        border: UnwindColors.borderStrong,
      ),
      UnwindButtonVariant.danger => (
        fill: UnwindColors.danger,
        deep: UnwindColors.dangerDeep,
        fg: UnwindColors.onDanger,
        border: null,
      ),
      UnwindButtonVariant.ghost => (
        fill: const Color(0x00000000),
        deep: const Color(0x00000000),
        fg: UnwindColors.textSecondary,
        border: null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final skin = _skin;
    final isGhost = variant == UnwindButtonVariant.ghost;
    final radius = BorderRadius.circular(
      small ? UnwindRadius.sm : UnwindRadius.md,
    );
    final style = (small ? UnwindType.buttonSmall : UnwindType.button).copyWith(
      color: skin.fg,
    );

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: small ? 18 : 20, color: skin.fg),
          const SizedBox(width: UnwindSpacing.s8),
        ],
        Flexible(
          child: Text(
            label,
            style: style,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    content = Container(
      height: small ? UnwindTouch.buttonSmallHeight : UnwindTouch.ctaHeight,
      padding: EdgeInsets.symmetric(
        horizontal: small ? UnwindSpacing.s16 : UnwindSpacing.s24,
      ),
      // alignment를 주면 Container가 부모 폭까지 늘어난다 — expand=false가
      // 무시되므로 정렬은 Row의 mainAxisAlignment에 맡긴다.
      decoration: BoxDecoration(
        color: skin.fill,
        borderRadius: radius,
        border: skin.border == null
            ? null
            : Border.all(color: skin.border!, width: UnwindStroke.base),
      ),
      child: content,
    );

    return UnwindPressable(
      onTap: onPressed,
      depth: isGhost ? 0 : (small ? UnwindDepth.small : UnwindDepth.base),
      shadowColor: skin.deep,
      borderRadius: radius,
      haptic: haptic,
      // semanticLabel을 주지 않는다 — 라벨 Text가 이미 접근성 라벨이다.
      // 둘 다 주면 노드 라벨이 "Save\nSave"로 합쳐진다.
      child: content,
    );
  }
}
