import 'package:flutter/widgets.dart';

import '../core/theme/unwind_theme.dart';

/// 천장 조명 (디자인 개편 2026-08-07) — 우측 상단, 전등 줄 위에 달린 등.
///
/// 방의 유일한 광원: [light] (0=꺼짐, 1=최대)가 곧 남은 할 일의 양이다.
/// 스위치를 하나 끌 때마다 이 조명이 조금씩 어두워지고, 화면 전체가
/// 라이트 → 다크로 이동한다. 전등 줄이 이 등에서 늘어져 있다.
///
/// §11: 블러 금지 — 발광은 RadialGradient 레이어로만.
class CeilingLight extends StatelessWidget {
  /// 0.0(완전히 꺼짐) ~ 1.0(가장 밝음). 보통 1 - t.
  final double light;

  /// §5.5 호흡 — 미세한 밝기 요동 (Reduce Motion 시 0)
  final double breath;

  /// 전등 줄 중심 x가 화면 우측 끝에서 떨어진 거리 (PullCord와 정렬)
  final double cordCenterFromRight;

  const CeilingLight({
    super.key,
    required this.light,
    this.breath = 0,
    this.cordCenterFromRight = 52,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CeilingLightPainter(
            light: light.clamp(0.0, 1.0),
            breath: breath,
            cordCenterFromRight: cordCenterFromRight,
            lampColor: colors.lamp,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CeilingLightPainter extends CustomPainter {
  final double light;
  final double breath;
  final double cordCenterFromRight;
  final Color lampColor;

  const _CeilingLightPainter({
    required this.light,
    required this.breath,
    required this.cordCenterFromRight,
    required this.lampColor,
  });

  static const _ink = Color(0xFF201B29); // 캐릭터와 같은 잉크 톤
  static const _shade = Color(0xFFFDFCF8);
  static const _bulbWarm = Color(0xFFFFE6AE);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width - cordCenterFromRight;
    const topY = 0.0;
    final l = (light + breath * 2).clamp(0.0, 1.0);

    // ── 빛 — 방을 채우는 발광. 어두워질수록 반경·강도가 줄어든다 ──
    if (l > 0.01) {
      final glowC = Offset(cx, topY + 26);
      // 넓은 번짐 — 화면 상부를 채우는 은은한 빛
      final wideR = size.width * (0.55 + 0.75 * l);
      canvas.drawCircle(
        glowC,
        wideR,
        Paint()
          ..shader = RadialGradient(colors: [
            _bulbWarm.withValues(alpha: 0.34 * l),
            _bulbWarm.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: glowC, radius: wideR)),
      );
      // 광원 블룸 — 전구에 붙은 눈부심
      final coreR = 60.0 + 50.0 * l;
      canvas.drawCircle(
        glowC,
        coreR,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF7DF).withValues(alpha: 0.75 * l),
            const Color(0xFFFFF7DF).withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: glowC, radius: coreR)),
      );
    }

    // ── 전구 — 갓 아래 매달린 작은 구 ──
    final bulbC = Offset(cx, topY + 24);
    canvas.drawCircle(
      bulbC,
      7.5,
      Paint()
        ..color = Color.lerp(
            const Color(0xFF5A5264), Color.lerp(_bulbWarm, lampColor, 0.3)!,
            l)!,
    );
    canvas.drawCircle(
      bulbC,
      7.5,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // ── 갓(shade) — 위가 좁은 돔. 잉크 아웃라인은 캐릭터와 톤 통일 ──
    final shade = Path()
      ..moveTo(cx - 26, topY + 20)
      ..quadraticBezierTo(cx - 24, topY + 2, cx - 9, topY - 2)
      ..lineTo(cx + 9, topY - 2)
      ..quadraticBezierTo(cx + 24, topY + 2, cx + 26, topY + 20)
      ..close();
    canvas.drawPath(shade, Paint()..color = _shade);
    // 갓 안쪽 — 켜져 있으면 빛을 머금는다
    if (l > 0.02) {
      canvas.drawPath(
        shade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _shade.withValues(alpha: 0),
              _bulbWarm.withValues(alpha: 0.55 * l),
            ],
          ).createShader(Rect.fromLTWH(cx - 26, topY - 2, 52, 24)),
      );
    }
    canvas.drawPath(
      shade,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CeilingLightPainter old) =>
      old.light != light ||
      old.breath != breath ||
      old.cordCenterFromRight != cordCenterFromRight ||
      old.lampColor != lampColor;
}
