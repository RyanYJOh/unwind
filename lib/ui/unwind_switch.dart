import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import 'unwind_pressable.dart';

/// 벽 로커 스위치 — 할 일 하나 = 방의 등 하나 (§1 컨셉).
///
/// 개편 2026-08-12: 크림색 플라스틱 스큐어모피즘을 버리고 **납작하고 두툼한
/// 로커**로. 세로 방향(위=ON)은 그대로 유지한다 — 벽 스위치라는 은유가
/// 여기서 나온다. 켜지면 앰버 + 발광, 꺼지면 중립 면.
class UnwindLampSwitch extends StatelessWidget {
  final bool isOn;
  final VoidCallback? onTap;

  /// §12 스크린리더: 라벨은 [semanticsOn], 값은 현재 상태를 읽는다.
  final String semanticsOn;
  final String semanticsOff;

  /// 발광 세기 (0~1). 소등 애니메이션 중 잔광을 표현.
  final double lit;

  const UnwindLampSwitch({
    super.key,
    required this.isOn,
    required this.onTap,
    required this.semanticsOn,
    required this.semanticsOff,
    this.lit = 1.0,
  });

  static const _trackW = 34.0;
  static const _trackH = 46.0;
  static const _knobW = 24.0;
  static const _knobH = 19.0;

  @override
  Widget build(BuildContext context) {
    final glow = isOn ? lit.clamp(0.0, 1.0) : 0.0;
    const dur = Duration(milliseconds: 180);

    return UnwindPressable(
      onTap: onTap,
      depth: 0,
      pressScale: 0.92,
      haptic: isOn ? UnwindHapticKind.toggleOff : UnwindHapticKind.toggleOn,
      semanticLabel: semanticsOn,
      semanticValue: isOn ? semanticsOn : semanticsOff,
      isToggled: isOn,
      child: SizedBox(
        width: UnwindTouch.minTarget,
        height: UnwindTouch.minTarget + UnwindSpacing.s4,
        child: Center(
          child: AnimatedContainer(
            duration: dur,
            curve: Curves.easeOut,
            width: _trackW,
            height: _trackH,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isOn ? UnwindColors.accentSoft : UnwindColors.surfaceAlt,
              borderRadius: BorderRadius.circular(UnwindRadius.sm),
              border: Border.all(
                color: isOn ? UnwindColors.accent : UnwindColors.borderStrong,
                width: UnwindStroke.base,
              ),
            ),
            child: AnimatedAlign(
              duration: dur,
              curve: Curves.easeOutBack,
              alignment: isOn ? Alignment.topCenter : Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: dur,
                width: _knobW,
                height: _knobH,
                decoration: BoxDecoration(
                  color: isOn ? UnwindColors.accent : UnwindColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(UnwindRadius.xs),
                  // §5 예외: 스위치 인디케이터 같은 소형 요소에 한해 blur 허용
                  boxShadow: glow > 0.02
                      ? [
                          BoxShadow(
                            color: UnwindColors.accent.withValues(
                              alpha: 0.55 * glow,
                            ),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 설정용 가로 토글. 벽 스위치 은유가 필요 없는 자리에 쓴다.
class UnwindToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  /// 시각적 활성 상태. [onChanged]가 null이어도(=상위 행이 탭을 받는 경우)
  /// 꺼진 것처럼 보이지 않게 하려고 분리했다.
  final bool enabled;

  const UnwindToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const dur = Duration(milliseconds: 160);

    return UnwindPressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      depth: 0,
      pressScale: 0.94,
      haptic: value ? UnwindHapticKind.toggleOff : UnwindHapticKind.toggleOn,
      semanticLabel: semanticsLabel,
      isToggled: value,
      child: SizedBox(
        width: UnwindTouch.minTarget + UnwindSpacing.s12,
        height: UnwindTouch.minTarget,
        child: Center(
          child: AnimatedContainer(
            duration: dur,
            curve: Curves.easeOut,
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? UnwindColors.accentSoft : UnwindColors.surfaceAlt,
              borderRadius: BorderRadius.circular(UnwindRadius.pill),
              border: Border.all(
                color: value ? UnwindColors.accent : UnwindColors.borderStrong,
                width: UnwindStroke.base,
              ),
            ),
            child: AnimatedAlign(
              duration: dur,
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? (value ? UnwindColors.accent : UnwindColors.textMuted)
                      : UnwindColors.textDisabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
