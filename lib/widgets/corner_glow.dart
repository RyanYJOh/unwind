import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';

/// 코너 글로우 (디자인 개편 2026-08-07, darkGlow) — 우측 상단에서
/// 방으로 쏟아지는 순수한 빛. 조명 그림 없이 빛 그 자체만 그린다.
///
/// 다크 베이스 위에 4겹 RadialGradient(§11: 블러 금지, GPU 그라데이션이라
/// 부담 없음)로 사실적인 감쇠를 만든다:
///   1. 워시 — 화면 대부분을 덮는 아주 은은한 온기
///   2. 미드 — 상부를 채우는 부드러운 빛
///   3. 코어 — 코너 근처의 밝은 빛덩어리
///   4. 핫스팟 — 광원 자체의 눈부심 (거의 흰색)
/// [light]가 줄면 반경·강도가 함께 잦아들어 "빛이 사그라드는" 감각을 만든다.
class CornerGlow extends StatelessWidget {
  /// 0.0(완전한 다크) ~ 1.0(가장 밝음). 보통 1 - t.
  final double light;

  /// §5.5 호흡 — 미세한 밝기 요동
  final double breath;

  const CornerGlow({super.key, required this.light, this.breath = 0});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CornerGlowPainter(
            light: light.clamp(0.0, 1.0),
            breath: breath,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CornerGlowPainter extends CustomPainter {
  final double light;
  final double breath;

  const _CornerGlowPainter({required this.light, required this.breath});

  // 디자인 시스템 v2: 빛도 포인트 컬러에 묶는다. 이전의 크림 톤은
  // 차가운 슬레이트 베이스 위에서 화면 전체를 베이지로 덮어 팔레트를 죽였다.
  // 방은 어디까지나 어두운 네이비고, 코너만 조명 색으로 빛난다.
  // 4겹은 조명 색(UnwindLightColor)의 seed에서 파생된다 (선택형 2026-08-22).

  @override
  void paint(Canvas canvas, Size size) {
    final wash = UnwindColors.glowWash;
    final mid = UnwindColors.glowMid;
    final core = UnwindColors.glowCore;
    final hot = UnwindColors.glowHot;
    final l = (light + breath * 1.5).clamp(0.0, 1.0);
    if (l <= 0.004) return;

    final w = size.width;
    // 광원: 우측 상단 코너 살짝 바깥 — 화면 안에 광원 원반이 보이지 않아
    // "어딘가 위에서 빛이 내려온다"는 인상을 준다
    final origin = Offset(w * 1.04, -w * 0.10);
    // 선형 응답 (개정 2026-08-12): easeOutQuad는 위쪽 구간이 평평해서
    // 등을 하나씩 꺼도 밝기 차이가 거의 안 보였다. 한 칸 끌 때마다 같은
    // 폭으로 어두워져야 "내가 방을 어둡게 하고 있다"가 읽힌다.
    final ease = l;

    void glow(double radius, Color color, double alpha, {double focus = 0.0}) {
      if (alpha <= 0.003) return;
      canvas.drawCircle(
        origin,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.55),
              color.withValues(alpha: 0.0),
            ],
            stops: [focus, 0.35 + focus * 0.3, 1.0],
          ).createShader(Rect.fromCircle(center: origin, radius: radius)),
      );
    }

    // 재조정 2026-08-13 (3차): **더 세게.** 할 일이 하나라도 남은 방은
    // Todd가 눈이 부셔 잠들 수 없어야 한다. 그래야 하나씩 끌 때마다 방이
    // 어두워지는 게 확실히 읽힌다. 좌하단은 언제나 어둠에 남는다.
    //
    // 상한은 §12가 정한다: 이 값에서 헤더 제목(textPrimary)이 가장 밝아진
    // 배경 위에서도 대비 ≈4.9:1로 4.5:1을 넘는다. 더 올리려면 헤더를
    // 불투명 면에 얹는 것이 먼저다.
    // 1. 워시 — 방 전체로 스미는 온기
    glow(w * (1.05 + 1.45 * ease), wash, 0.52 * ease);
    // 2. 미드 — 상부를 채우는 빛
    glow(w * (0.70 + 1.05 * ease), mid, 0.78 * ease);
    // 3. 코어 — 코너의 빛덩어리
    glow(w * (0.38 + 0.60 * ease), core, 1.0 * ease, focus: 0.10);
    // 4. 핫스팟 — 광원 자체의 눈부심 (거의 흰색)
    glow(w * (0.22 + 0.34 * ease), hot, 1.0 * ease, focus: 0.22);
  }

  @override
  bool shouldRepaint(_CornerGlowPainter old) =>
      old.light != light || old.breath != breath;
}
