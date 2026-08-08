import 'package:flutter/widgets.dart';

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

  // 따뜻하지만 세련된 톤 — 채도를 눌러 우아하게
  static const _wash = Color(0xFFE8C98F);
  static const _mid = Color(0xFFF3DCAC);
  static const _core = Color(0xFFFBEFD3);
  static const _hot = Color(0xFFFFFBF0);

  @override
  void paint(Canvas canvas, Size size) {
    final l = (light + breath * 1.5).clamp(0.0, 1.0);
    if (l <= 0.004) return;

    final w = size.width;
    // 광원: 우측 상단 코너 살짝 바깥 — 화면 안에 광원 원반이 보이지 않아
    // "어딘가 위에서 빛이 내려온다"는 인상을 준다
    final origin = Offset(w * 1.04, -w * 0.10);
    final ease = Curves.easeOutQuad.transform(l); // 감쇠가 자연스럽도록

    void glow(double radius, Color color, double alpha,
        {double focus = 0.0}) {
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

    // 강화 2026-08-08: 광원이 확실히 "빛나는" 인상을 주도록 전 겹 증폭
    // 1. 워시 — 방 전체로 스미는 온기 (좌하단은 어둠에 남는다)
    glow(w * (1.05 + 1.35 * ease), _wash, 0.36 * ease);
    // 2. 미드 — 상부를 채우는 빛
    glow(w * (0.70 + 0.95 * ease), _mid, 0.62 * ease);
    // 3. 코어 — 코너의 빛덩어리
    glow(w * (0.36 + 0.56 * ease), _core, 0.92 * ease, focus: 0.10);
    // 4. 핫스팟 — 광원의 눈부심 (최대 밝기)
    glow(w * (0.20 + 0.32 * ease), _hot, 1.0 * ease, focus: 0.22);
  }

  @override
  bool shouldRepaint(_CornerGlowPainter old) =>
      old.light != light || old.breath != breath;
}
