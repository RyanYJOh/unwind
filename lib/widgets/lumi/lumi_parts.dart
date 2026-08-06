import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// §7.1 Lumi 더미 파츠 페인터.
/// 단일 이미지가 아니라 파츠 조합 — body / hem / eyes / lids / mouth / glow.
/// 나중에 실제 에셋으로 교체할 때 이 파일만 갈아끼운다.
class LumiPainter extends CustomPainter {
  /// 0.0(정오) ~ 1.0(밤). 눈꺼풀·쳐짐·glow에 반영.
  final double brightness;

  /// 눈 뜬 정도 0.0(감김) ~ 1.0(뜸). 깜빡임·취침이 여기로 합산되어 들어온다.
  final double eyeOpenness;

  /// 하품 진행도 0~1 (mouth 표시)
  final double yawn;

  /// hem 물결 위상 (라디안)
  final double hemPhase;

  /// hem 진폭 배율 0~1 (조도가 낮을수록, 취침 시 0)
  final double hemAmplitude;

  /// 몸이 아래로 쳐지는 오프셋(px)
  final double droop;

  /// glow 강도 0~1
  final double glowStrength;

  final Color glowColor;

  const LumiPainter({
    required this.brightness,
    required this.eyeOpenness,
    required this.yawn,
    required this.hemPhase,
    required this.hemAmplitude,
    required this.droop,
    required this.glowStrength,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + droop;
    final bodyW = size.width * 0.52;
    final bodyH = size.height * 0.62;
    final top = cy - bodyH / 2;
    final bottom = cy + bodyH / 2;

    // glow — 반투명 원 (§11: 블러 금지, RadialGradient 레이어로 표현)
    if (glowStrength > 0.01) {
      final glowR = bodyW * (0.95 + 0.25 * glowStrength);
      final glowPaint = Paint()
        ..shader = RadialGradient(colors: [
          glowColor.withValues(alpha: 0.28 * glowStrength),
          glowColor.withValues(alpha: 0.0),
        ]).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: glowR));
      canvas.drawCircle(Offset(cx, cy), glowR, glowPaint);
    }

    // body — 위가 둥근 흰 타원 + hem 물결
    const bodyColor = Color(0xFFFDFCF8);
    final body = Path()
      ..moveTo(cx - bodyW / 2, bottom);
    // 왼쪽 변 위로
    body.lineTo(cx - bodyW / 2, top + bodyH * 0.38);
    // 둥근 머리
    body.quadraticBezierTo(cx - bodyW / 2, top, cx, top);
    body.quadraticBezierTo(cx + bodyW / 2, top, cx + bodyW / 2, top + bodyH * 0.38);
    body.lineTo(cx + bodyW / 2, bottom);
    // hem — 물결 곡선 4개 (오른쪽 → 왼쪽)
    const waves = 4;
    final waveW = bodyW / waves;
    final amp = bodyH * 0.045 * hemAmplitude +
        bodyH * 0.028 * math.sin(hemPhase) * hemAmplitude;
    for (var i = 0; i < waves; i++) {
      final x0 = cx + bodyW / 2 - waveW * i;
      final phase = hemPhase + i * 0.9;
      final dip = bodyH * 0.05 + amp * (0.6 + 0.4 * math.sin(phase));
      body.quadraticBezierTo(
          x0 - waveW / 2, bottom + dip, x0 - waveW, bottom);
    }
    body.close();
    canvas.drawPath(body, Paint()..color = bodyColor);

    // eyes — 검은 원 (openness에 따라 세로로 눌림)
    final eyeY = top + bodyH * 0.40;
    final eyeDx = bodyW * 0.17;
    final eyeR = bodyW * 0.055;
    final open = eyeOpenness.clamp(0.0, 1.0);
    final eyePaint = Paint()..color = const Color(0xFF2A2430);
    for (final dx in [-eyeDx, eyeDx]) {
      if (open > 0.05) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + dx, eyeY),
              width: eyeR * 2,
              height: eyeR * 2 * open),
          eyePaint,
        );
      } else {
        // 감긴 눈 — 부드러운 곡선 한 줄
        final lidLine = Paint()
          ..color = const Color(0xFF2A2430)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final p = Path()
          ..moveTo(cx + dx - eyeR, eyeY)
          ..quadraticBezierTo(cx + dx, eyeY + eyeR * 0.9, cx + dx + eyeR, eyeY);
        canvas.drawPath(p, lidLine);
      }
    }

    // lids — 몸통색 반원이 조도에 비례해 내려옴 (blink와 별개, §7.1)
    // eyeOpenness에 이미 lid 효과가 합산되어 있으므로 여기서는 그리지 않는다.
    // (파츠 교체 시 별도 lid 레이어로 분리할 것)

    // mouth — 하품 시에만
    if (yawn > 0.05) {
      final mouthY = eyeY + bodyH * 0.16;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, mouthY),
          width: bodyW * 0.10 * (0.5 + 0.5 * yawn),
          height: bodyW * 0.13 * yawn,
        ),
        Paint()..color = const Color(0xFF4A4050),
      );
    }
  }

  @override
  bool shouldRepaint(LumiPainter old) =>
      old.brightness != brightness ||
      old.eyeOpenness != eyeOpenness ||
      old.yawn != yawn ||
      old.hemPhase != hemPhase ||
      old.hemAmplitude != hemAmplitude ||
      old.droop != droop ||
      old.glowStrength != glowStrength ||
      old.glowColor != glowColor;
}
