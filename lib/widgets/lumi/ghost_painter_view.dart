import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/models/lumi_state.dart' show LumiMode, LumiDayActivity;
import 'ghost_contract.dart' show GhostEvent;

/// Rive 브리프의 캐릭터 사양을 Flutter로 구현한 렌더러.
/// (Rive 에디터 없이 동일한 표현 — .riv가 생기면 GhostView가 자동으로 Rive 사용)
///
/// 브리프 §4 블렌드(awake↔drowsy) + 타임라인 C~F 대응:
///   - 눈꺼풀 Y (0 → 3/4 덮음, 과장)
///   - 다크서클 0→35%, 동공 100→70%, 하이라이트 100→0%, 머리 0→5도
///   - 흰자는 항상 흰색 (분홍 블렌드는 사용자 결정으로 제외)
///   - 부유: 진폭 크고 주기 짧음 → 진폭 작고 주기 김
///   - yawn(1.5s) / checkBounce(0.5s 통통) / fallAsleep(zzz) / happyWake
/// 확정 결정: 충혈선 없음. 물결은 Flutter라 진짜로 구현(졸릴수록 감쇠).
class GhostPainterView extends StatefulWidget {
  final double sleepiness;
  final GhostEvent? event;
  final int eventTick;
  final double size;
  final bool reduceMotion;

  /// 생활 모드 (개편 2026-08-08). null = 기존 sleepiness 매핑(하위 호환).
  /// 활동·밤 연출은 본체 디자인과 분리된 소품/모션 레이어로 그린다 —
  /// 유령 외형이 바뀌어도 이 레이어는 그대로 얹힌다.
  final LumiMode? mode;
  final LumiDayActivity? activity;
  final double dazzle;

  const GhostPainterView({
    super.key,
    required this.sleepiness,
    this.event,
    this.eventTick = 0,
    this.size = 240,
    this.reduceMotion = false,
    this.mode,
    this.activity,
    this.dazzle = 0.0,
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

  /// 모드가 주어지면 시각·상황이 졸림을 결정한다 (개편 2026-08-08).
  /// - 낮: 말똥말똥 (rest 슬롯만 살짝 나른)
  /// - 밤(못 잠): 눈부실수록 덜 감기고(찡그림), 어두울수록 무겁게 감긴다
  double get _effSleepiness {
    final base = widget.sleepiness.clamp(0.0, 1.0);
    return switch (widget.mode) {
      null => base,
      LumiMode.day => widget.activity == LumiDayActivity.rest ? 0.30 : 0.06,
      LumiMode.nightAwake => _lerp(0.68, 0.45, widget.dazzle.clamp(0.0, 1.0)),
      LumiMode.asleep => math.max(base, 0.85),
    };
  }

  @override
  void initState() {
    super.initState();
    _yawn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sleep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _happy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

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
    final t = _effSleepiness;
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
      final chance = _effSleepiness * 0.4; // 최대 40% — 낮엔 거의 없음
      if (_rng.nextDouble() < chance) _yawn.forward(from: 0);
    });
  }

