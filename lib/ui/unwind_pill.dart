import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';

enum UnwindPillTone {
  /// 중립 — 다른 화면으로 넘어가는 조용한 알약 (주간 뷰 진입 등)
  neutral,

  /// 앰버 — 눈에 띄어야 하는 알림성 알약.
  /// **불투명 채움**이라 CornerGlow가 눈부신 자리에서도 읽힌다 (§5.1).
  accent,

  /// 코랄 — 아직 안 본 것이 있다는 신호 (미확인 청구서).
  /// 앰버는 앱 전체가 쓰는 색이라 알림으로는 묻힌다 (개정 2026-08-13).
  danger,
}

/// 작은 알약 버튼 — 주로 **다른 곳으로 데려가는** 자리에 쓴다.
///
/// [UnwindChip]과 역할이 다르다: 칩은 상호배타 **선택**이고, 이건 **이동·알림**이다.
/// 둘을 섞으면 선택된 칩처럼 보여 역할이 흐려지므로 컴포넌트를 나눠 둔다.
///
/// 작지만 **누를 수 있다는 게 보여야 한다** — 듀오링고식 압출을 4pt 넣는다.
/// 중립 톤의 압출면은 배경(ink)보다 확실히 어두운 색이어야 한다. `solid`는
/// ink와 명도 차가 거의 없어 그림자가 보이지 않았다 (개정 2026-08-13).
class UnwindPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final UnwindPillTone tone;

  final String? semanticLabel;

  const UnwindPill({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = UnwindPillTone.neutral,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color border, Color fg, Color deep) = switch (tone) {
      UnwindPillTone.neutral => (
        UnwindColors.surfaceHigh,
        UnwindColors.borderStrong,
        UnwindColors.textPrimary,
        UnwindColors.pillDeep,
      ),
      UnwindPillTone.accent => (
        UnwindColors.accent,
        UnwindColors.accent,
        UnwindColors.onAccent,
        UnwindColors.accentDeep,
      ),
      UnwindPillTone.danger => (
        UnwindColors.danger,
        UnwindColors.danger,
        UnwindColors.onDanger,
        UnwindColors.dangerDeep,
      ),
    };
    final br = BorderRadius.circular(UnwindRadius.pill);

    return UnwindPressable(
      onTap: onTap,
      depth: UnwindDepth.base,
      shadowColor: deep,
      borderRadius: br,
      semanticLabel: semanticLabel ?? label,
      child: Container(
        // alignment를 주면 Container가 부모 폭까지 늘어난다 — 높이는
        // 패딩으로 만든다 (UnwindButton에서 겪은 것과 같은 함정).
        padding: const EdgeInsets.symmetric(
          horizontal: UnwindSpacing.s8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: br,
          border: Border.all(color: border, width: UnwindStroke.hair),
        ),
        child: Text(
          label,
          style: UnwindType.caption.copyWith(color: fg, height: 1.0),
        ),
      ),
    );
  }
}
