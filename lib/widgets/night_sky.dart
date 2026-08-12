import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/tokens/motion.dart';

/// 소등 후 밤하늘 — 별 + 초승달. 블러 금지(§11), RadialGradient만 사용.
class NightSkyPainter extends CustomPainter {
  final double opacity;
  const NightSkyPainter({required this.opacity});

  static final stars = () {
    final rng = math.Random(42);
    return List.generate(46, (_) {
      return (
        dx: rng.nextDouble(),
        dy: rng.nextDouble() * 0.55,
        r: 0.6 + rng.nextDouble() * 1.1,
        a: 0.25 + rng.nextDouble() * 0.6,
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;
    final starPaint = Paint();
    for (final s in stars) {
      starPaint.color = const Color(
        0xFFEDE8F5,
      ).withValues(alpha: s.a * opacity);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.r,
        starPaint,
      );
    }

    // 초승달 — 좌상단, 은은한 발광
    final moonC = Offset(size.width * 0.18, size.height * 0.13);
    const moonR = 26.0;
    canvas.drawCircle(
      moonC,
      moonR * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF5EBC8).withValues(alpha: 0.14 * opacity),
            const Color(0x00F5EBC8),
          ],
        ).createShader(Rect.fromCircle(center: moonC, radius: moonR * 2.6)),
    );
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonC, radius: moonR)),
      Path()..addOval(
        Rect.fromCircle(
          center: moonC.translate(moonR * 0.45, -moonR * 0.18),
          radius: moonR * 0.86,
        ),
      ),
    );
    canvas.drawPath(
      moon,
      Paint()
        ..color = const Color(0xFFF0E6C6).withValues(alpha: 0.85 * opacity),
    );
  }

  @override
  bool shouldRepaint(NightSkyPainter old) => old.opacity != opacity;
}

/// §5.5 호흡: sin(2π·elapsed/4000ms) · 0.012 — (1 - t) 인자는 소비처(glow)에서 곱한다.
class BreathAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  @override
  final Animation<double> parent;
  BreathAnimation(this.parent);

  @override
  double get value =>
      math.sin(parent.value * 2 * math.pi) * UnwindMotion.breathAmplitude;
}