  /// PRD §7.3 깜빡임 — 4~8초 랜덤. 졸려서 눈이 반쯤 감겼으면 생략.
  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 4000 + _rng.nextInt(4000)),
      () async {
        if (!mounted) return;
        if (!widget.reduceMotion &&
            !_asleep &&
            _effSleepiness < 0.75 &&
            !_yawn.isAnimating) {
          await _blink.forward(from: 0);
          if (mounted) await _blink.reverse();
        }
        if (mounted) _scheduleBlink();
      },
    );
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
        animation: Listenable.merge([_yawn, _bounce, _sleep, _happy, _blink]),
        builder: (context, _) {
          final t = _effSleepiness;
          final s = Curves.easeInOut.transform(_sleep.value);

          // 타임라인 C: 하품 — 0.3s 상승 / 0.7s 유지 / 0.5s 복귀
          final yp = _yawn.value;
          final yawnAmt = yp <= 0
              ? 0.0
              : yp < 0.2
              ? Curves.easeOut.transform(yp / 0.2)
              : yp < 0.667
              ? 1.0
              : 1.0 - Curves.easeInOut.transform((yp - 0.667) / 0.333);

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
            _blink.value,
          );

          return CustomPaint(
            size: Size.square(widget.size),
            painter: _GhostPainter(
              phase: _phase,
              sleepiness: t,
              asleepProgress: s,
              // 생활 레이어 (개편 2026-08-08) — 잠들면 활동·밤 연출 없음
              activity: widget.mode == LumiMode.day && s < 0.5
                  ? widget.activity
                  : null,
              nightDoze: widget.mode == LumiMode.nightAwake && s < 0.5,
              dazzle: widget.dazzle.clamp(0.0, 1.0),
              lidCover: lid.clamp(0.0, 1.0),
              // 흰자는 항상 흰색 — 분홍 블렌드는 사용자 결정으로 제거
              scleraColor: const Color(0xFFFFFFFF),
              darkCircleOpacity: 0.35 * t * (1 - s * 0.5),
              pupilScale: _lerp(1.0, 0.7, t),
              highlightOpacity: (_lerp(1.0, 0.0, t) + hAmt).clamp(0.0, 1.0),
              headTiltDeg: 5.0 * t * (1 - s),
              floatAmp:
                  (widget.reduceMotion
                      ? 0.0
                      : _lerp(6.0, 2.0, t) * (1 - s * 0.7)) /
                  240 *
                  widget.size,
              hemAmp: widget.reduceMotion ? 0.0 : (1 - t * 0.7) * (1 - s),
              bodyScale:
                  1.0 +
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

  /// 낮 일과 (null = 없음). 소품·모션은 본체와 분리된 레이어로 그린다.
  final LumiDayActivity? activity;

  /// 밤에 못 자는 상태 — 꾸벅꾸벅 조는 사이클 + 눈부심 연출
  final bool nightDoze;

  /// 눈부심 (방에 남은 빛). 높으면 빛을 가리고, 낮으면 존다.
  final double dazzle;

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
    this.activity,
    this.nightDoze = false,
    this.dazzle = 0.0,
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

  // ── 팔레트 (전면 개편 2026-08-09: 첨부 레퍼런스 매칭) ──
  static const _bodyColor = Color(0xFFFFFFFF);
  static const _pupilColor = Color(0xFF1E1A2E); // 눈 = 잉크와 동일 (솔리드)
  static const _glowColor = Color(0xFFF2C482);
  static const _blushColor = Color(0xFFFFAEBB); // 옅고 맑은 볼터치
  static const _tongueColor = Color(0xFFF5899E); // 혀
  static const _cavityColor = Color(0xFF2A2233); // 입 안

  /// 두꺼운 잉크 아웃라인 — 레퍼런스의 네이비 잉크
  static const _inkColor = Color(0xFF1E1A2E);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 240; // 기준 크기 240 대비 배율
    final cx = size.width / 2;
    final floatY = math.sin(phase * 2 * math.pi) * floatAmp;
    final cy = size.height / 2 + floatY + asleepProgress * 8 * u;

    // ── 산책 (12~14시): 방 안을 이리저리 떠다닌다. 통통 튀는 걸음 보브 +
    //    진행 방향으로 살짝 기울기 — 전체(글로우 포함)가 함께 움직인다.
    canvas.save(); // 전체 이동 레이어
    double leanDeg = 0;
    if (activity == LumiDayActivity.walk) {
      final wp = phase * 2 * math.pi * 0.16;
      final wanderX = math.sin(wp) * 26 * u;
      final bob = math.sin(phase * 2 * math.pi * 1.3).abs() * 3.5 * u;
      // 이동 방향으로 확실히 기울인다 (개정 2026-08-09: 4° → 8°)
      leanDeg = math.cos(wp) * 8.0;
      canvas.translate(wanderX, -bob);
    } else if (activity == LumiDayActivity.hum) {
      // 콧노래 (14~16시): 리듬 타는 좌우 스웨이
      leanDeg = math.sin(phase * 2 * math.pi * 0.5) * 2.4;
    }

    // 레퍼런스 비율: 둥근 머리는 비교적 좁고, 아래로 갈수록 몸이 넓어진다.
    final bodyW = 154.0 * u;
    final bodyH = 168.0 * u;
    final top = cy - bodyH / 2;
    final bottom = cy + bodyH / 2 - 8 * u; // 물결이 아래로 부풀 여백

    // ── glow — 졸릴수록 은은하게 (PRD §7.1, RadialGradient만) ──
    final glowStrength =
        (0.25 + 0.75 * sleepiness) * (asleepProgress > 0 ? 0.8 : 1.0);
    final glowR = bodyW * (0.95 + 0.25 * glowStrength);
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _glowColor.withValues(alpha: 0.30 * glowStrength),
            _glowColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR)),
    );

    // ── 몸통 스케일 (통통·기지개·하품·취침 호흡) + 기울기/스트레칭 ──
    canvas.save();
    canvas.translate(cx, cy + bodyH * 0.3);
    if (leanDeg != 0) canvas.rotate(leanDeg * math.pi / 180);
    canvas.scale(bodyScale);
    if (activity == LumiDayActivity.stretch) {
      // 아침 스트레칭 (06~08시): 위로 쭉 — 세로 늘어남
      final st = math.sin(phase * 2 * math.pi * 0.45).abs();
      canvas.scale(1.0 - 0.015 * st, 1.0 + 0.045 * st);
    }
    canvas.translate(-cx, -(cy + bodyH * 0.3));

    // ── 손 (개정 2026-08-09, 첨부 레퍼런스):
    //    타원이 아니라 몸 옆에서 자연스럽게 솟는 짧은 플리퍼 실루엣.
    //    활동 모션은 유지하되 평상시 크기와 돌출량을 작게 제한한다.
    final armSway = math.sin(phase * 2 * math.pi + 1.2) * 4 * hemAmp;
    final armRaise = smile * 20;
    // 활동별 손 자세 — 좌우가 다르게 움직일 수 있다
    double activityRaise(int dir) {
      switch (activity) {
        case LumiDayActivity.stretch:
          // 만세 스트레칭 — 좌우 번갈아 위로 쭉
          final st = math.sin(phase * 2 * math.pi * 0.45);
          return (dir == -1 ? math.max(0.0, st) : math.max(0.0, -st)) * 38.0;
        case LumiDayActivity.coffee:
          return dir == 1 ? 14.0 : 0.0; // 오른손이 잔 쪽으로
        case LumiDayActivity.read:
          return -12.0; // 두 손이 책 쪽으로 내려온다
        case LumiDayActivity.hum:
          // 리듬 타기 — 박자에 맞춰 들썩
          return 6.0 * math.sin(phase * 2 * math.pi * 0.5 + dir * 0.9);
        case LumiDayActivity.snack:
          return dir == 1 ? 12.0 : -4.0; // 오른손이 쿠키 쪽으로
        default:
          return 0.0;
      }
    }

    bool showBaseArm(int dir) {
      return switch (activity) {
        // 오른팔은 소품까지 이어지는 전용 팔로 대체한다.
        LumiDayActivity.coffee || LumiDayActivity.snack => dir == -1,
        // 책 아래에 양팔을 새로 그리므로 바깥 기본 팔은 모두 숨긴다.
        LumiDayActivity.read => false,
        _ => true,
      };
    }

    for (final dir in [-1, 1]) {
      if (!showBaseArm(dir)) continue;
      canvas.save();
      final armX = cx + dir * bodyW * 0.46;
      final armY = cy - bodyH * 0.03;
      canvas.translate(armX, armY);
      canvas.scale(dir.toDouble(), 1); // 좌우 미러
      final upDeg = 18.0 + armSway + armRaise + activityRaise(dir);
      final deg = upDeg * (1 - asleepProgress) - 30.0 * asleepProgress;
      canvas.rotate(-deg * math.pi / 180);
      final hand = Path()
        ..moveTo(-8 * u, 10 * u)
        ..cubicTo(-2 * u, -2 * u, 6 * u, -12 * u, 15 * u, -12 * u)
        ..cubicTo(25 * u, -12 * u, 29 * u, -4 * u, 27 * u, 4 * u)
        ..cubicTo(24 * u, 14 * u, 14 * u, 22 * u, 2 * u, 25 * u)
        ..cubicTo(-3 * u, 22 * u, -7 * u, 17 * u, -8 * u, 10 * u)
        ..close();
      final handBounds = hand.getBounds();
      canvas.drawPath(
        hand,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFFF8F7FC),
              Color(0xFFE8E7F3),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(handBounds),
      );
      canvas.drawPath(
        hand,
        Paint()
          ..color = _inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2 * u
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // ── 몸통 (개정 2026-08-09, 첨부 레퍼런스 재현):
    //    머리는 정확한 반원에 가까운 돔. 좁은 어깨에서 시작한 옆선이
    //    아래로 갈수록 계속 넓어져 통통한 하단과 연결된다.
    final w2 = bodyW / 2;
    final domeR = w2 * 0.79; // 머리 폭 < 하단 폭
    final domeBaseY = top + domeR; // 반원이 옆선과 만나는 높이
    final hemHalf = w2 * 0.98;
    const waves = 4;
    final segW = hemHalf * 2 / waves;
    final body = Path()..moveTo(cx - hemHalf, bottom);
    // 왼쪽 옆선: 밑단에서는 수평, 돔에서는 수직 접선으로 연결한다.
    // 양 끝의 접선 방향을 맞춰 머리·몸통·밑단 사이 꺾임을 없앤다.
    body.cubicTo(
      cx - hemHalf - segW * 0.18,
      bottom,
      cx - domeR,
      domeBaseY + bodyH * 0.28,
      cx - domeR,
      domeBaseY,
    );
    // 돔: 정확한 반원 호
    body.arcToPoint(
      Offset(cx + domeR, domeBaseY),
      radius: Radius.circular(domeR),
      clockwise: true,
    );
    // 오른쪽 옆선 (미러)
    body.cubicTo(
      cx + domeR,
      domeBaseY + bodyH * 0.28,
      cx + hemHalf + segW * 0.18,
      bottom,
      cx + hemHalf,
      bottom,
    );
    // 물결 밑단 — 봉우리와 골 모두 수평 접선을 갖는 낮고 둥근 스캘럽.
    // quadratic 한 개로 그릴 때 생기던 봉우리의 뾰족한 cusp를 제거한다.
    final amp = bodyH * 0.018 * hemAmp * math.sin(phase * 2 * math.pi * 1.5);
    for (var i = 0; i < waves; i++) {
      final startX = cx + hemHalf - segW * i;
      final endX = cx + hemHalf - segW * (i + 1);
      final midX = (startX + endX) / 2;
      final dip =
          bodyH * 0.062 +
          amp * (0.6 + 0.4 * math.sin(phase * 2 * math.pi * 1.5 + i * 0.9));
      body
        ..cubicTo(
          startX - segW * 0.22,
          bottom,
          midX + segW * 0.22,
          bottom + dip,
          midX,
          bottom + dip,
        )
        ..cubicTo(
          midX - segW * 0.22,
          bottom + dip,
          endX + segW * 0.22,
          bottom,
          endX,
          bottom,
        );
    }
    body.close();

    // 채움: 흰 돔에서 라벤더빛 하단으로 이어지는 부드러운 입체감.
    final bodyBounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFEFF),
            Color(0xFFF8F7FC),
            Color(0xFFE8E7F4),
          ],
          stops: const [0.0, 0.44, 0.72, 1.0],
        ).createShader(bodyBounds),
    );
    canvas.save();
    canvas.clipPath(body);
    // 좌하단 라벤더 음영 — 레퍼런스처럼 밑단 굴곡을 따라 진해진다.
    final shL = Offset(cx - w2 * 0.42, bottom + 3 * u);
    canvas.drawCircle(
      shL,
      w2 * 1.05,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFC9C8E8).withValues(alpha: 0.46),
            const Color(0xFFD9D6E4).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: shL, radius: w2 * 1.05)),
    );
    // 우하단은 푸른 라벤더로 옅게 받쳐 좌우 볼륨을 분리한다.
    final shR = Offset(cx + w2 * 0.48, bottom + 1 * u);
    canvas.drawCircle(
      shR,
      w2 * 0.72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD9DAF3).withValues(alpha: 0.34),
            const Color(0xFFD9DAF3).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: shR, radius: w2 * 0.72)),
    );
    // 중앙의 옅은 흰 광택과 정수리 하이라이트(블러 없이 gradient).
    final centerLight = Offset(cx, top + bodyH * 0.48);
    canvas.drawOval(
      Rect.fromCenter(
        center: centerLight,
        width: bodyW * 0.72,
        height: bodyH * 0.72,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: 0.38),
                const Color(0xFFFFFFFF).withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: centerLight, radius: bodyW * 0.48),
            ),
    );
    final hlC = Offset(cx - bodyW * 0.14, top + bodyH * 0.14);
    canvas.drawCircle(
      hlC,
      bodyW * 0.40,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.6),
            const Color(0xFFFFFFFF).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: hlC, radius: bodyW * 0.40)),
    );
    canvas.restore();
    // 레퍼런스의 둥글고 짙은 네이비 외곽선.
    canvas.drawPath(
      body,
      Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2 * u
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // ── 꾸벅꾸벅 (밤, 개편 2026-08-08) — 고개가 천천히 떨어지다 화들짝
    //    되돌아오는 사이클. 눈부실수록(dazzle↑) 잠이 달아나 덜 존다.
    double doze = 0;
    if (nightDoze) {
      final p = (phase * 0.55) % 1.0; // 부유 주기 대비 ~7초 사이클
      final raw = p < 0.72
          ? Curves.easeInOut.transform(p / 0.72) // 스르르 떨어지고
          : p < 0.86
          ? 1.0 -
                Curves.easeOut.transform((p - 0.72) / 0.14) // 화들짝
          : 0.0; // 잠깐 말똥
      doze = raw * (1 - dazzle * 0.7);
    }

    // ── 머리 그룹 (꾸벅 기울기 — 눈·볼·입이 함께 회전) ──
    final headCx = cx;
    final headCy = top + bodyH * 0.42;
    canvas.save();
    canvas.translate(headCx, headCy);
    canvas.rotate((headTiltDeg + doze * 13.0) * math.pi / 180);
    canvas.translate(-headCx, -headCy + doze * 5 * u);

    // 졸리면 눈 전체가 살짝 작아지고 홍채도 수축한다.
    final eyeScale = 0.85 + 0.15 * pupilScale;
    // 눈부심 (개정 2026-08-08): 소품 없이 표정으로 — 눈을 가늘게 찡그린다
    final squint = nightDoze ? ((dazzle - 0.45) / 0.55).clamp(0.0, 1.0) : 0.0;
    // 졸림 변화가 작은 홈 크기에서도 읽히도록 레퍼런스보다 눈을 약 15% 강조.
    final eyeDx = 26.0 * u;
    final eyeRx = 13.5 * u * eyeScale;
    final eyeRy = 18.0 * u * eyeScale * (1 - 0.68 * squint);

    // 독서 (10~12시): 시선이 책으로 — 눈이 살짝 아래로 내려온다
    final eyeYOff = activity == LumiDayActivity.read ? 3.0 * u : 0.0;

    for (final dir in [-1, 1]) {
      final ec = Offset(headCx + dir * eyeDx, headCy + eyeYOff);

      if (asleepProgress > 0.95) {
        // 완전히 잠듦 — 감은 눈 곡선 한 줄
        final p = Path()
          ..moveTo(ec.dx - eyeRx * 1.0, ec.dy)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy + eyeRy * 0.55,
            ec.dx + eyeRx * 1.0,
            ec.dy,
          );
        canvas.drawPath(
          p,
          Paint()
            ..color = _pupilColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2 * u
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      // 눈 — 세미리얼 구조: 입체적인 흰자 + 홍채 + 동공 + 캐치라이트.
      // 세로형 비율은 레퍼런스의 귀여움을 유지하고 내부 구조만 실제 눈처럼 만든다.
      final eyeRect = Rect.fromCenter(
        center: ec,
        width: eyeRx * 2,
        height: eyeRy * 2,
      );
      canvas.drawOval(
        eyeRect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.25, -0.35),
            radius: 0.9,
            colors: [Color(0xFFFFFFFF), Color(0xFFF9FAFF), Color(0xFFD8DCEB)],
            stops: [0.0, 0.62, 1.0],
          ).createShader(eyeRect),
      );

      // 홍채는 정면을 보되 독서 중에는 책을 향해 조금 내려간다.
      final gazeY = activity == LumiDayActivity.read ? 2.2 * u : 0.4 * u;
      final irisCenter = ec.translate(0, gazeY);
      final irisRect = Rect.fromCenter(
        center: irisCenter,
        width: eyeRx * 1.18 * pupilScale,
        height: eyeRy * 1.28 * pupilScale,
      );
      canvas.drawOval(
        irisRect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.25, -0.30),
            radius: 0.82,
            colors: [Color(0xFF66739C), Color(0xFF303853), Color(0xFF111425)],
            stops: [0.0, 0.50, 1.0],
          ).createShader(irisRect),
      );
      canvas.drawOval(
        irisRect,
        Paint()
          ..color = _inkColor.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * u,
      );

      final pupilRect = Rect.fromCenter(
        center: irisCenter.translate(0, 0.8 * u),
        width: eyeRx * 0.48 * pupilScale,
        height: eyeRy * 0.70 * pupilScale,
      );
      canvas.drawOval(pupilRect, Paint()..color = const Color(0xFF080A14));

      // 두 개의 반사광으로 촉촉한 눈의 깊이를 만든다. 졸릴수록 약해진다.
      final catchlightAlpha = (0.62 + highlightOpacity * 0.38 + smile * 0.15)
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        irisCenter.translate(-eyeRx * 0.24, -eyeRy * 0.30),
        2.5 * u,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: catchlightAlpha),
      );
      canvas.drawCircle(
        irisCenter.translate(eyeRx * 0.20, eyeRy * 0.23),
        1.1 * u,
        Paint()
          ..color = const Color(
            0xFFFFFFFF,
          ).withValues(alpha: catchlightAlpha * 0.72),
      );

      // 눈의 외곽과 윗눈꺼풀을 분리해 실제 눈처럼 깊이감을 준다.
      canvas.drawOval(
        eyeRect,
        Paint()
          ..color = _inkColor.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * u,
      );
      final upperLid = Path()
        ..moveTo(ec.dx - eyeRx * 0.86, ec.dy - eyeRy * 0.42)
        ..quadraticBezierTo(
          ec.dx,
          ec.dy - eyeRy * 1.06,
          ec.dx + eyeRx * 0.86,
          ec.dy - eyeRy * 0.42,
        );
      canvas.drawPath(
        upperLid,
        Paint()
          ..color = _inkColor.withValues(alpha: 0.68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * u
          ..strokeCap = StrokeCap.round,
      );

      // 실제 눈꺼풀처럼 위·아래 곡면이 홍채 위를 덮는다.
      // 꾸벅일 때는 윗눈꺼풀이 무겁게 내려오고, 눈부실 때는 양쪽에서
      // 조여져 가느다란 눈 틈만 남는다.
      final lidWithDoze = (lidCover + doze * 0.30).clamp(0.0, 1.0);
      final effLid = lidWithDoze < 0.10 ? 0.0 : (lidWithDoze - 0.10) / 0.90;
      final upperCover = (effLid + squint * 0.50).clamp(0.0, 1.0);
      final lowerCover = (squint * 0.42 + doze * 0.08).clamp(0.0, 0.48);
      if (upperCover > 0.01 || lowerCover > 0.01) {
        canvas.save();
        canvas.clipPath(Path()..addOval(eyeRect));

        final upperY = ec.dy - eyeRy + eyeRy * 2 * upperCover;
        final upperCurve = eyeRy * (0.10 + 0.10 * upperCover);
        final upperLidShape = Path()
          ..moveTo(ec.dx - eyeRx - 2 * u, ec.dy - eyeRy - 2 * u)
          ..lineTo(ec.dx + eyeRx + 2 * u, ec.dy - eyeRy - 2 * u)
          ..lineTo(ec.dx + eyeRx + 2 * u, upperY - upperCurve)
          ..quadraticBezierTo(
            ec.dx,
            upperY + upperCurve,
            ec.dx - eyeRx - 2 * u,
            upperY - upperCurve,
          )
          ..close();
        canvas.drawPath(
          upperLidShape,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Color(0xFFFFFFFF), Color(0xFFECEAF3)],
            ).createShader(eyeRect),
        );

        if (lowerCover > 0.01) {
          final lowerY = ec.dy + eyeRy - eyeRy * 2 * lowerCover;
          final lowerCurve = eyeRy * (0.08 + 0.08 * lowerCover);
          final lowerLidShape = Path()
            ..moveTo(ec.dx - eyeRx - 2 * u, lowerY + lowerCurve)
            ..quadraticBezierTo(
              ec.dx,
              lowerY - lowerCurve,
              ec.dx + eyeRx + 2 * u,
              lowerY + lowerCurve,
            )
            ..lineTo(ec.dx + eyeRx + 2 * u, ec.dy + eyeRy + 2 * u)
            ..lineTo(ec.dx - eyeRx - 2 * u, ec.dy + eyeRy + 2 * u)
            ..close();
          canvas.drawPath(
            lowerLidShape,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0xFFF4F2F8), Color(0xFFFFFFFF)],
              ).createShader(eyeRect),
          );
        }
        canvas.restore();

        // 눈꺼풀 가장자리: 직선 대신 실제 눈처럼 완만한 곡선.
        if (upperCover > 0.12) {
          final upperEdge = Path()
            ..moveTo(ec.dx - eyeRx * 0.92, upperY - upperCurve * 0.85)
            ..quadraticBezierTo(
              ec.dx,
              upperY + upperCurve,
              ec.dx + eyeRx * 0.92,
              upperY - upperCurve * 0.85,
            );
          canvas.drawPath(
            upperEdge,
            Paint()
              ..color = _inkColor.withValues(alpha: 0.34 + squint * 0.46)
              ..style = PaintingStyle.stroke
              ..strokeWidth = (1.7 + squint * 0.9) * u
              ..strokeCap = StrokeCap.round,
          );
        }
        if (lowerCover > 0.08) {
          final lowerY = ec.dy + eyeRy - eyeRy * 2 * lowerCover;
          final lowerCurve = eyeRy * (0.08 + 0.08 * lowerCover);
          final lowerEdge = Path()
            ..moveTo(ec.dx - eyeRx * 0.88, lowerY + lowerCurve * 0.8)
            ..quadraticBezierTo(
              ec.dx,
              lowerY - lowerCurve,
              ec.dx + eyeRx * 0.88,
              lowerY + lowerCurve * 0.8,
            );
          canvas.drawPath(
            lowerEdge,
            Paint()
              ..color = _inkColor.withValues(alpha: 0.26 + squint * 0.38)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6 * u
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      // 강한 눈부심: 눈을 꽉 압착하고, 안쪽이 올라간 눈썹과 바깥 눈꼬리
      // 주름으로 화난 표정이 아닌 "빛 때문에 괴로운" 표정을 만든다.
      if (squint > 0.35) {
        final pain = ((squint - 0.35) / 0.65).clamp(0.0, 1.0);

        // 꽉 감긴 윗눈꺼풀의 압력선.
        final pressureLid = Path()
          ..moveTo(ec.dx - eyeRx * 0.98, ec.dy + eyeRy * 0.10)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy - eyeRy * (0.74 + pain * 0.18),
            ec.dx + eyeRx * 0.98,
            ec.dy + eyeRy * 0.10,
          );
        canvas.drawPath(
          pressureLid,
          Paint()
            ..color = _inkColor.withValues(alpha: 0.30 + pain * 0.62)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (2.0 + pain * 1.2) * u
            ..strokeCap = StrokeCap.round,
        );

        // 안쪽이 들린 눈썹 — 고통·당황 신호, 중앙을 내리는 화난 눈썹과 반대.
        final outerBrow = Offset(
          ec.dx + dir * eyeRx * 0.92,
          ec.dy - eyeRy * (1.20 + pain * 0.08),
        );
        final innerBrow = Offset(
          ec.dx - dir * eyeRx * 0.72,
          ec.dy - eyeRy * (1.46 + pain * 0.16),
        );
        final brow = Path()
          ..moveTo(outerBrow.dx, outerBrow.dy)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy - eyeRy * (1.34 + pain * 0.12),
            innerBrow.dx,
            innerBrow.dy,
          );
        canvas.drawPath(
          brow,
          Paint()
            ..color = _inkColor.withValues(alpha: 0.24 + pain * 0.56)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1.5 + pain * 0.8) * u
            ..strokeCap = StrokeCap.round,
        );

        // 바깥 눈꼬리의 짧은 수축 주름 두 개.
        final corner = Offset(ec.dx + dir * eyeRx * 0.96, ec.dy + eyeRy * 0.02);
        for (final yDir in [-1.0, 1.0]) {
          canvas.drawLine(
            corner,
            corner.translate(
              dir * (3.5 + pain * 2.5) * u,
              yDir * (2.0 + pain * 1.6) * u,
            ),
            Paint()
              ..color = _inkColor.withValues(alpha: 0.18 + pain * 0.44)
              ..strokeWidth = 1.4 * u
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      // 다크서클 — 눈 아래 은은한 반달 (졸림 신호, 카와이 톤으로 절제)
      if (darkCircleOpacity > 0.01) {
        final p = Path()
          ..moveTo(ec.dx - eyeRx * 0.7, ec.dy + eyeRy * 1.1)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy + eyeRy * 1.45,
            ec.dx + eyeRx * 0.7,
            ec.dy + eyeRy * 1.1,
          );
        canvas.drawPath(
          p,
          Paint()
            ..color = const Color(
              0xFF9B7B8A,
            ).withValues(alpha: darkCircleOpacity * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * u
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── 안경 (독서, 개정 2026-08-09) — 둥근 뿔테 + 은은한 렌즈 반사 ──
    if (activity == LumiDayActivity.read && asleepProgress < 0.5) {
      final gy = headCy + eyeYOff;
      final lensR = 14.5 * u;
      final framePaint = Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * u;
      for (final dir in [-1, 1]) {
        final c = Offset(headCx + dir * eyeDx, gy);
        canvas.drawCircle(
          c,
          lensR,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.14),
        );
        canvas.drawCircle(c, lensR, framePaint);
      }
      // 브리지 — 두 렌즈 안쪽을 잇는 짧은 아치
      final bridge = Path()
        ..moveTo(headCx - (eyeDx - lensR) - 1 * u, gy - 3 * u)
        ..quadraticBezierTo(
          headCx,
          gy - 7 * u,
          headCx + (eyeDx - lensR) + 1 * u,
          gy - 3 * u,
        );
      canvas.drawPath(bridge, framePaint);
      // 다리 — 렌즈 바깥으로 짧게
      for (final dir in [-1, 1]) {
        canvas.drawLine(
          Offset(headCx + dir * (eyeDx + lensR), gy - 1 * u),
          Offset(headCx + dir * (eyeDx + lensR + 6 * u), gy - 4 * u),
          framePaint,
        );
      }
    }

    // ── 볼터치 — 레퍼런스의 분홍 블러시 (RadialGradient, 블러 금지 §11) ──
    final blushAlpha = (0.45 + 0.25 * smile) * (1 - asleepProgress * 0.35);
    for (final dir in [-1, 1]) {
      final bc = Offset(headCx + dir * (eyeDx + 19 * u), headCy + 11 * u);
      final blushR = 10.0 * u;
      canvas.drawOval(
        Rect.fromCenter(
          center: bc,
          width: blushR * 2.25,
          height: blushR * 1.35,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              _blushColor.withValues(alpha: blushAlpha),
              _blushColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: bc, radius: blushR * 1.3)),
      );
    }

    // ── 입 — 기본: 혀가 보이는 열린 미소 (레퍼런스).
    //    졸릴수록 작아지고, 하품 때 크게 열리고, 잠들면 감은 미소.
    final mouthC = Offset(headCx, headCy + 27 * u);
    final restSmile = activity == LumiDayActivity.rest && asleepProgress <= 0.6;
    if (mouthOpen > 0.08) {
      // 하품 (개정 2026-08-09) — 웃는 입이 아니라 진짜 동그란 하품.
      // 크게 벌어진 O + 아래쪽 작은 혀.
      final yw = 10.5 * u * (0.55 + 0.45 * mouthOpen);
      final yh = 14.5 * u * (0.30 + 0.70 * mouthOpen);
      final yawnRect = Rect.fromCenter(
        center: mouthC.translate(0, yh * 0.15),
        width: yw * 2,
        height: yh * 2,
      );
      canvas.drawOval(yawnRect, Paint()..color = _cavityColor);
      canvas.save();
      canvas.clipPath(Path()..addOval(yawnRect));
      canvas.drawOval(
        Rect.fromCenter(
          center: mouthC.translate(0, yh * 1.0),
          width: yw * 1.6,
          height: yh * 1.0,
        ),
        Paint()..color = _tongueColor,
      );
      canvas.restore();
      canvas.drawOval(
        yawnRect,
        Paint()
          ..color = _inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * u,
      );
    } else if (asleepProgress > 0.6 || restSmile) {
      // 잠들었을 때/저녁 휴식 — 낮고 잔잔한 만족 곡선
      final sm = asleepProgress > 0.6
          ? ((asleepProgress - 0.6) / 0.4).clamp(0.0, 1.0)
          : 0.8;
      final p = Path()
        ..moveTo(mouthC.dx - 8 * u, mouthC.dy - 1.5 * u)
        ..quadraticBezierTo(
          mouthC.dx,
          mouthC.dy + 5.5 * u * sm,
          mouthC.dx + 8 * u,
          mouthC.dy - 1.5 * u,
        );
      canvas.drawPath(
        p,
        Paint()
          ..color = _inkColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * u
          ..strokeCap = StrokeCap.round,
      );
    } else if (nightDoze) {
      // 밤새 못 자는 입 (개정 2026-08-09) — 살짝 처진 곡선, 힘들다.
      final p = Path()
        ..moveTo(mouthC.dx - 6.5 * u, mouthC.dy + 1 * u)
        ..quadraticBezierTo(
          mouthC.dx,
          mouthC.dy - 2.6 * u,
          mouthC.dx + 6.5 * u,
          mouthC.dy + 1 * u,
        );
      canvas.drawPath(
        p,
        Paint()
          ..color = _inkColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 * u
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // 열린 미소 — 위 입술은 살짝 스마일 곡선, 아래는 둥근 주머니.
      // 크기: 졸리면 축소, happy·하품이면 확대
      final shrink = 1 - 0.40 * sleepiness * (1 - mouthOpen);
      // 간식 (16~18시): 오물오물 — 입이 리듬에 맞춰 조였다 벌어진다
      final chew = activity == LumiDayActivity.snack
          ? 0.72 + 0.22 * math.sin(phase * 2 * math.pi * 1.15).abs()
          : 1.0;
      final aw = 12.5 * u * shrink * (1 + 0.20 * smile + 0.30 * mouthOpen);
      final ah =
          11.0 * u * shrink * chew * (1 + 0.45 * smile + 1.5 * mouthOpen);
      canvas.save();
      canvas.translate(mouthC.dx, mouthC.dy);
      final mouth = Path()
        ..moveTo(-aw, -ah * 0.22)
        // 위 입술 — 가운데가 살짝 내려오는 스마일
        ..quadraticBezierTo(0, ah * 0.02, aw, -ah * 0.22)
        // 오른쪽 → 아래 둥근 주머니 → 왼쪽
        ..cubicTo(aw * 1.10, ah * 0.45, aw * 0.55, ah, 0, ah)
        ..cubicTo(-aw * 0.55, ah, -aw * 1.10, ah * 0.45, -aw, -ah * 0.22)
        ..close();
      canvas.drawPath(mouth, Paint()..color = _cavityColor);
      // 혀 — 아래쪽 절반을 채우는 분홍 (클립)
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, ah * 0.72),
          width: aw * 1.5,
          height: ah * 1.05,
        ),
        Paint()..color = _tongueColor,
      );
      canvas.restore();
      // 입 아웃라인 (개정 2026-08-09: 얇게)
      canvas.drawPath(
        mouth,
        Paint()
          ..color = _inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * u
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }

    canvas.restore(); // 머리 그룹

    // ── 낮 일과 소품 (개편 2026-08-08) — 본체 디자인과 분리된 레이어.
    //    유령 몸 앞에 떠 있는 소품이라 외형이 바뀌어도 그대로 얹힌다.
    switch (activity) {
      case LumiDayActivity.read:
        _paintBook(canvas, u, cx, cy, bodyH);
      case LumiDayActivity.coffee:
        _paintCoffee(canvas, u, cx, cy, bodyH);
      case LumiDayActivity.snack:
        _paintCookie(canvas, u, cx, cy, bodyH);
      default:
        break;
    }

    canvas.restore(); // 몸통 스케일

    // ── 콧노래 음표 (14~16시) — zzz와 같은 문법의 상승 루프 ──
    if (activity == LumiDayActivity.hum) {
      for (var i = 0; i < 2; i++) {
        final p = (phase * 0.30 + i * 0.5) % 1.0;
        final alpha = math.sin(p * math.pi) * 0.6;
        if (alpha <= 0.02) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: i.isEven ? '♪' : '♫',
            style: TextStyle(
              fontSize: (13.0 + i * 4) * u,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFA99BC9).withValues(alpha: alpha),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            cx + bodyW * 0.42 + i * 11 * u + math.sin(p * 2 * math.pi) * 4 * u,
            top + 4 * u - p * 30 * u,
          ),
        );
      }
    }

    // ── zzz — 잠들 때만, 페이드인 + 상승 루프 ──
    if (zzzOpacity > 0.02) {
      final baseX = cx + bodyW * 0.55;
      final baseY = top + 6 * u;
      for (var i = 0; i < 3; i++) {
        final p = (phase * 0.35 + i / 3) % 1.0;
        final alpha = zzzOpacity * math.sin(p * math.pi) * (0.35 + 0.2 * i);
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
          Offset(
            baseX + i * 12 * u + p * 6 * u,
            baseY - p * 34 * u - i * 10 * u,
          ),
        );
      }
    }

    canvas.restore(); // 전체 이동 레이어
  }

  // ── 낮 일과 소품들 (개편 2026-08-08, 개정 2026-08-09: 손에 쥔 소품) ──

  /// 소품을 감싸 쥔 작은 손 — 소품 위에 겹쳐 그려 "들고 있음"을 만든다.
  void _paintHoldingHand(
    Canvas canvas,
    double u,
    Offset p, {
    double scale = 1,
  }) {
    final hand = Rect.fromCenter(
      center: p,
      width: 14 * u * scale,
      height: 11 * u * scale,
    );
    canvas.drawOval(hand, Paint()..color = _bodyColor);
    canvas.drawOval(
      hand,
      Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * u
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 독서 (10~12시): 펼친 책 — 더 크게 (개정 2026-08-09), 양손이 받친다.
  void _paintBook(Canvas canvas, double u, double cx, double cy, double bodyH) {
    final y =
        cy +
        bodyH * 0.14 +
        math.sin(phase * 2 * math.pi + 0.6) * 1.5 * u; // 부유 딜레이
    const pageFill = Color(0xFFFBF5E6);
    final ink = Paint()
      ..color = _inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * u
      ..strokeJoin = StrokeJoin.round;

    for (final dir in [-1, 1]) {
      final page = Path()
        ..moveTo(cx, y) // 스파인 위
        ..lineTo(cx + dir * 42 * u, y - 12 * u) // 바깥 위 (펼침 각)
        ..lineTo(cx + dir * 42 * u, y + 16 * u)
        ..lineTo(cx, y + 25 * u) // 스파인 아래
        ..close();
      canvas.drawPath(page, Paint()..color = pageFill);
      canvas.drawPath(page, ink);
      // 글줄 — 페이지 기울기를 따라 세 줄
      for (var line = 0; line < 3; line++) {
        final ly = y + (3.0 + line * 5.0) * u;
        canvas.drawLine(
          Offset(cx + dir * 6 * u, ly + 1.6 * u),
          Offset(cx + dir * 35 * u, ly - 5.0 * u),
          Paint()
            ..color = _inkColor.withValues(alpha: 0.28)
            ..strokeWidth = 1.6 * u
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    // 양손이 책 아래 모서리를 받친다
    _paintHoldingHand(canvas, u, Offset(cx - 37 * u, y + 15 * u), scale: 1.2);
    _paintHoldingHand(canvas, u, Offset(cx + 37 * u, y + 15 * u), scale: 1.2);
  }

  /// 커피 (08~10시): 김이 오르는 잔 — 더 크게, 손에 쥔다
  /// (개정 2026-08-09). 주기적으로 홀짝 들어올린다.
  void _paintCoffee(
    Canvas canvas,
    double u,
    double cx,
    double cy,
    double bodyH,
  ) {
    final sip = (phase * 0.14) % 1.0;
    final lift = sip > 0.78 && sip < 0.94
        ? math.sin((sip - 0.78) / 0.16 * math.pi)
        : 0.0;
    final mc = Offset(cx + 34 * u, cy + bodyH * 0.12 - lift * 16 * u);

    // 김 — 잔이 입가로 올라가 있지 않을 때만
    if (lift < 0.3) {
      for (var k = 0; k < 2; k++) {
        final swirl = math.sin(phase * 2 * math.pi * 0.9 + k * 2.4);
        final sx = mc.dx - 5 * u + k * 10 * u;
        final steam = Path()
          ..moveTo(sx, mc.dy - 17 * u)
          ..quadraticBezierTo(
            sx + swirl * 4 * u,
            mc.dy - 24 * u,
            sx + swirl * 1.5 * u,
            mc.dy - 31 * u,
          );
        canvas.drawPath(
          steam,
          Paint()
            ..color = const Color(
              0xFFCFC7DE,
            ).withValues(alpha: 0.32 + 0.12 * swirl.abs())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * u
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 잔 본체 + 호박색 띠 + 손잡이 — 크게 (개정 2026-08-09)
    final mug = RRect.fromRectAndRadius(
      Rect.fromCenter(center: mc, width: 34 * u, height: 29 * u),
      Radius.circular(6 * u),
    );
    canvas.drawRRect(mug, Paint()..color = const Color(0xFFFFFDF8));
    canvas.save();
    canvas.clipRRect(mug);
    canvas.drawRect(
      Rect.fromLTWH(mc.dx - 17 * u, mc.dy - 4 * u, 34 * u, 8 * u),
      Paint()..color = const Color(0xFFE8913D),
    );
    canvas.restore();
    canvas.drawRRect(
      mug,
      Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * u
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: mc.translate(20 * u, 0), radius: 8.5 * u),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * u
        ..strokeCap = StrokeCap.round,
    );
    // 손이 잔을 감싸 쥔다
    _paintHoldingHand(
      canvas,
      u,
      Offset(mc.dx - 15 * u, mc.dy + 8 * u),
      scale: 1.15,
    );
  }

  /// 간식 (16~18시): 초코칩 쿠키 — 더 크게, 손에 쥔다 (개정 2026-08-09).
  /// 한 입씩 사라졌다가 새 쿠키로.
  void _paintCookie(
    Canvas canvas,
    double u,
    double cx,
    double cy,
    double bodyH,
  ) {
    final cc = Offset(cx + 27 * u, cy + bodyH * 0.08);
    final r = 14.0 * u;
    final biteN = (((phase * 0.08) % 1.0) * 4).floor(); // 0~3입

    Path cookie = Path()..addOval(Rect.fromCircle(center: cc, radius: r));
    // 위-왼쪽부터 반원형 베어문 자국
    const biteSpots = [
      Offset(-0.7, -0.7),
      Offset(0.1, -1.0),
      Offset(0.8, -0.55),
    ];
    for (var b = 0; b < biteN && b < biteSpots.length; b++) {
      final bite = Path()
        ..addOval(
          Rect.fromCircle(
            center: cc.translate(biteSpots[b].dx * r, biteSpots[b].dy * r),
            radius: r * 0.52,
          ),
        );
      cookie = Path.combine(PathOperation.difference, cookie, bite);
    }
    canvas.drawPath(cookie, Paint()..color = const Color(0xFFD9A05B));
    canvas.drawPath(
      cookie,
      Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * u
        ..strokeJoin = StrokeJoin.round,
    );
    // 초코칩
    for (final chip in const [
      Offset(-0.35, 0.05),
      Offset(0.25, 0.4),
      Offset(0.15, -0.25),
      Offset(-0.15, 0.55),
    ]) {
      canvas.drawCircle(
        cc.translate(chip.dx * r, chip.dy * r),
        2.0 * u,
        Paint()..color = _inkColor.withValues(alpha: 0.55),
      );
    }
    // 손이 쿠키를 쥔다 — 아래쪽 가장자리
    _paintHoldingHand(
      canvas,
      u,
      Offset(cc.dx - r * 0.75, cc.dy + r * 0.6),
      scale: 1.15,
    );
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.phase != phase ||
      old.sleepiness != sleepiness ||
      old.asleepProgress != asleepProgress ||
      old.activity != activity ||
      old.nightDoze != nightDoze ||
      old.dazzle != dazzle ||
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
