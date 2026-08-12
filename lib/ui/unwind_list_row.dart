import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';
import 'unwind_switch.dart';

/// 설정·목록의 한 행. 라벨 + 선택적 캡션 + 트레일링.
///
/// 세 가지로 쓴다:
/// - [UnwindListRow.toggle] — 스위치가 붙은 행
/// - [UnwindListRow.value]  — 값이 붙고 탭하면 피커가 열리는 행
/// - [UnwindListRow]        — 임의의 [trailing]
class UnwindListRow extends StatelessWidget {
  final String label;
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// 화면 목록은 기본 여백(좌우 24)을, 시트 안에서는 0을 준다.
  final EdgeInsetsGeometry padding;

  static const defaultPadding = EdgeInsets.symmetric(
    horizontal: UnwindSpacing.s24,
    vertical: UnwindSpacing.s8,
  );

  const UnwindListRow({
    super.key,
    required this.label,
    this.caption,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.padding = defaultPadding,
  });

  UnwindListRow.toggle({
    super.key,
    required this.label,
    this.caption,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.padding = defaultPadding,
  }) : destructive = false,
       onTap = onChanged == null ? null : (() => onChanged(!value)),
       trailing = UnwindToggle(
         value: value,
         // 행 전체가 탭 타깃이므로 스위치는 시각 표현만 담당한다
         onChanged: null,
         semanticsLabel: label,
       );

  UnwindListRow.value({
    super.key,
    required this.label,
    this.caption,
    required String value,
    required this.onTap,
    this.destructive = false,
    this.padding = defaultPadding,
  }) : trailing = value.isEmpty
           ? null
           : Text(
               value,
               style: UnwindType.label.copyWith(color: UnwindColors.accent),
             );

  @override
  Widget build(BuildContext context) {
    return UnwindPressable(
      onTap: onTap,
      depth: 0,
      pressScale: 0.985,
      haptic: destructive ? UnwindHapticKind.warning : UnwindHapticKind.tap,
      semanticLabel: label,
      isButton: onTap != null,
      child: Container(
        constraints: const BoxConstraints(minHeight: UnwindTouch.minTarget),
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: UnwindType.bodyStrong.copyWith(
                      color: destructive
                          ? UnwindColors.danger
                          : UnwindColors.textPrimary,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: UnwindSpacing.s2),
                    Text(
                      caption!,
                      style: UnwindType.caption.copyWith(
                        color: UnwindColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: UnwindSpacing.s12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
