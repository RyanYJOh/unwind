import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';

/// 두툼한 면 하나. 앱의 모든 카드·패널의 기본형.
///
/// 듀오링고 규칙: 2px 테두리 + 큰 반경. [onTap]을 주면 압출(3D)이 붙고
/// 누르면 내려앉는다.
class UnwindCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final double radius;

  /// 강조된 카드 — 앰버 테두리 (켜진 등, 선택 상태)
  final bool highlighted;

  /// onTap이 없어도 압출을 그린다
  final bool raised;
  final String? semanticLabel;

  const UnwindCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(UnwindSpacing.s16),
    this.color = UnwindColors.surface,
    this.borderColor,
    this.radius = UnwindRadius.md,
    this.highlighted = false,
    this.raised = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: br,
        border: Border.all(
          color:
              borderColor ??
              (highlighted ? UnwindColors.accentEdge : UnwindColors.border),
          width: UnwindStroke.base,
        ),
      ),
      child: child,
    );

    final depth = (onTap != null || onLongPress != null || raised)
        ? UnwindDepth.base
        : 0.0;

    return UnwindPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      depth: depth,
      borderRadius: br,
      semanticLabel: semanticLabel,
      isButton: onTap != null,
      child: body,
    );
  }
}

/// 섹션 구분 라벨 — 대문자 트래킹, 뮤트 색.
class UnwindSectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const UnwindSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      UnwindSpacing.s24,
      UnwindSpacing.s24,
      UnwindSpacing.s24,
      UnwindSpacing.s8,
    ),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      text.toUpperCase(),
      style: UnwindType.overline.copyWith(color: UnwindColors.textMuted),
    ),
  );
}

/// 얇은 구분선 — 꼭 필요할 때만. 듀오링고는 여백으로 나눈다.
class UnwindDivider extends StatelessWidget {
  final double indent;
  const UnwindDivider({super.key, this.indent = UnwindSpacing.s24});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: indent),
    child: const SizedBox(
      height: UnwindStroke.base,
      child: ColoredBox(color: UnwindColors.border),
    ),
  );
}
