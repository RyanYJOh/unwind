import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';
import 'unwind_switch.dart';

/// 할 일 하나 = 방의 등 하나 (§1 컨셉).
///
/// 개편 2026-08-12: 형광등 패널·발광 그라데이션을 버리고 **두툼한 타일 +
/// 벽 로커 스위치**로. 켜진 등은 앰버 테두리로만 구분한다 — 빛의 총량은
/// CornerGlow가 담당하고, 타일은 그 빛을 흉내내지 않는다.
///
/// - 타일 탭 = 편집, 롱프레스 = 메뉴, 스위치 탭 = 토글
/// - 완료 항목은 삭선 + 가라앉은 면
class UnwindTodoTile extends StatelessWidget {
  final String title;
  final String? timeLabel;

  /// 등이 켜져 있는가 (= 아직 남은 할 일)
  final bool isOn;

  /// 실제로 완료 처리됐는가 — 삭선의 근거.
  /// 일괄 소등 중 시각적으로만 꺼진 항목과 구분해야 하므로 [isOn]과 별개다.
  final bool isDone;

  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 소등 도미노 중 잔광 (0~1)
  final double lit;

  final String switchSemanticsOn;
  final String switchSemanticsOff;

  const UnwindTodoTile({
    super.key,
    required this.title,
    required this.isOn,
    required this.switchSemanticsOn,
    required this.switchSemanticsOff,
    this.timeLabel,
    this.isDone = false,
    this.onToggle,
    this.onTap,
    this.onLongPress,
    this.lit = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(UnwindRadius.md);
    const dur = Duration(milliseconds: 200);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnwindSpacing.s20,
        vertical: UnwindSpacing.s4,
      ),
      child: UnwindPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        depth: UnwindDepth.base,
        borderRadius: br,
        semanticLabel: [?timeLabel, title].join(' '),
        isButton: onTap != null,
        child: AnimatedContainer(
          duration: dur,
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: UnwindTouch.tileHeight),
          padding: const EdgeInsets.only(
            left: UnwindSpacing.s16,
            right: UnwindSpacing.s8,
            top: UnwindSpacing.s8,
            bottom: UnwindSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isOn ? UnwindColors.surface : UnwindColors.ink,
            borderRadius: br,
            border: Border.all(
              color: isOn ? UnwindColors.accentEdge : UnwindColors.border,
              width: UnwindStroke.base,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeLabel != null) ...[
                      Text(
                        timeLabel!,
                        style: UnwindType.caption.copyWith(
                          color: isOn
                              ? UnwindColors.accent
                              : UnwindColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: UnwindSpacing.s2),
                    ],
                    Text(
                      title,
                      style: UnwindType.bodyStrong.copyWith(
                        color: isDone
                            ? UnwindColors.textMuted
                            : isOn
                            ? UnwindColors.textPrimary
                            : UnwindColors.textSecondary,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: UnwindColors.textMuted,
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UnwindSpacing.s8),
              UnwindLampSwitch(
                isOn: isOn,
                lit: lit,
                onTap: onToggle,
                semanticsOn: switchSemanticsOn,
                semanticsOff: switchSemanticsOff,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
