import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'ghost_contract.dart' show GhostEvent;

/// Rive 브리프의 캐릭터 사양을 Flutter로 구현한 렌더러.
/// (Rive 에디터 없이 동일한 표현 — .riv가 생기면 GhostView가 자동으로 Rive 사용)
///
/// 브리프 §4 블렌드(awake↔drowsy) + 타임라인 C~F 대응:
///   - 눈꺼풀 Y (0 → 3/4 덮음, 과장), 흰자 흰색→분홍(#FFD8D8)
///   - 다크서클 0→35%, 동공 100→70%, 하이라이트 100→0%, 머리 0→5도
///   - 부유: 진폭 크고 주기 짧음 → 진폭 작고 주기 김
///   - yawn(1.5s) / checkBounce(0.5s 통통) / fallAsleep(zzz) / happyWake
/// 확정 결정: 충혈선 없음. 물결은 Flutter라 진짜로 구현(졸릴수록 감쇠).
class GhostPainterView extends StatefulWidget {
  final double sleepiness;
  final GhostEvent? event;
  final int eventTick;
  final double size;
  final bool reduceMotion;

  const GhostPainterView({
    super.key,
    required this.sleepiness,
    this.event,
    this.eventTick = 0,
    this.size = 240,
    this.reduceMotion = false,
  });

  @override
  State<GhostPainterView> createState() => _GhostPainterViewState();
}

