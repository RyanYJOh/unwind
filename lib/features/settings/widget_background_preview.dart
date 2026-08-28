import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/tokens/spacing.dart';
import '../../domain/models/todd_state.dart';
import '../../domain/models/widget_background.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/todd/todd_view.dart';

/// 배경 표시 이름 — 갤러리·페이월 캐러셀이 공유한다
String widgetBackgroundLabel(AppLocalizations l10n, WidgetBackground bg) =>
    switch (bg) {
      WidgetBackground.deepNight => l10n.bgDeepNight,
      WidgetBackground.fireflies => l10n.bgFireflies,
      WidgetBackground.rainWindow => l10n.bgRainWindow,
      WidgetBackground.bigMoon => l10n.bgBigMoon,
      WidgetBackground.starrySea => l10n.bgStarrySea,
      WidgetBackground.firstSnow => l10n.bgFirstSnow,
      WidgetBackground.aurora => l10n.bgAurora,
      WidgetBackground.pastelDream => l10n.bgPastelDream,
      WidgetBackground.blanketFort => l10n.bgBlanketFort,
    };

/// 실제 위젯과 같은 구성의 미리보기 카드 (배경 + 코너 글로우 + 잠든 Todd).
/// 갤러리 카드의 알맹이이자 페이월 캐러셀의 페이지다.
class WidgetBackgroundPreviewCard extends StatelessWidget {
  final WidgetBackground bg;
  final Color accent;
  final double borderRadius;
  final double toddSize;

  const WidgetBackgroundPreviewCard({
    super.key,
    required this.bg,
    required this.accent,
    this.borderRadius = UnwindRadius.lg,
    this.toddSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: WidgetBackgroundPainter(bg: bg, accent: accent),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: UnwindSpacing.s8),
              child: ToddView(
                size: toddSize,
                reduceMotion: reduce,
                state: const ToddState(
                  brightness: 1,
                  isAsleep: true,
                  mode: ToddMode.asleep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 위젯 배경 미리보기 페인터 (선택형 2026-08-28).
///
/// **`ios/ToddWidget/ToddWidget.swift`의 `SceneBackground` 미러** — 장면을
/// 고치면 두 곳을 함께 고칠 것 (§8.5 팔레트 미러와 같은 계약). 좌표는
/// 158×158 기준으로 적고 그리는 크기에 비례 스케일한다.
///
/// 우상단 코너 글로우까지 함께 그린다 — 갤러리 카드가 실제 위젯과 같은
/// 모습이어야 "사면 이렇게 보인다"가 성립한다. 글로우 색은 현재 조명
/// 색(accent)을 받아 따라간다.
class WidgetBackgroundPainter extends CustomPainter {
  final WidgetBackground bg;

  /// 코너 글로우 색 (= UnwindColors.accent). 세기는 미리보기 고정값.
  final Color accent;

  /// 글로우 세기 0..1 — 갤러리는 "불이 좀 남은 방"으로 보여준다
  final double glow;

  const WidgetBackgroundPainter({
    required this.bg,
    required this.accent,
    this.glow = 0.55,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 158;
    final sy = size.height / 158;
    switch (bg) {
      case WidgetBackground.deepNight:
        _deepNight(canvas, size, sx, sy);
      case WidgetBackground.fireflies:
        _fireflies(canvas, size, sx, sy);
      case WidgetBackground.rainWindow:
        _rainWindow(canvas, size, sx, sy);
      case WidgetBackground.bigMoon:
        _bigMoon(canvas, size, sx, sy);
      case WidgetBackground.starrySea:
        _starrySea(canvas, size, sx, sy);
      case WidgetBackground.firstSnow:
        _firstSnow(canvas, size, sx, sy);
      case WidgetBackground.aurora:
        _aurora(canvas, size, sx, sy);
      case WidgetBackground.pastelDream:
        _pastelDream(canvas, size, sx, sy);
      case WidgetBackground.blanketFort:
        _blanketFort(canvas, size, sx, sy);
    }
    _cornerGlow(canvas, size);
  }

  // ── 공용 조각 (Swift 쪽과 1:1) ─────────────────────────────

  void _vGradient(Canvas c, Size s, List<double> stops, List<Color> colors) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, s.height),
          colors,
          stops,
        ),
    );
  }

  /// 우상단 코너 글로우 — ToddWidget.swift의 RadialGradient와 동일 기하
  void _cornerGlow(Canvas c, Size s) {
    final center = Offset(s.width * 1.06, s.height * -0.08);
    c.drawCircle(
      center,
      s.width * 1.15,
      Paint()
        ..shader = ui.Gradient.radial(center, s.width * 1.15, [
          accent.withValues(alpha: 0.62 * glow),
          accent.withValues(alpha: 0.20 * glow),
          accent.withValues(alpha: 0),
        ], const [0.0, 0.5, 1.0]),
    );
  }

  /// 4점 스파클 (NitW·산리오 문법)
  void _sparkle(
    Canvas c,
    double x,
    double y,
    double r,
    double sx,
    double sy, {
    Color color = const Color(0xFFFFF6E8),
    double opacity = 0.85,
  }) {
    const w = 0.22;
    final p = Path()
      ..moveTo(x, y - r)
      ..quadraticBezierTo(x + r * w, y - r * w, x + r, y)
      ..quadraticBezierTo(x + r * w, y + r * w, x, y + r)
      ..quadraticBezierTo(x - r * w, y + r * w, x - r, y)
      ..quadraticBezierTo(x - r * w, y - r * w, x, y - r)
      ..close();
    c.drawPath(
      p.transform((Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)).storage),
      Paint()..color = color.withValues(alpha: opacity),
    );
  }