class _GhostPainterViewState extends State<GhostPainterView>
    with TickerProviderStateMixin {
  // 부유·물결·zzz 공용 위상 — 주기를 sleepiness에 따라 연속 변조하기 위해
  // AnimationController 대신 Ticker로 위상을 직접 적분한다.
  late final Ticker _ticker;
  double _phase = 0; // 라디안이 아닌 사이클 단위 (1.0 = 한 바퀴)
  Duration _lastTick = Duration.zero;

  late final AnimationController _yawn; // 타임라인 C, 1.5s
  late final AnimationController _bounce; // 타임라인 D, 0.5s
  late final AnimationController _sleep; // 타임라인 E 진입/해제
  late final AnimationController _happy; // 타임라인 F, 1.6s
  late final AnimationController _blink; // PRD §7.3 깜빡임 (180ms)

  Timer? _yawnTimer;
  Timer? _blinkTimer;
  DateTime _lastEventAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _seenTick = -1;
  final _rng = math.Random();

  bool get _asleep => widget.event == GhostEvent.allDone;

  @override
  void initState() {
    super.initState();
    _yawn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _sleep = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _happy = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));

    _ticker = createTicker(_onTick);
    if (!widget.reduceMotion) _ticker.start();
    if (_asleep) _sleep.value = 1.0;

    _startYawnTimer();
    _scheduleBlink();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // 부유 주기: 깨어있을 때 ~2.6s, 졸릴수록 ~5s, 잠들면 ~7s (브리프 §4)
    final t = widget.sleepiness.clamp(0.0, 1.0);
    final period = _asleep ? 7.0 : _lerp(2.6, 5.0, t);
    setState(() => _phase = (_phase + dt / period) % 1000);
  }

  /// 브리프 §6.3 — sleepiness가 높을수록 자주 하품. 이벤트 직후 2초 금지.
  void _startYawnTimer() {
    _yawnTimer?.cancel();
    _yawnTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.reduceMotion || _asleep) return;
      if (_yawn.isAnimating || _happy.isAnimating) return;
      if (DateTime.now().difference(_lastEventAt).inSeconds < 2) return;
      final chance = widget.sleepiness * 0.4; // 최대 40%
      if (_rng.nextDouble() < chance) _yawn.forward(from: 0);
    });
  }

  /// PRD §7.3 깜빡임 — 4~8초 랜덤. 졸려서 눈이 반쯤 감겼으면 생략.
  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
        Duration(milliseconds: 4000 + _rng.nextInt(4000)), () async {
      if (!mounted) return;
      if (!widget.reduceMotion &&
          !_asleep &&
          widget.sleepiness < 0.75 &&
          !_yawn.isAnimating) {
        await _blink.forward(from: 0);
        if (mounted) await _blink.reverse();
      }
      if (mounted) _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(GhostPainterView old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion != old.reduceMotion) {
      if (widget.reduceMotion) {
        _ticker.stop();
      } else if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }

    final wasAsleep = old.event == GhostEvent.allDone;
    if (!wasAsleep && _asleep) {
      _lastEventAt = DateTime.now();
      _sleep.forward();
    } else if (wasAsleep && !_asleep) {
      _sleep.reverse();
    }

    if (widget.event != null &&
        widget.eventTick != _seenTick &&
        widget.event != GhostEvent.allDone) {
      _seenTick = widget.eventTick;
      _lastEventAt = DateTime.now();
      switch (widget.event!) {
        case GhostEvent.checkOff:
          _bounce.forward(from: 0); // 통통 (브리프 D)
        case GhostEvent.wakeUpHappy:
          _happy.forward(from: 0);
        case GhostEvent.allDone:
          break;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _yawnTimer?.cancel();
    _blinkTimer?.cancel();
    _yawn.dispose();
    _bounce.dispose();
    _sleep.dispose();
    _happy.dispose();
    _blink.dispose();
    super.dispose();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation:
            Listenable.merge([_yawn, _bounce, _sleep, _happy, _blink]),
        builder: (context, _) {
          final t = widget.sleepiness.clamp(0.0, 1.0);
          final s = Curves.easeInOut.transform(_sleep.value);

          // 타임라인 C: 하품 — 0.3s 상승 / 0.7s 유지 / 0.5s 복귀
          final yp = _yawn.value;
          final yawnAmt = yp <= 0
              ? 0.0
              : yp < 0.2
                  ? Curves.easeOut.transform(yp / 0.2)
                  : yp < 0.667
                      ? 1.0
                      : 1.0 -
                          Curves.easeInOut.transform((yp - 0.667) / 0.333);

          // 타임라인 D: 통통 — 감쇠 사인 스케일 펄스
          final bp = _bounce.value;
          final bounceScale = bp <= 0 || bp >= 1
              ? 0.0
              : math.sin(bp * math.pi * 2) * (1 - bp) * 0.09;

          // 타임라인 F: 기지개 + 미소 + 하이라이트 반짝
          final hAmt = math.sin(_happy.value * math.pi);

          // 눈꺼풀: 블렌드 0→3/4 (과장) + 하품/취침 시 완전 감김 + 깜빡임
          final lidBase = 0.75 * t;
          final lid = math.max(
              math.max(lidBase, math.max(yawnAmt, s)),
              _blink.value);

          return CustomPaint(
            size: Size.square(widget.size),
            painter: _GhostPainter(
              phase: _phase,
              sleepiness: t,
              asleepProgress: s,
              lidCover: lid.clamp(0.0, 1.0),
              scleraColor: Color.lerp(const Color(0xFFFFFFFF),
                  const Color(0xFFFFD8D8), t)!, // 분홍 (연분홍 금지)
              darkCircleOpacity: 0.35 * t * (1 - s * 0.5),
              pupilScale: _lerp(1.0, 0.7, t),
              highlightOpacity:
                  (_lerp(1.0, 0.0, t) + hAmt).clamp(0.0, 1.0),
              headTiltDeg: 5.0 * t * (1 - s),
              floatAmp: (widget.reduceMotion
                      ? 0.0
                      : _lerp(6.0, 2.0, t) * (1 - s * 0.7)) /
                  240 *
                  widget.size,
              hemAmp: widget.reduceMotion ? 0.0 : (1 - t * 0.7) * (1 - s),
              bodyScale: 1.0 +
                  bounceScale +
                  0.05 * yawnAmt +
                  0.06 * hAmt +
                  (s > 0.99 && !widget.reduceMotion
                      ? math.sin(_phase * 2 * math.pi * 0.7) * 0.008
                      : 0.0),
              mouthOpen: yawnAmt,
              smile: hAmt,
              zzzOpacity: s,
            ),
          );
        },
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  final double phase;
  final double sleepiness;
  final double asleepProgress;
  final double lidCover;
  final Color scleraColor;
  final double darkCircleOpacity;
  final double pupilScale;
  final double highlightOpacity;
  final double headTiltDeg;
  final double floatAmp;
  final double hemAmp;
  final double bodyScale;
  final double mouthOpen;
  final double smile;
  final double zzzOpacity;

  const _GhostPainter({
    required this.phase,
    required this.sleepiness,
    required this.asleepProgress,
    required this.lidCover,
    required this.scleraColor,
    required this.darkCircleOpacity,
    required this.pupilScale,
    required this.highlightOpacity,
    required this.headTiltDeg,
    required this.floatAmp,
    required this.hemAmp,
    required this.bodyScale,
    required this.mouthOpen,
    required this.smile,
    required this.zzzOpacity,
  });

  static const _bodyColor = Color(0xFFFDFCF8);
  static const _pupilColor = Color(0xFF2A2430);
  static const _glowColor = Color(0xFFF2C482);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 240; // 기준 크기 240 대비 배율
    final cx = size.width / 2;
    final floatY = math.sin(phase * 2 * math.pi) * floatAmp;
    final cy = size.height / 2 + floatY + asleepProgress * 8 * u;

    final bodyW = 130.0 * u;
    final bodyH = 150.0 * u;
    final top = cy - bodyH / 2;
    final bottom = cy + bodyH / 2;

    // ── glow — 졸릴수록 은은하게 (PRD §7.1, RadialGradient만) ──
    final glowStrength =
        (0.25 + 0.75 * sleepiness) * (asleepProgress > 0 ? 0.8 : 1.0);
    final glowR = bodyW * (0.95 + 0.25 * glowStrength);
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          _glowColor.withValues(alpha: 0.30 * glowStrength),
          _glowColor.withValues(alpha: 0.0),
        ]).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: glowR)),
    );

    // ── 몸통 스케일 (통통·기지개·하품·취침 호흡) ──
    canvas.save();
    canvas.translate(cx, cy + bodyH * 0.3);
    canvas.scale(bodyScale);
    canvas.translate(-cx, -(cy + bodyH * 0.3));

    // ── 팔 — 물방울형, 부유와 살짝 어긋난 스윙. happy 때 위로 ──
    final armSway = math.sin(phase * 2 * math.pi + 1.2) * 5 * hemAmp;
    final armRaise = smile * 38;
    for (final (dir, swayPhase) in [(-1, 0.0), (1, 0.6)]) {
      canvas.save();
      final armX = cx + dir * bodyW * 0.52;
      final armY = cy + bodyH * 0.06;
      canvas.translate(armX, armY);
      canvas.rotate((dir * (18 + armSway + swayPhase * 2 - armRaise)) *
          math.pi /
          180);
      final arm = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, 10 * u), width: 22 * u, height: 40 * u),
        Radius.circular(11 * u),
      );
      canvas.drawRRect(arm, Paint()..color = _bodyColor);
      canvas.restore();
    }

    // ── 몸통 (타원 상단 + 물결 밑단 — Flutter라 진짜 물결) ──
    final body = Path()..moveTo(cx - bodyW / 2, bottom);
    body.lineTo(cx - bodyW / 2, top + bodyH * 0.38);
    body.quadraticBezierTo(cx - bodyW / 2, top, cx, top);
    body.quadraticBezierTo(
        cx + bodyW / 2, top, cx + bodyW / 2, top + bodyH * 0.38);
    body.lineTo(cx + bodyW / 2, bottom);
    const waves = 4;
    final waveW = bodyW / waves;
    final amp = bodyH * 0.045 * hemAmp +
        bodyH * 0.028 * math.sin(phase * 2 * math.pi * 1.5) * hemAmp;
    for (var i = 0; i < waves; i++) {
      final x0 = cx + bodyW / 2 - waveW * i;
      final dip = bodyH * 0.05 +
          amp * (0.6 + 0.4 * math.sin(phase * 2 * math.pi * 1.5 + i * 0.9));
      body.quadraticBezierTo(x0 - waveW / 2, bottom + dip, x0 - waveW, bottom);
    }
    body.close();
    canvas.drawPath(body, Paint()..color = _bodyColor);

    // ── 머리 그룹 (꾸벅 기울기 — 눈·다크서클·입이 함께 회전) ──
    final headCx = cx;
    final headCy = top + bodyH * 0.40;
    canvas.save();
    canvas.translate(headCx, headCy);
    canvas.rotate(headTiltDeg * math.pi / 180);
    canvas.translate(-headCx, -headCy);

    final eyeDx = bodyW * 0.21;
    final eyeRx = 15.0 * u;
    final eyeRy = 17.0 * u;

    for (final dir in [-1, 1]) {
      final ec = Offset(headCx + dir * eyeDx, headCy);

      if (asleepProgress > 0.95) {
        // 완전히 잠듦 — 감은 눈 곡선 한 줄
        final p = Path()
          ..moveTo(ec.dx - eyeRx * 0.8, ec.dy)
          ..quadraticBezierTo(
              ec.dx, ec.dy + eyeRy * 0.55, ec.dx + eyeRx * 0.8, ec.dy);
        canvas.drawPath(
          p,
          Paint()
            ..color = _pupilColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * u
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      // 흰자 — 흰색→분홍 블렌드. 몸통 위에서 읽히도록 옅은 림.
      final scleraRect =
          Rect.fromCenter(center: ec, width: eyeRx * 2, height: eyeRy * 2);
      canvas.drawOval(scleraRect, Paint()..color = scleraColor);
      canvas.drawOval(
        scleraRect,
        Paint()
          ..color = _pupilColor.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * u,
      );

      // 동공 + 하이라이트 (흰자에 클립)
      canvas.save();
      canvas.clipPath(Path()..addOval(scleraRect));
      final pupilR = 7.5 * u * pupilScale;
      canvas.drawCircle(
          ec.translate(0, eyeRy * 0.12), pupilR, Paint()..color = _pupilColor);
      if (highlightOpacity > 0.01) {
        canvas.drawCircle(
          ec.translate(-pupilR * 0.35, eyeRy * 0.12 - pupilR * 0.4),
          2.6 * u,
          Paint()
            ..color =
                const Color(0xFFFFFFFF).withValues(alpha: highlightOpacity),
        );
      }

      // 눈꺼풀 — 몸통색이 위에서 내려와 덮는다 (브리프 §3 원리)
      if (lidCover > 0.01) {
        final lidH = eyeRy * 2 * lidCover;
        canvas.drawRect(
          Rect.fromLTWH(
              ec.dx - eyeRx - 1, ec.dy - eyeRy - 1, eyeRx * 2 + 2, lidH + 1),
          Paint()..color = _bodyColor,
        );
        // 눈꺼풀 가장자리 — 감기는 게 읽히도록
        canvas.drawLine(
          Offset(ec.dx - eyeRx * 0.9, ec.dy - eyeRy + lidH),
          Offset(ec.dx + eyeRx * 0.9, ec.dy - eyeRy + lidH),
          Paint()
            ..color = _pupilColor.withValues(alpha: 0.18)
            ..strokeWidth = 1.4 * u
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();

      // 다크서클 — 눈 아래 반달 (충혈선은 사용자 결정으로 제외)
      if (darkCircleOpacity > 0.01) {
        final p = Path()
          ..moveTo(ec.dx - eyeRx * 0.72, ec.dy + eyeRy * 0.86)
          ..quadraticBezierTo(ec.dx, ec.dy + eyeRy * 1.28,
              ec.dx + eyeRx * 0.72, ec.dy + eyeRy * 0.86);
        canvas.drawPath(
          p,
          Paint()
            ..color =
                const Color(0xFF9B7B8A).withValues(alpha: darkCircleOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6 * u
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── 입 — 평상시 아주 작게 / 하품 세로 확대 / happy 미소 ──
    final mouthC = Offset(headCx, headCy + eyeRy * 1.9);
    if (smile > 0.05 && mouthOpen < 0.1) {
      final p = Path()
        ..moveTo(mouthC.dx - 9 * u, mouthC.dy - 2 * u)
        ..quadraticBezierTo(
            mouthC.dx, mouthC.dy + 7 * u * smile, mouthC.dx + 9 * u,
            mouthC.dy - 2 * u);
      canvas.drawPath(
        p,
        Paint()
          ..color = _pupilColor.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * u
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final openScale = 1.0 + 1.8 * mouthOpen; // ScaleY 100→280%
      canvas.drawOval(
        Rect.fromCenter(
            center: mouthC,
            width: 9.0 * u * (1.0 + 0.3 * mouthOpen),
            height: 5.0 * u * openScale),
        Paint()
          ..color = Color.lerp(const Color(0xFF4A4050),
              const Color(0xFF362E3E), mouthOpen)!,
      );
    }

    canvas.restore(); // 머리 그룹
    canvas.restore(); // 몸통 스케일

    // ── zzz — 잠들 때만, 페이드인 + 상승 루프 ──
    if (zzzOpacity > 0.02) {
      final baseX = cx + bodyW * 0.55;
      final baseY = top + 6 * u;
      for (var i = 0; i < 3; i++) {
        final p = (phase * 0.35 + i / 3) % 1.0;
        final alpha =
            zzzOpacity * math.sin(p * math.pi) * (0.35 + 0.2 * i);
        if (alpha <= 0.01) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              fontSize: (11.0 + i * 5) * u,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8E86A8).withValues(alpha: alpha),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(baseX + i * 12 * u + p * 6 * u,
                baseY - p * 34 * u - i * 10 * u));
      }
    }
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.phase != phase ||
      old.sleepiness != sleepiness ||
      old.asleepProgress != asleepProgress ||
      old.lidCover != lidCover ||
      old.scleraColor != scleraColor ||
      old.darkCircleOpacity != darkCircleOpacity ||
      old.pupilScale != pupilScale ||
      old.highlightOpacity != highlightOpacity ||
      old.headTiltDeg != headTiltDeg ||
      old.floatAmp != floatAmp ||
      old.hemAmp != hemAmp ||
      old.bodyScale != bodyScale ||
      old.mouthOpen != mouthOpen ||
      old.smile != smile ||
      old.zzzOpacity != zzzOpacity;
}