  /// 가짜 블룸 — 동심 radial (§11 블러 금지 준수)
  void _glowDot(
    Canvas c,
    double x,
    double y,
    double r,
    double sx,
    double sy, {
    required Color seed,
    required Color core,
    required double strength,
  }) {
    final center = Offset(x * sx, y * sy);
    c.drawCircle(
      center,
      r * sx,
      Paint()
        ..shader = ui.Gradient.radial(center, r * sx, [
          seed.withValues(alpha: 0.9 * strength),
          seed.withValues(alpha: 0.18 * strength),
          seed.withValues(alpha: 0),
        ], const [0.0, 0.5, 1.0]),
    );
    c.drawCircle(
      center,
      math.max(1.6, r * 0.34) * sx / 2,
      Paint()..color = core.withValues(alpha: strength),
    );
  }

  Path _poly(List<(double, double)> pts, double sx, double sy) {
    final p = Path()..moveTo(pts.first.$1, pts.first.$2);
    for (final pt in pts.skip(1)) {
      p.lineTo(pt.$1, pt.$2);
    }
    p.close();
    return p.transform(
      (Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)).storage,
    );
  }

  // ── 장면들 ─────────────────────────────────────────────────

  void _deepNight(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 1], const [Color(0xFF0D1520), Color(0xFF070D15)]);
    void star(double x, double y, double r, double o) => c.drawCircle(
      Offset(x * sx, y * sy),
      r * sx,
      Paint()..color = const Color(0xFF9BB0C2).withValues(alpha: o),
    );
    star(22, 19, 1.5, 0.55);
    star(47, 35, 1.0, 0.35);
    star(13, 54, 1.25, 0.40);
  }

  void _fireflies(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 1], const [Color(0xFF0E1F1A), Color(0xFF070F0D)]);
    final hint = Offset(0.18 * s.width, 0.88 * s.height);
    c.drawCircle(
      hint,
      110 * sx,
      Paint()
        ..shader = ui.Gradient.radial(hint, 110 * sx, [
          const Color(0xFF16302A).withValues(alpha: 0.7),
          const Color(0x0016302A),
        ]),
    );
    c.drawPath(
      _poly(const [
        (0, 158), (0, 110), (7, 96), (13, 110), (18, 100), (25, 116),
        (31, 104), (39, 122), (45, 112), (52, 126), (52, 158),
      ], sx, sy),
      Paint()..color = const Color(0xFF050A09),
    );
    const seed = Color(0xFFFFD98A);
    const core = Color(0xFFFFF6E0);
    void fly(double x, double y, double r, double st) =>
        _glowDot(c, x, y, r, sx, sy, seed: seed, core: core, strength: st);
    fly(22, 46, 9, 0.9);
    fly(36, 62, 11, 0.85);
    fly(14, 68, 8, 0.7);
    fly(46, 34, 8, 0.75);
    fly(43, 101, 7, 0.6);
    fly(76, 42, 6, 0.5);
  }

  void _rainWindow(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 0.55, 1], const [
      Color(0xFF22314E),
      Color(0xFF18243A),
      Color(0xFF0C1422),
    ]);
    const streak = Color(0xFF9FB6D4);
    for (final r in const [
      (14.0, 18.0, 26.0), (33.0, 8.0, 34.0), (52.0, 26.0, 28.0),
      (70.0, 6.0, 30.0), (24.0, 60.0, 24.0), (46.0, 72.0, 26.0),
    ]) {
      c.save();
      c.translate(r.$1 * sx, (r.$2 + r.$3 / 2) * sy);
      c.rotate(13 * math.pi / 180);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: 1.3 * sx,
        height: r.$3 * sy,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(0.65 * sx)),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [
              streak.withValues(alpha: 0),
              streak.withValues(alpha: 0.5 * 0.6),
              streak.withValues(alpha: 0),
            ],
            const [0, 0.5, 1],
          ),
      );
      c.restore();
    }
    for (final d in const [
      (26.0, 46.0, 4.2), (58.0, 30.0, 3.2), (41.0, 88.0, 3.6), (14.0, 72.0, 2.6),
    ]) {
      final center = Offset(d.$1 * sx, d.$2 * sy);
      final rect = Rect.fromCenter(
        center: center,
        width: d.$3 * 2 * sx,
        height: d.$3 * 2.5 * sy,
      );
      c.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            center.translate(-d.$3 * 0.3 * sx, -d.$3 * 0.5 * sy),
            d.$3 * 1.6 * sx,
            [
              const Color(0xFFB9CCE4).withValues(alpha: 0.85),
              const Color(0xFF4A6284).withValues(alpha: 0.25),
            ],
          ),
      );
      c.drawCircle(
        center.translate(-d.$3 * 0.38 * sx, -d.$3 * 0.5 * sy),
        0.9 * sx,
        Paint()..color = const Color(0xFFDCE8F6).withValues(alpha: 0.9),
      );
    }
    c.drawRect(
      Rect.fromLTWH(0, 0, 5 * sx, s.height),
      Paint()..color = const Color(0xFF080D16),
    );
    c.drawRect(
      Rect.fromLTWH(0, 60 * sy, s.width, 4 * sy),
      Paint()..color = const Color(0xFF080D16).withValues(alpha: 0.5),
    );
  }

  void _bigMoon(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 0.55, 0.84, 0.93, 1], const [
      Color(0xFF0B1026),
      Color(0xFF182642),
      Color(0xFF3A3D5E),
      Color(0xFF6E5A66),
      Color(0xFF120F1C),
    ]);
    const moon = Color(0xFFE8DFC4);
    final center = Offset(44 * sx, 42 * sy);
    c.drawCircle(
      center,
      40 * sx,
      Paint()
        ..shader = ui.Gradient.radial(center, 40 * sx, [
          moon.withValues(alpha: 0.20),
          moon.withValues(alpha: 0),
        ]),
    );
    c.drawCircle(center, 17 * sx, Paint()..color = moon);
    const maria = Color(0xFFD8CDAE);
    c.drawCircle(
      Offset(38 * sx, 37 * sy),
      4.5 * sx,
      Paint()..color = maria.withValues(alpha: 0.55),
    );
    c.drawCircle(
      Offset(50 * sx, 47 * sy),
      3.2 * sx,
      Paint()..color = maria.withValues(alpha: 0.45),
    );
    c.drawCircle(
      Offset(44 * sx, 52 * sy),
      2.4 * sx,
      Paint()..color = maria.withValues(alpha: 0.4),
    );
    _sparkle(c, 84, 26, 3.4, sx, sy);
    _sparkle(c, 20, 84, 2.8, sx, sy, opacity: 0.7);
    _sparkle(c, 70, 66, 2.2, sx, sy, opacity: 0.55);
    c.drawPath(
      _poly(const [
        (0, 158), (0, 130), (22, 121), (42, 128), (66, 117), (94, 127),
        (128, 114), (158, 125), (158, 158),
      ], sx, sy),
      Paint()..color = const Color(0xFF0A0812),
    );
  }

  void _starrySea(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 0.7, 1], const [
      Color(0xFF131B32),
      Color(0xFF22314C),
      Color(0xFF4E4A5C),
    ]);
    final water = Rect.fromLTWH(0, 88 * sy, s.width, s.height - 88 * sy);
    c.drawRect(
      water,
      Paint()
        ..shader = ui.Gradient.linear(water.topCenter, water.bottomCenter, [
          const Color(0xFF33465E),
          const Color(0xFF16222F),
        ]),
    );
    c.drawRect(
      Rect.fromLTWH(0, 86 * sy, s.width, math.max(1, 1.6 * sy)),
      Paint()..color = const Color(0xFF8A7A72).withValues(alpha: 0.55),
    );
    const warm = Color(0xFFFFB224);
    // 반사 — 폭이 다른 띠 3겹을 겹쳐 좌우 가장자리를 흩는다
    // (한 장짜리 사각 띠는 나무 기둥처럼 읽힌다)
    for (final (w, a) in const [(26.0, 0.10), (17.0, 0.11), (9.0, 0.12)]) {
      final refl = Rect.fromLTWH(
        (109 - w / 2) * sx,
        88 * sy,
        w * sx,
        s.height - 88 * sy,
      );
      c.drawRect(
        refl,
        Paint()
          ..shader = ui.Gradient.linear(refl.topCenter, refl.bottomCenter, [
            warm.withValues(alpha: a),
            warm.withValues(alpha: 0),
          ]),
      );
    }
    for (final b in const [
      (103.0, 96.0, 12.0, 0.22), (100.0, 108.0, 18.0, 0.16),
      (105.0, 120.0, 10.0, 0.12),
    ]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b.$1 * sx, b.$2 * sy, b.$3 * sx, 2 * sy),
          Radius.circular(1 * sx),
        ),
        Paint()..color = warm.withValues(alpha: b.$4),
      );
    }
    _sparkle(c, 24, 30, 3.0, sx, sy);
    _sparkle(c, 58, 18, 2.4, sx, sy, opacity: 0.7);
    _sparkle(c, 38, 56, 2.0, sx, sy, opacity: 0.5);
    _sparkle(c, 78, 40, 1.8, sx, sy, opacity: 0.45);
  }

  void _firstSnow(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 0.6, 1], const [
      Color(0xFF1B2740),
      Color(0xFF121B2C),
      Color(0xFF0A101A),
    ]);
    c.drawPath(
      _poly(const [
        (0, 158), (0, 118), (10, 100), (19, 118), (25, 106), (35, 126),
        (43, 110), (54, 132), (61, 118), (71, 138), (71, 158),
      ], sx, sy),
      Paint()..color = const Color(0xFF0C131E),
    );
    c.drawPath(
      _poly(const [
        (28, 158), (28, 126), (37, 110), (45, 126), (51, 115), (60, 133),
        (67, 119), (77, 139), (77, 158),
      ], sx, sy),
      Paint()..color = const Color(0xFF080D16),
    );
    for (final f in const [
      (22.0, 26.0, 2.2, 0.9), (47.0, 14.0, 1.6, 0.75), (66.0, 34.0, 2.0, 0.8),
      (14.0, 54.0, 1.5, 0.65), (38.0, 46.0, 1.2, 0.55), (58.0, 62.0, 1.8, 0.7),
      (30.0, 78.0, 1.4, 0.5), (72.0, 18.0, 1.3, 0.6), (80.0, 70.0, 1.5, 0.45),
      (10.0, 94.0, 1.7, 0.4),
    ]) {
      c.drawCircle(
        Offset(f.$1 * sx, f.$2 * sy),
        f.$3 * sx,
        Paint()..color = const Color(0xFFE8F0FA).withValues(alpha: f.$4),
      );
    }
    const window = Color(0xFFFFC96B);
    c.drawCircle(
      Offset(47 * sx, 132 * sy),
      6 * sx,
      Paint()..color = window.withValues(alpha: 0.13),
    );
    c.drawCircle(
      Offset(47 * sx, 132 * sy),
      2.6 * sx,
      Paint()..color = window.withValues(alpha: 0.85),
    );
  }

  void _aurora(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 1], const [Color(0xFF0A1024), Color(0xFF060A16)]);
    const violet = Color(0xFF9A5FD0);
    const teal = Color(0xFF4FD9A8);
    void curtain(List<(double, double)> pts, double top, double mid) {
      final p = Path()..moveTo(pts[0].$1, pts[0].$2);
      for (var i = 1; i < pts.length - 1; i += 2) {
        p.quadraticBezierTo(
          pts[i].$1,
          pts[i].$2,
          pts[i + 1].$1,
          pts[i + 1].$2,
        );
      }
      p.close();
      final scaled = p.transform(
        (Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)).storage,
      );
      // 커튼을 두 번 — 넓게 흩은 겹 + 본체. 가장자리가 잎사귀처럼
      // 딱딱해지는 것을 막는다 (§11 블러 금지 — 겹침으로 흉내)
      final b = scaled.getBounds();
      for (final (widen, k) in const [(1.45, 0.35), (1.0, 1.0)]) {
        final soft = scaled.transform(
          (Matrix4.identity()
                ..translateByDouble(b.center.dx * (1 - widen), 0, 0, 1)
                ..scaleByDouble(widen, 1, 1, 1))
              .storage,
        );
        c.drawPath(
          soft,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(0, s.height),
              [
                violet.withValues(alpha: top * k),
                teal.withValues(alpha: mid * k),
                teal.withValues(alpha: 0),
              ],
              const [0, 0.45, 1],
            ),
        );
      }
    }

    curtain(const [
      (8, 0), (22, 26), (24, 78), (30, 98), (18, 122),
      (4, 90), (2, 58), (2, 30), (8, 0),
    ], 0.55, 0.45);
    curtain(const [
      (44, 0), (60, 30), (58, 84), (63, 104), (53, 124),
      (38, 88), (36, 56), (38, 28), (44, 0),
    ], 0.38, 0.30);
    curtain(const [
      (78, 0), (89, 22), (88, 64), (93, 82), (85, 96),
      (72, 66), (71, 40), (73, 20), (78, 0),
    ], 0.27, 0.21);
    _sparkle(c, 112, 24, 2.6, sx, sy);
    _sparkle(c, 132, 58, 2.2, sx, sy, opacity: 0.7);
    _sparkle(c, 96, 74, 1.8, sx, sy, opacity: 0.5);
    _sparkle(c, 26, 110, 1.8, sx, sy, opacity: 0.4);
  }

  void _pastelDream(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 0.6, 1], const [
      Color(0xFF251A38),
      Color(0xFF1C1329),
      Color(0xFF120C1B),
    ]);
    const cloud = Color(0xFF392B52);
    void puff(double x, double y, double w, double h, double o) {
      final paint = Paint()..color = cloud.withValues(alpha: o);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy),
          Radius.circular(h / 2 * sy),
        ),
        paint,
      );
      c.drawCircle(
        Offset((x + w * 0.3) * sx, (y + h * 0.2) * sy),
        h * 0.65 * sx,
        paint,
      );
      c.drawCircle(
        Offset((x + w * 0.72) * sx, (y + h * 0.28) * sy),
        h * 0.5 * sx,
        paint,
      );
    }

    puff(0, 78, 84, 26, 0.55);
    puff(92, 104, 66, 22, 0.5);
    const cream = Color(0xFFFFF3C4);
    // 달무리 — 평면 원은 원판 자국이 남는다. radial로 흩어 준다
    final haloC = Offset(46 * sx, 34 * sy);
    c.drawCircle(
      haloC,
      34 * sx,
      Paint()
        ..shader = ui.Gradient.radial(haloC, 34 * sx, [
          cream.withValues(alpha: 0.12),
          cream.withValues(alpha: 0),
        ]),
    );
    final big = Path()
      ..addOval(const Rect.fromLTWH(26, 22, 40, 40));
    final bite = Path()
      ..addOval(const Rect.fromLTWH(38, 16, 40, 40));
    final crescent = Path.combine(PathOperation.difference, big, bite)
        .transform((Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)).storage);
    c.drawPath(crescent, Paint()..color = cream);
    const gold = Color(0xFFF7D774);
    _sparkle(c, 80, 20, 3.6, sx, sy, color: gold);
    _sparkle(c, 22, 58, 2.8, sx, sy, color: gold, opacity: 0.8);
    _sparkle(c, 96, 52, 2.2, sx, sy, color: gold, opacity: 0.6);
    _sparkle(c, 66, 74, 1.8, sx, sy, color: gold, opacity: 0.45);
  }

  void _blanketFort(Canvas c, Size s, double sx, double sy) {
    _vGradient(c, s, [0, 0.5, 1], const [
      Color(0xFF2A1B26),
      Color(0xFF180F18),
      Color(0xFF0C070C),
    ]);
    const fold = Color(0xFF3A2534);
    void wedge(List<(double, double)> pts, double o) {
      c.drawPath(
        _poly(pts, sx, sy),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), [
            fold.withValues(alpha: 0.85 * o),
            fold.withValues(alpha: 0),
          ]),
      );
    }

    wedge(const [(79, 0), (12, 158), (0, 158), (0, 0)], 0.5);
    wedge(const [(79, 0), (40, 158), (26, 158), (70, 0)], 0.38);
    wedge(const [(79, 0), (123, 158), (110, 158), (72, 0)], 0.3);
    final scallop = Path()
      ..moveTo(0, 0)
      ..lineTo(158, 0)
      ..lineTo(158, 18);
    for (var x = 158.0; x > 0; x -= 18) {
      scallop.quadraticBezierTo(x - 9, 27, x - 18, 18);
    }
    scallop.close();
    c.drawPath(
      scallop.transform(
        (Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)).storage,
      ),
      Paint()..color = fold.withValues(alpha: 0.55),
    );
    c.drawRect(
      Rect.fromLTWH(0, 0, s.width, 11 * sy),
      Paint()..color = const Color(0xFF241722),
    );
  }

  @override
  bool shouldRepaint(WidgetBackgroundPainter old) =>
      old.bg != bg || old.accent != accent || old.glow != glow;
}
