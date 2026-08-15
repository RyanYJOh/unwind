import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../../core/tokens/design_variant.dart';
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

  /// 전날 밤 불을 남긴 채 잤다 (세계관 2026-08-15) — 평소와 똑같이
  /// 행동하지만 눈 밑에 옅은 다크서클이 하루 종일 남는다.
  final bool darkCircles;

  /// 유휴 위상의 시작값 (신설 2026-08-15) — **정지 프레임 도구 전용**.
  /// 위젯 스프라이트 추출기가 reduceMotion(틱 정지) 상태에서도 꾸벅·콧물
  /// 방울·식은땀 같은 위상 기반 연출의 대표 순간을 담을 수 있게 한다.
  /// 앱 화면에서는 기본값 0을 쓴다.
  final double initialPhase;

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
    this.darkCircles = false,
    this.initialPhase = 0.0,
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
  late final AnimationController _bounce; // 타임라인 D — 체크 축하, 0.8s
  late final AnimationController _sleep; // 타임라인 E 진입/해제
  late final AnimationController _happy; // 타임라인 F, 1.6s
  late final AnimationController _blink; // PRD §7.3 깜빡임 (180ms)

  /// 사용자가 Lumi를 톡 건드렸을 때 (개편 2026-08-12).
  /// 하나의 컨트롤러로 두 반응을 재생한다 — 어느 쪽인지는 [_pokeIsPeek].
  late final AnimationController _poke;
  bool _pokeIsPeek = false;

  Timer? _yawnTimer;
  Timer? _blinkTimer;
  DateTime _lastEventAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _seenTick = -1;
  final _rng = math.Random();

  bool get _asleep => widget.event == GhostEvent.allDone;

  /// 몸통 PNG (개편 2026-08-12, kLumiBodyStyle.image) — 앱 전역 1회 로드.
  /// 로드 전에는 painted 몸통으로 그려 빈 몸을 보이지 않는다.
  static ui.Image? _bodyImage;
  static Future<ui.Image>? _bodyImageLoading;

  void _ensureBodyImage() {
    if (kLumiBodyStyle != LumiBodyStyle.image || _bodyImage != null) return;
    _bodyImageLoading ??= () async {
      final data = await rootBundle.load(kGhostBodyAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }();
    _bodyImageLoading!.then((img) {
      _bodyImage = img;
      if (mounted) setState(() {});
    });
  }

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
      // 체크 축하 (개편 2026-08-15): 통통 스케일 + 폴짝 + 웃는 눈 + 반짝이.
      // 연속 체크 때 겹치지 않게 짧게 유지하되, 기쁨이 읽힐 만큼은 길게.
      duration: const Duration(milliseconds: 800),
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
    _poke = AnimationController(vsync: this, duration: _tickleDuration);

    _phase = widget.initialPhase;
    _ticker = createTicker(_onTick);
    if (!widget.reduceMotion) _ticker.start();
    if (_asleep) _sleep.value = 1.0;
    _ensureBodyImage();

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
        case GhostEvent.poke:
          _firePoke();
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
    _poke.dispose();
    super.dispose();
  }

  static const _tickleDuration = Duration(milliseconds: 1300);
  static const _peekDuration = Duration(milliseconds: 2200);

  /// 톡 건드렸다 — 반응은 **지금 상태가 고른다**.
  /// - 잠들었으면 아무것도 하지 않는다 (깨우지 않는 게 이 앱의 예의다)
  /// - 졸린 밤이면 실눈을 겨우 떠 두리번거린다
  /// - 그 외(낮·말똥말똥)엔 간지럼을 탄다
  Future<void> _firePoke() async {
    if (_asleep || widget.reduceMotion) return;
    if (_poke.isAnimating) return; // 연타로 겹치지 않게
    final peek = widget.mode == LumiMode.nightAwake || _effSleepiness >= 0.55;
    _poke.duration = peek ? _peekDuration : _tickleDuration;
    setState(() => _pokeIsPeek = peek);
    await _poke.forward(from: 0);
    if (mounted) _poke.value = 0;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _yawn,
          _bounce,
          _sleep,
          _happy,
          _blink,
          _poke,
        ]),
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

          // 타임라인 D: 체크 축하 (개편 2026-08-15) — 등 하나를 끌 때마다
          // 짜릿하게 기뻐한다. 통통 스케일 + 폴짝 점프 + 웃는 ∩∩ 눈 +
          // 반짝이 버스트. 심리적 보상이 목적이라 확실히 보여야 한다.
          final bp = _bounce.value;
          final bounceScale = bp <= 0 || bp >= 1
              ? 0.0
              : math.sin(bp * math.pi * 2) * (1 - bp) * 0.11;
          // 기쁨 엔벨로프 — 확 벅차올랐다가 서서히 잦아든다
          final joy = (widget.reduceMotion || bp <= 0 || bp >= 1)
              ? 0.0
              : bp < 0.12
              ? Curves.easeOut.transform(bp / 0.12)
              : 1.0 - Curves.easeInOutCubic.transform((bp - 0.12) / 0.88);
          // 폴짝 — 앞 55% 동안 한 번 뛰었다 내려온다 (Reduce Motion 시 없음)
          final hop = (widget.reduceMotion || bp <= 0 || bp >= 0.55)
              ? 0.0
              : math.sin(bp / 0.55 * math.pi) * 13.0;

          // 타임라인 F: 기지개 + 미소 + 하이라이트 반짝
          final hAmt = math.sin(_happy.value * math.pi);

          // ── 톡 건드렸을 때 (개편 2026-08-12) ──────────────────
          final pokeT = _poke.value;
          // 간지럼: 확 놀랐다가 서서히 진정된다 (빠른 어택 · 긴 디케이)
          final tickle = (_pokeIsPeek || pokeT <= 0 || pokeT >= 1)
              ? 0.0
              : pokeT < 0.12
              ? Curves.easeOut.transform(pokeT / 0.12)
              : 1.0 - Curves.easeInOutCubic.transform((pokeT - 0.12) / 0.88);
          // 몸을 부르르 떤다 — 5.5주기, 진폭은 위 엔벨로프를 따른다
          final shakeDeg = tickle <= 0
              ? 0.0
              : math.sin(pokeT * math.pi * 2 * 5.5) * tickle * 6.5;

          // 실눈 두리번: 겨우 한쪽 눈을 뜨고 → 왼쪽 → 오른쪽 → 다시 감는다
          final peekT = (!_pokeIsPeek || pokeT <= 0 || pokeT >= 1)
              ? 0.0
              : pokeT;
          double peekOpen = 0, gazeX = 0;
          if (peekT > 0) {
            peekOpen = peekT < 0.18
                ? Curves.easeOut.transform(peekT / 0.18)
                : peekT < 0.86
                ? 1.0
                : 1.0 - Curves.easeIn.transform((peekT - 0.86) / 0.14);
            if (peekT >= 0.20 && peekT < 0.44) {
              gazeX = -Curves.easeInOut.transform((peekT - 0.20) / 0.24);
            } else if (peekT >= 0.44 && peekT < 0.70) {
              gazeX =
                  -1 + 2 * Curves.easeInOut.transform((peekT - 0.44) / 0.26);
            } else if (peekT >= 0.70 && peekT < 0.86) {
              gazeX = 1 - Curves.easeInOut.transform((peekT - 0.70) / 0.16);
            }
          }

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
              bodyImage: kLumiBodyStyle == LumiBodyStyle.image
                  ? _bodyImage
                  : null,
              // 생활 레이어 (개편 2026-08-08) — 잠들면 활동·밤 연출 없음
              activity: widget.mode == LumiMode.day && s < 0.5
                  ? widget.activity
                  : null,
              nightDoze: widget.mode == LumiMode.nightAwake && s < 0.5,
              dazzle: widget.dazzle.clamp(0.0, 1.0),
              lidCover: lid.clamp(0.0, 1.0),
              // 체크 축하도 간지럼과 같은 얼굴(∩∩ 눈·활짝 미소·볼터치)을
              // 쓴다 — 기쁨의 문법을 하나로 유지한다
              tickle: math.max(tickle, joy).clamp(0.0, 1.0),
              joy: joy.clamp(0.0, 1.0),
              joyT: bp.clamp(0.0, 1.0),
              hopPx: hop / 240 * widget.size,
              shakeDeg: shakeDeg,
              gazeX: gazeX,
              peekOpen: peekOpen,
              // 흰자는 항상 흰색 — 분홍 블렌드는 사용자 결정으로 제거
              scleraColor: const Color(0xFFFFFFFF),
              // 졸림에 따른 은은한 다크서클에 더해, 전날 불을 남긴 밤의
              // 흔적(darkCircles)은 하루 종일 지워지지 않는 바닥값으로 깔린다.
              // 홈에서는 캐릭터가 작게(118pt) 그려져 과장해야 읽힌다
              // (발주자 결정 2026-08-15) — 세기가 높으면 그리기 쪽에서도
              // 호를 더 굵고 넓게 키운다.
              darkCircleOpacity: math.max(
                0.35 * t * (1 - s * 0.5),
                widget.darkCircles ? 0.95 * (1 - s * 0.15) : 0.0,
              ),
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
                  0.05 * math.sin(math.max(tickle, joy).clamp(0.0, 1.0) * math.pi) +
                  0.07 * yawnAmt +
                  0.06 * hAmt +
                  (s > 0.99 && !widget.reduceMotion
                      ? math.sin(_phase * 2 * math.pi * 0.7) * 0.008
                      : 0.0),
              mouthOpen: yawnAmt,
              smile: math.max(hAmt, math.max(tickle, joy).clamp(0.0, 1.0)),
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

  /// 몸통 PNG (null이면 painted 몸통으로 그린다)
  final ui.Image? bodyImage;

  /// 낮 일과 (null = 없음). 소품·모션은 본체와 분리된 레이어로 그린다.
  final LumiDayActivity? activity;

  /// 밤에 못 자는 상태 — 꾸벅꾸벅 조는 사이클 + 눈부심 연출
  final bool nightDoze;

  /// 눈부심 (방에 남은 빛). 높으면 빛을 가리고, 낮으면 존다.
  final double dazzle;

  final double lidCover;

  /// 간지럼 (0~1). 몸을 떨고, 눈이 ^ ^로 접히고, 입이 활짝 벌어진다.
  final double tickle;

  /// 체크 축하 (개편 2026-08-15, 0~1) — 반짝이 버스트의 세기(알파).
  final double joy;

  /// 체크 축하의 진행도 (컨트롤러 원값 0~1) — 반짝이가 퍼져 나가는 축.
  final double joyT;

  /// 체크 축하의 폴짝 점프 높이 (캔버스 px, 위쪽 +)
  final double hopPx;

  /// 간지럼 떨림 각도(도)
  final double shakeDeg;

  /// 실눈 두리번의 시선 (-1 왼쪽 ~ +1 오른쪽)
  final double gazeX;

  /// 실눈 두리번에서 한쪽 눈이 열린 정도 (0~1)
  final double peekOpen;
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
    this.bodyImage,
    this.activity,
    this.nightDoze = false,
    this.dazzle = 0.0,
    required this.lidCover,
    this.tickle = 0.0,
    this.joy = 0.0,
    this.joyT = 0.0,
    this.hopPx = 0.0,
    this.shakeDeg = 0.0,
    this.gazeX = 0.0,
    this.peekOpen = 0.0,
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
    // hopPx: 체크 축하의 폴짝 — 부유 위에 잠깐 얹히는 점프 (2026-08-15)
    final cy = size.height / 2 + floatY + asleepProgress * 8 * u - hopPx;

    // ── 산책: 방 안을 이리저리 떠다닌다. 통통 튀는 걸음 보브 +
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
      // 콧노래: 리듬 타는 좌우 스웨이
      leanDeg = math.sin(phase * 2 * math.pi * 0.5) * 2.4;
    } else if (activity == LumiDayActivity.dance) {
      // 춤 (신설 2026-08-15): 콧노래보다 크게 리듬을 탄다 —
      // 좌우 스텝 + 빠른 통통 바운스 + 큰 기울기. 반짝이는 소품 레이어가 맡는다.
      final dp = phase * 2 * math.pi * 0.55;
      leanDeg = math.sin(dp * 2) * 8.5;
      canvas.translate(
        math.sin(dp) * 14 * u,
        -math.sin(dp * 4).abs() * 4.5 * u,
      );
    } else if (nightDoze) {
      // 졸려서 몸을 못 가눈다 (신설 2026-08-15) — 저주파 비틀비틀 스웨이.
      // 눈부신 밤(dazzle↑)엔 잠이 달아나 있어 덜 흔들린다.
      leanDeg = math.sin(phase * 2 * math.pi * 0.18) * 3.4 * (1 - dazzle * 0.6);
    }

    // Rive SVG 파츠(assets/rive/svg, viewBox 500)와 동일 지오메트리
    // (개정 2026-08-09). k = SVG 좌표 → 캔버스 배율, 1.25는 화면 크기감 보정.
    // k = SVG 좌표 → 캔버스 배율. 세로 기준점 252는 캐릭터 중심(261)보다
    // 위라서 캐릭터가 그만큼 아래로 내려가 **상단 여백**이 생긴다 —
    // 통통·하품으로 bodyScale이 커질 때 피벗(캐릭터 하단 0.72)에서 멀어지는
    // 머리가 캔버스 밖으로 나가 잘리던 문제를 막는다 (개정 2026-08-12).
    final k = size.width / 500 * 1.20;
    double px(double x) => cx + (x - 250) * k;
    double py(double y) => cy + (y - 252) * k;
    final top = py(102);
    final bottom = py(398);
    final bodyW = 220.0 * k; // 돔 폭 (SVG 140~360)
    final bodyH = bottom - top;

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
    // 간지럼 떨림은 몸통 그룹에 얹는다 — 얼굴·소품까지 함께 흔들린다
    if (leanDeg != 0 || shakeDeg != 0) {
      canvas.rotate((leanDeg + shakeDeg) * math.pi / 180);
    }
    canvas.scale(bodyScale);
    if (activity == LumiDayActivity.stretch) {
      // 아침 스트레칭: 위로 쭉 — 세로 늘어남
      final st = math.sin(phase * 2 * math.pi * 0.45).abs();
      canvas.scale(1.0 - 0.015 * st, 1.0 + 0.045 * st);
    }
    canvas.translate(-cx, -(cy + bodyH * 0.3));

    // ── 몸통 (개정 2026-08-09, Rive SVG 정합):
    //    팔까지 하나로 이어진 실루엣 — 레퍼런스처럼 아웃라인이 끊기지 않는다.
    //    (별도 손 셰이프 제거. 팔 모션은 Rive 이관 후 본으로 처리)
    // 재측정 3차 (2026-08-09, 레퍼런스 정합): 캡슐형 팔(두께 38, 수평),
    // 트럼펫처럼 벌어지는 스커트, 옆선이 코너 스캘럽으로 감아 도는 밑단.
    // assets/rive/svg/body.svg와 동일 좌표.
    if (bodyImage != null) {
      // ── 몸통 PNG (개편 2026-08-12, kLumiBodyStyle.image):
      //    실루엣·음영·아웃라인은 ghost_body.png가 담당하고, 얼굴·소품은
      //    아래 코드가 그대로 그린다. 세로(py 98~425)에 균등 스케일로
      //    맞추고 가로 중앙 정렬 — px/py 좌표계와 정합된다.
      const src = Rect.fromLTRB(
        kGhostBodySrcL,
        kGhostBodySrcT,
        kGhostBodySrcR,
        kGhostBodySrcB,
      );
      final destTop = py(98);
      final destH = py(425) - destTop;
      final scale = destH / src.height;
      final destW = src.width * scale;
      final dest = Rect.fromLTWH(cx - destW / 2, destTop, destW, destH);
      canvas.drawImageRect(
        bodyImage!,
        src,
        dest,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      final body = Path()..moveTo(px(100), py(382));
      // 왼쪽 스커트 — 머리부터 일정한 넓은 각으로 떨어지며 밑단에서 펼쳐진다
      body.cubicTo(px(112), py(350), px(126), py(308), px(136), py(266));
      // 왼팔 — 옆선에서 살짝 아래로 기울어 튀어나오는 캡슐
      body.cubicTo(px(126), py(268.5), px(114), py(270), px(103), py(269));
      body.cubicTo(px(93), py(268), px(83), py(262), px(82), py(252));
      body.cubicTo(px(81), py(241), px(89), py(232), px(99), py(231));
      body.cubicTo(px(112), py(228), px(126), py(225), px(138), py(223));
      body.cubicTo(px(139), py(221.5), px(140), py(220), px(140), py(218));
      // 돔 — 반원, 이마는 살짝 봉긋 (개정: apex 106→102)
      body.cubicTo(px(140), py(152), px(188), py(102), px(250), py(102));
      body.cubicTo(px(312), py(102), px(360), py(152), px(360), py(218));
      // 오른팔 (미러)
      body.cubicTo(px(360), py(220), px(361), py(221.5), px(362), py(223));
      body.cubicTo(px(374), py(225), px(388), py(228), px(401), py(231));
      body.cubicTo(px(411), py(232), px(419), py(241), px(418), py(252));
      body.cubicTo(px(417), py(262), px(407), py(268), px(397), py(269));
      body.cubicTo(px(386), py(270), px(374), py(268.5), px(364), py(266));
      body.cubicTo(px(374), py(308), px(388), py(350), px(400), py(382));
      // 오른쪽 코너 스캘럽 — 큰 반경으로 감아 돈다 (개정: 굵은 웨이브 4개)
      body.cubicTo(px(403), py(398), px(397), py(413), px(382), py(416));
      body.cubicTo(px(369), py(418), px(352), py(405), px(342), py(398));
      // 가운데 스캘럽 2개 — 이 구간만 살아 있는 물결 (애니메이션)
      final amp = 3.0 * k * hemAmp * math.sin(phase * 2 * math.pi * 1.5);
      const valleys = [342.0, 250.0, 158.0];
      const mids = [296.0, 204.0];
      for (var i = 0; i < 2; i++) {
        final sx = valleys[i];
        final ex = valleys[i + 1];
        final mx = mids[i];
        final dipY =
            py(421) +
            amp * (0.6 + 0.4 * math.sin(phase * 2 * math.pi * 1.5 + i * 0.9));
        body
          ..cubicTo(px(sx - 15), py(398), px(mx + 16), dipY, px(mx), dipY)
          ..cubicTo(px(mx - 16), dipY, px(ex + 15), py(398), px(ex), py(398));
      }
      // 왼쪽 코너 스캘럽
      body.cubicTo(px(148), py(405), px(131), py(418), px(118), py(416));
      body.cubicTo(px(103), py(413), px(97), py(398), px(100), py(382));
      body.close();
      final w2 = bodyW / 2; // 음영 배치용

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
    } // painted 몸통 끝

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
    // SVG 파츠의 눈 중심(y=202)과 동일 (개정 2026-08-09)
    final headCy = py(202);
    canvas.save();
    canvas.translate(headCx, headCy);
    // 두리번거릴 때 고개도 시선을 살짝 따라간다.
    // 꾸벅꾸벅 (과장 2026-08-15): 기울기 13°→19°·낙폭 5→8u로 키우고,
    // 떨어지는 동안 잔떨림을 얹어 "자기도 모르게 끄덕끄덕"이 크게 읽히게 한다.
    final nodTremor = doze > 0.05
        ? math.sin(phase * 2 * math.pi * 1.7) * 2.0 * doze
        : 0.0;
    canvas.rotate(
      (headTiltDeg + doze * 19.0 + nodTremor + gazeX * 3.0) * math.pi / 180,
    );
    canvas.translate(-headCx, -headCy + doze * 8 * u);

    // 졸리면 눈이 살짝 작아진다. SVG 파츠(eye_*, 10×16 @ ±36)와 동일 비율
    // (개정 2026-08-09: 강조 배율 제거 — 레퍼런스처럼 작은 눈 + 얼굴 여백).
    final eyeScale = 0.85 + 0.15 * pupilScale;
    // 눈부심 (개정 2026-08-08): 소품 없이 표정으로 — 눈을 가늘게 찡그린다
    final squint = nightDoze ? ((dazzle - 0.45) / 0.55).clamp(0.0, 1.0) : 0.0;
    final eyeDx = 36.0 * k;
    final eyeRx = 10.0 * k * eyeScale;
    // 눈부심 압착 (과장 2026-08-15): 0.68 → 0.82 — 거의 실선까지 짓눌린다
    final eyeRy = 16.0 * k * eyeScale * (1 - 0.82 * squint);

    // 독서·낙서: 시선이 책/종이로 — 눈이 살짝 아래로 내려온다
    final eyeYOff =
        (activity == LumiDayActivity.read ||
            activity == LumiDayActivity.doodle)
        ? 3.0 * u
        : 0.0;

    // 두리번 — 눈(솔리드 타원)이 얼굴 안에서 좌우로 옮겨 다닌다.
    // 홍채가 없는 디자인이라 이게 곧 시선이다.
    final gazeShift = gazeX * 5.5 * u;

    for (final dir in [-1, 1]) {
      final ec = Offset(headCx + dir * eyeDx + gazeShift, headCy + eyeYOff);

      // 다크서클 — 눈 아래 반달. 눈 모양 분기(간지럼·취침)보다 먼저
      // 그린다 — 전날 못 잔 흔적은 감은 눈 밑에도, 웃는 눈 밑에도 남아
      // 있어야 한다 (세계관 2026-08-15).
      // 세기(opacity)가 높을수록 넓고 굵고 짙어진다 — 홈의 작은 캐릭터
      // (118pt)에서도 읽히도록 과장 (발주자 결정 2026-08-15). 진한 쪽은
      // 채운 초승달 음영 + 가장자리 선으로, 옅은 쪽은 선 하나로 그린다.
      if (darkCircleOpacity > 0.01) {
        final dcW = eyeRx * (0.7 + 0.55 * darkCircleOpacity);
        final topY = ec.dy + eyeRy * 1.02;
        final dipY = ec.dy + eyeRy * (1.35 + 0.45 * darkCircleOpacity);
        final edge = Path()
          ..moveTo(ec.dx - dcW, topY)
          ..quadraticBezierTo(ec.dx, dipY, ec.dx + dcW, topY);
        // 채움: 눈 밑을 살짝 꺼진 초승달로 음영 처리 (진할 때만 보인다)
        if (darkCircleOpacity > 0.45) {
          final crescent = Path()
            ..moveTo(ec.dx - dcW, topY)
            ..quadraticBezierTo(ec.dx, dipY, ec.dx + dcW, topY)
            ..quadraticBezierTo(ec.dx, dipY - eyeRy * 0.42, ec.dx - dcW, topY)
            ..close();
          canvas.drawPath(
            crescent,
            Paint()
              ..color = const Color(
                0xFFA98BB0,
              ).withValues(alpha: (darkCircleOpacity - 0.45) * 0.62),
          );
        }
        canvas.drawPath(
          edge,
          Paint()
            ..color = const Color(
              0xFF8A6494,
            ).withValues(alpha: (darkCircleOpacity * 0.85).clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = (2.2 + 1.6 * darkCircleOpacity) * u
            ..strokeCap = StrokeCap.round,
        );
      }

      // 간지럼 — 웃느라 눈이 ∩ 모양으로 접힌다.
      // 문턱을 낮게 잡아 반응 대부분의 구간에서 웃는 눈이 보이게 한다.
      if (tickle > 0.12) {
        final f = ((tickle - 0.12) / 0.88).clamp(0.0, 1.0);
        final arc = Path()
          ..moveTo(ec.dx - eyeRx * 1.15, ec.dy + eyeRy * 0.30)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy - eyeRy * (0.35 + 0.55 * f),
            ec.dx + eyeRx * 1.15,
            ec.dy + eyeRy * 0.30,
          );
        canvas.drawPath(
          arc,
          Paint()
            ..color = _pupilColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.4 * u
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

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

      // 눈 — Rive SVG 파츠와 동일: 솔리드 잉크 세로 타원 (레퍼런스).
      final eyeRect = Rect.fromCenter(
        center: ec,
        width: eyeRx * 2,
        height: eyeRy * 2,
      );
      canvas.drawOval(eyeRect, Paint()..color = _pupilColor);

      // happy 반짝 — 기상 순간에만 작은 하이라이트
      if (smile > 0.05) {
        canvas.drawCircle(
          ec.translate(-eyeRx * 0.3, -eyeRy * 0.35),
          2.6 * u,
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: (smile * 0.9).clamp(0.0, 1.0)),
        );
      }

      // 눈꺼풀 — SVG eyelid 규칙: 몸색 덮개가 위에서 내려오고,
      // 아래 가장자리 ∪ 잉크 곡선은 충분히 감겼을 때만 보인다.
      final lidWithDoze = (lidCover + doze * 0.30).clamp(0.0, 1.0);
      final effLid = lidWithDoze < 0.10 ? 0.0 : (lidWithDoze - 0.10) / 0.90;
      // 실눈 두리번 — 오른쪽 눈만 겨우 뜬다. 왼쪽은 거의 그대로 감긴 채.
      final open = peekOpen * (dir > 0 ? 0.82 : 0.18);
      final upperCover = ((effLid + squint * 0.45) * (1 - open)).clamp(
        0.0,
        1.0,
      );
      if (upperCover > 0.01) {
        final edgeY = ec.dy - eyeRy + eyeRy * 2 * upperCover;
        final sag = eyeRx * 0.30; // SVG ∪ 곡률 (Q +6 / 40폭)
        canvas.save();
        canvas.clipPath(Path()..addOval(eyeRect.inflate(1.5 * u)));
        final lid = Path()
          ..moveTo(ec.dx - eyeRx - 2 * u, ec.dy - eyeRy - 2 * u)
          ..lineTo(ec.dx + eyeRx + 2 * u, ec.dy - eyeRy - 2 * u)
          ..lineTo(ec.dx + eyeRx + 2 * u, edgeY - sag * 0.3)
          ..quadraticBezierTo(
            ec.dx,
            edgeY + sag,
            ec.dx - eyeRx - 2 * u,
            edgeY - sag * 0.3,
          )
          ..close();
        canvas.drawPath(lid, Paint()..color = const Color(0xFFFEFDFF));
        canvas.restore();
        if (upperCover > 0.12) {
          final edge = Path()
            ..moveTo(ec.dx - eyeRx, edgeY - sag * 0.3)
            ..quadraticBezierTo(
              ec.dx,
              edgeY + sag,
              ec.dx + eyeRx,
              edgeY - sag * 0.3,
            );
          canvas.drawPath(
            edge,
            Paint()
              ..color = _inkColor.withValues(alpha: 0.55 + squint * 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = (2.0 + squint * 0.8) * u
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      // 강한 눈부심: 눈을 꽉 압착하고, 안쪽이 올라간 눈썹과 바깥 눈꼬리
      // 주름으로 화난 표정이 아닌 "빛 때문에 괴로운" 표정을 만든다.
      // (과장 2026-08-15: 압력선을 더 깊고 굵게, 아래 눈꺼풀도 밀어 올려
      //  ><로 짓눌린 인상 + 주름 3개 + 눈꼬리에 눈물이 찔끔 맺힌다 —
      //  홈의 작은 캐릭터에서도 "괴롭다"가 한눈에 읽혀야 한다.)
      if (squint > 0.35) {
        final pain = ((squint - 0.35) / 0.65).clamp(0.0, 1.0);

        // 꽉 감긴 윗눈꺼풀의 압력선 — 깊고 굵게.
        final pressureLid = Path()
          ..moveTo(ec.dx - eyeRx * 1.05, ec.dy + eyeRy * 0.10)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy - eyeRy * (0.80 + pain * 0.34),
            ec.dx + eyeRx * 1.05,
            ec.dy + eyeRy * 0.10,
          );
        canvas.drawPath(
          pressureLid,
          Paint()
            ..color = _inkColor.withValues(alpha: 0.30 + pain * 0.62)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (2.4 + pain * 1.8) * u
            ..strokeCap = StrokeCap.round,
        );

        // 아래 눈꺼풀도 밀어 올라온다 — 꽉 감은 ><의 아래 절반.
        final lowerLid = Path()
          ..moveTo(ec.dx - eyeRx * 0.82, ec.dy + eyeRy * 0.34)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy + eyeRy * (0.66 + pain * 0.14),
            ec.dx + eyeRx * 0.82,
            ec.dy + eyeRy * 0.34,
          );
        canvas.drawPath(
          lowerLid,
          Paint()
            ..color = _inkColor.withValues(alpha: (0.18 + pain * 0.42))
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1.6 + pain * 1.0) * u
            ..strokeCap = StrokeCap.round,
        );

        // 안쪽이 들린 눈썹 — 고통·당황 신호, 중앙을 내리는 화난 눈썹과 반대.
        final outerBrow = Offset(
          ec.dx + dir * eyeRx * 0.92,
          ec.dy - eyeRy * (1.20 + pain * 0.10),
        );
        final innerBrow = Offset(
          ec.dx - dir * eyeRx * 0.72,
          ec.dy - eyeRy * (1.52 + pain * 0.26),
        );
        final brow = Path()
          ..moveTo(outerBrow.dx, outerBrow.dy)
          ..quadraticBezierTo(
            ec.dx,
            ec.dy - eyeRy * (1.36 + pain * 0.18),
            innerBrow.dx,
            innerBrow.dy,
          );
        canvas.drawPath(
          brow,
          Paint()
            ..color = _inkColor.withValues(alpha: 0.24 + pain * 0.60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1.7 + pain * 1.1) * u
            ..strokeCap = StrokeCap.round,
        );

        // 바깥 눈꼬리의 짧은 수축 주름 세 개 — 부챗살로 퍼진다.
        final corner = Offset(ec.dx + dir * eyeRx * 0.96, ec.dy + eyeRy * 0.02);
        for (final yDir in [-1.0, 0.0, 1.0]) {
          canvas.drawLine(
            corner,
            corner.translate(
              dir * (4.5 + pain * 3.5) * u,
              yDir * (2.6 + pain * 2.0) * u,
            ),
            Paint()
              ..color = _inkColor.withValues(alpha: 0.18 + pain * 0.44)
              ..strokeWidth = 1.5 * u
              ..strokeCap = StrokeCap.round,
          );
        }

        // 짓눌린 눈꼬리에 찔끔 맺힌 눈물 — 괴로움의 마침표.
        if (pain > 0.4) {
          _paintDrop(
            canvas,
            Offset(ec.dx + dir * eyeRx * 1.22, ec.dy + eyeRy * 0.62),
            (1.8 + 1.4 * pain) * u,
            (pain - 0.4) / 0.6 * 0.85,
          );
        }
      }

      // 하품 눈물 (신설 2026-08-15) — 입이 크게 벌어진 정점에서
      // 눈꼬리에 눈물이 그렁 맺힌다. 진짜 하품의 화룡점정.
      if (mouthOpen > 0.55) {
        final tw = ((mouthOpen - 0.55) / 0.45).clamp(0.0, 1.0);
        _paintDrop(
          canvas,
          Offset(ec.dx + dir * eyeRx * 1.18, ec.dy + eyeRy * 0.45),
          (2.0 + 1.8 * tw) * u,
          tw * 0.9,
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
    // SVG 파츠의 입 중심(y=232)과 동일 (개정 2026-08-09)
    final mouthC = Offset(headCx, py(232));
    final restSmile = activity == LumiDayActivity.rest && asleepProgress <= 0.6;
    if (mouthOpen > 0.08) {
      // 하품 (개정 2026-08-09 · 2차 과장 2026-08-15) — 평소 입은 작지만
      // 하품만은 얼굴의 절반을 차지할 만큼 커야 "진짜 하품"이 읽힌다.
      // 크게 벌어진 O + 아래쪽 작은 혀. (기존 16×23 → 20×31)
      final yw = 20.0 * k * (0.50 + 0.50 * mouthOpen);
      final yh = 31.0 * k * (0.25 + 0.75 * mouthOpen);
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
    } else if (activity == LumiDayActivity.bubbles) {
      // 비눗방울 (신설 2026-08-15) — 후- 하고 오므린 작은 O 입.
      // 방울이 떠오르는 쪽(오른쪽)으로 살짝 치우친다. 숨결에 맞춰 오므림이
      // 미세하게 커졌다 작아진다.
      final r = (4.6 + 0.7 * math.sin(phase * 2 * math.pi * 0.44)) * u;
      final oc = mouthC.translate(5 * u, 0);
      canvas.drawCircle(oc, r, Paint()..color = _cavityColor);
      canvas.drawCircle(
        oc,
        r,
        Paint()
          ..color = _inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * u,
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
      // 간식: 오물오물 — 입이 리듬에 맞춰 조였다 벌어진다
      final chew = activity == LumiDayActivity.snack
          ? 0.72 + 0.22 * math.sin(phase * 2 * math.pi * 1.15).abs()
          : 1.0;
      // SVG mouth_happy(30×20)와 동일 비율 (개정 2026-08-09: 축소)
      final aw = 15.0 * k * shrink * (1 + 0.20 * smile + 0.30 * mouthOpen);
      final ah =
          13.0 * k * shrink * chew * (1 + 0.45 * smile + 1.5 * mouthOpen);
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

    // ── 콧물 방울 (신설 2026-08-15, 😪) — 꾸벅꾸벅 조는 동안 코끝에서
    //    숨을 따라 부풀다가, 화들짝 깨는 순간(doze 급락) 훅 들이마셔진다.
    //    눈부신 밤(dazzle↑)엔 잠이 얕아 doze 자체가 작으므로 거의 안 생긴다.
    //    머리 그룹 안에서 그려 끄덕임을 따라 함께 기운다.
    if (nightDoze && doze > 0.12) {
      final bubbleT = ((doze - 0.12) / 0.88).clamp(0.0, 1.0);
      final noseTip = Offset(headCx + 7 * u, py(222));
      final r =
          (2.2 + 6.0 * bubbleT) *
          u *
          (1 + 0.06 * math.sin(phase * 2 * math.pi * 2.2)); // 숨결 떨림
      final bc = noseTip.translate(2.5 * u * bubbleT, r * 0.75);
      canvas.drawCircle(
        bc,
        r,
        Paint()
          ..color = const Color(0xFFB5E0F5).withValues(alpha: 0.80 * bubbleT),
      );
      canvas.drawCircle(
        bc,
        r,
        Paint()
          ..color = _inkColor.withValues(alpha: 0.55 * bubbleT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * u,
      );
      canvas.drawCircle(
        bc.translate(-r * 0.32, -r * 0.32),
        r * 0.24,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * bubbleT),
      );
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
      case LumiDayActivity.doodle:
        _paintDoodle(canvas, u, cx, cy, bodyH);
      case LumiDayActivity.dance:
        _paintSparkles(canvas, u, cx, cy, bodyW, bodyH);
      default:
        break;
    }

    // ── 체크 축하 반짝이 (개편 2026-08-15) — 등 하나를 끌 때마다
    //    정수리 위로 별이 팡 터진다. 확산은 joyT, 밝기는 joy가 몬다.
    if (joy > 0.02) {
      _paintJoyBurst(canvas, u, cx, top, bodyW);
    }

    // ── 식은땀 (신설 2026-08-15) — 강한 눈부심에 괴로울 때 관자놀이에
    //    땀방울이 맺혀 또르르 흘러내린다.
    if (squint > 0.5) {
      final sp = (phase * 0.45) % 1.0;
      final a = ((squint - 0.5) * 2).clamp(0.0, 1.0) * math.sin(sp * math.pi);
      _paintDrop(
        canvas,
        Offset(px(352), py(150) + sp * 30 * u),
        (3.6 + 2.0 * squint) * u,
        a * 0.9,
      );
    }

    canvas.restore(); // 몸통 스케일

    // ── 콧노래 음표 — zzz와 같은 문법의 상승 루프 ──
    // 글리프는 폰트가 아니라 패스로 직접 그린다 (개정 2026-08-15):
    // 플랫폼 폰트 차이·위젯 스프라이트 추출 환경에 흔들리지 않고,
    // 라운드 스트로크가 카와이 톤과도 맞는다.
    if (activity == LumiDayActivity.hum) {
      for (var i = 0; i < 2; i++) {
        final p = (phase * 0.30 + i * 0.5) % 1.0;
        final alpha = math.sin(p * math.pi) * 0.6;
        if (alpha <= 0.02) continue;
        _paintNote(
          canvas,
          Offset(
            cx + bodyW * 0.42 + i * 11 * u + math.sin(p * 2 * math.pi) * 4 * u,
            top + 4 * u - p * 30 * u,
          ),
          (13.0 + i * 4) * u,
          const Color(0xFFA99BC9).withValues(alpha: alpha),
          eighthPair: i.isOdd,
        );
      }
    }

    // ── 비눗방울 (신설 2026-08-15) — 오므린 입에서 방울이 떠올라
    //    흔들리며 올라가다 하나씩 사라진다. 유령다운 몽환적 놀이.
    if (activity == LumiDayActivity.bubbles) {
      for (var i = 0; i < 3; i++) {
        final p = (phase * 0.22 + i / 3) % 1.0;
        final alpha = (math.sin(p * math.pi) * 0.95).clamp(0.0, 1.0);
        if (alpha <= 0.02) continue;
        final r = (3.4 + i * 1.5 + p * 3.2) * u;
        // 입에서 나와 곧장 오른쪽 대각선 바깥으로 — 초반에 빠르게 벗어나
        // (sqrt 궤적) 얼굴·눈 위를 지나가지 않는다.
        final bc = Offset(
          cx +
              (8 + 44 * math.sqrt(p)) * u +
              math.sin(p * 2 * math.pi * 2 + i * 2.1) * 4 * u,
          py(228) - p * 62 * u,
        );
        canvas.drawCircle(
          bc,
          r,
          Paint()
            ..color = const Color(0xFFBFE3F7).withValues(alpha: 0.25 * alpha),
        );
        canvas.drawCircle(
          bc,
          r,
          Paint()
            ..color = const Color(0xFF9FD4EF).withValues(alpha: 0.85 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * u,
        );
        canvas.drawArc(
          Rect.fromCircle(center: bc, radius: r * 0.60),
          -2.6,
          1.1,
          false,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * u
            ..strokeCap = StrokeCap.round,
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
        _paintZ(
          canvas,
          Offset(
            baseX + i * 12 * u + p * 6 * u,
            baseY - p * 34 * u - i * 10 * u,
          ),
          (11.0 + i * 5) * u,
          const Color(0xFF8E86A8).withValues(alpha: alpha),
        );
      }
    }

    canvas.restore(); // 전체 이동 레이어
  }

  /// 소문자 'z' — 세 획(윗줄·대각선·아랫줄)을 라운드 스트로크로.
  /// [size]는 폰트 크기에 해당하고 [o]는 글리프 박스의 좌상단.
  void _paintZ(Canvas canvas, Offset o, double size, Color color) {
    final w = size * 0.60;
    final h = size * 0.62;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + w, o.dy)
      ..lineTo(o.dx, o.dy + h)
      ..lineTo(o.dx + w, o.dy + h);
    canvas.drawPath(path, paint);
  }

  /// 8분음표 — [eighthPair]면 빔으로 이은 두 개(♫), 아니면 꼬리 하나(♪).
  void _paintNote(
    Canvas canvas,
    Offset o,
    double size,
    Color color, {
    bool eighthPair = false,
  }) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.09
      ..strokeCap = StrokeCap.round;

    void head(double cxh, double cyh) {
      canvas.save();
      canvas.translate(cxh, cyh);
      canvas.rotate(-0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size * 0.40,
          height: size * 0.30,
        ),
        fill,
      );
      canvas.restore();
    }

    if (eighthPair) {
      final y = o.dy + size * 0.78;
      final x1 = o.dx + size * 0.20, x2 = o.dx + size * 0.62;
      final topY = o.dy + size * 0.16;
      head(x1, y);
      head(x2, y);
      canvas.drawLine(
        Offset(x1 + size * 0.17, y - size * 0.05),
        Offset(x1 + size * 0.17, topY + size * 0.05),
        stroke,
      );
      canvas.drawLine(
        Offset(x2 + size * 0.17, y - size * 0.05),
        Offset(x2 + size * 0.17, topY),
        stroke,
      );
      // 빔 — 살짝 기운 두툼한 연결선
      canvas.drawLine(
        Offset(x1 + size * 0.17, topY + size * 0.05),
        Offset(x2 + size * 0.17, topY),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.16
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final x = o.dx + size * 0.26, y = o.dy + size * 0.80;
      final stemX = x + size * 0.17;
      final topY = o.dy + size * 0.14;
      head(x, y);
      canvas.drawLine(
        Offset(stemX, y - size * 0.05),
        Offset(stemX, topY),
        stroke,
      );
      // 꼬리 — 스템 꼭대기에서 오른쪽 아래로 흐르는 곡선
      final flag = Path()
        ..moveTo(stemX, topY)
        ..quadraticBezierTo(
          stemX + size * 0.30,
          topY + size * 0.12,
          stemX + size * 0.24,
          topY + size * 0.40,
        );
      canvas.drawPath(flag, stroke);
    }
  }

  /// 물방울 — 위가 뾰족한 카와이 눈물/땀 방울 (신설 2026-08-15).
  /// 하품 눈물·눈부심 눈물·식은땀이 같은 문법을 쓴다.
  void _paintDrop(Canvas canvas, Offset c, double r, double alpha) {
    if (alpha <= 0.02) return;
    final a = alpha.clamp(0.0, 1.0);
    final drop = Path()
      ..moveTo(c.dx, c.dy - r * 1.45)
      ..quadraticBezierTo(
        c.dx + r * 0.95,
        c.dy - r * 0.35,
        c.dx + r * 0.92,
        c.dy + r * 0.18,
      )
      ..cubicTo(
        c.dx + r * 0.88,
        c.dy + r * 0.95,
        c.dx - r * 0.88,
        c.dy + r * 0.95,
        c.dx - r * 0.92,
        c.dy + r * 0.18,
      )
      ..quadraticBezierTo(c.dx - r * 0.95, c.dy - r * 0.35, c.dx, c.dy - r * 1.45)
      ..close();
    canvas.drawPath(
      drop,
      Paint()..color = const Color(0xFF9FD4EF).withValues(alpha: 0.85 * a),
    );
    canvas.drawPath(
      drop,
      Paint()
        ..color = _inkColor.withValues(alpha: 0.40 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.20
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      c.translate(-r * 0.28, 0),
      r * 0.22,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * a),
    );
  }

  /// 4갈래 다이아몬드 별 — 허리가 잘록해 반짝임으로 읽힌다 (춤·체크 축하 공용)
  static Path _diamondStar(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r * 1.9)
    ..quadraticBezierTo(c.dx + r * 0.25, c.dy - r * 0.25, c.dx + r * 1.9, c.dy)
    ..quadraticBezierTo(c.dx + r * 0.25, c.dy + r * 0.25, c.dx, c.dy + r * 1.9)
    ..quadraticBezierTo(c.dx - r * 0.25, c.dy + r * 0.25, c.dx - r * 1.9, c.dy)
    ..quadraticBezierTo(c.dx - r * 0.25, c.dy - r * 0.25, c.dx, c.dy - r * 1.9)
    ..close();

  /// 체크 축하 (개편 2026-08-15): 등 하나를 끌 때마다 정수리 주변 부채꼴로
  /// 별 무리가 팡 터지며 바깥으로 퍼진다 — 짜릿한 심리적 보상.
  void _paintJoyBurst(
    Canvas canvas,
    double u,
    double cx,
    double top,
    double bodyW,
  ) {
    final head = Offset(cx, top + 6 * u);
    // 위쪽 부채꼴 5방향 (라디안) — 좌우 대칭, 정수리가 가장 멀리 뻗는다
    const angles = [-2.62, -2.10, -1.57, -1.04, -0.52];
    final spread =
        bodyW * (0.40 + 0.45 * Curves.easeOut.transform(joyT.clamp(0.0, 1.0)));
    for (var i = 0; i < angles.length; i++) {
      final reach = i.isEven ? 1.0 : 0.78; // 별들이 두 겹으로 흩어진다
      final c =
          head +
          Offset(math.cos(angles[i]), math.sin(angles[i])) * spread * reach;
      final r = (i.isEven ? 3.6 : 2.5) * u * (0.6 + 0.5 * joy);
      final color = i.isOdd
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFFFC85C);
      canvas.drawPath(
        _diamondStar(c, r),
        Paint()..color = color.withValues(alpha: (0.95 * joy).clamp(0.0, 1.0)),
      );
    }
  }

  /// 춤 (신설 2026-08-15): 스텝 주변에 앰버 반짝이 별들이 위상차로 깜빡인다.
  /// 몸의 스텝·바운스는 본체 이동 레이어가 맡고, 여기는 반짝이만 그린다.
  void _paintSparkles(
    Canvas canvas,
    double u,
    double cx,
    double cy,
    double bodyW,
    double bodyH,
  ) {
    const spots = [
      Offset(-0.68, -0.52),
      Offset(0.70, -0.28),
      Offset(-0.55, 0.40),
      Offset(0.60, 0.52),
    ];
    for (var i = 0; i < spots.length; i++) {
      final p = (phase * 0.8 + i * 0.27) % 1.0;
      final a = math.sin(p * math.pi);
      if (a <= 0.05) continue;
      final c = Offset(
        cx + spots[i].dx * bodyW * 0.78,
        cy + spots[i].dy * bodyH * 0.55,
      );
      final r = (2.6 + (i % 2) * 1.3) * u * (0.6 + 0.6 * a);
      // 4갈래 다이아몬드 별 — 허리가 잘록해 반짝임으로 읽힌다
      final star = Path()
        ..moveTo(c.dx, c.dy - r * 1.9)
        ..quadraticBezierTo(c.dx + r * 0.25, c.dy - r * 0.25, c.dx + r * 1.9, c.dy)
        ..quadraticBezierTo(c.dx + r * 0.25, c.dy + r * 0.25, c.dx, c.dy + r * 1.9)
        ..quadraticBezierTo(c.dx - r * 0.25, c.dy + r * 0.25, c.dx - r * 1.9, c.dy)
        ..quadraticBezierTo(c.dx - r * 0.25, c.dy - r * 0.25, c.dx, c.dy - r * 1.9)
        ..close();
      canvas.drawPath(
        star,
        Paint()..color = const Color(0xFFFFC85C).withValues(alpha: 0.92 * a),
      );
    }
  }

  /// 낙서 (신설 2026-08-15): 몸 앞에 떠 있는 종이 위로 크레용이 고리
  /// 낙서를 그려 나간다 — 다 그리면 새 종이로 넘어간다.
  void _paintDoodle(
    Canvas canvas,
    double u,
    double cx,
    double cy,
    double bodyH,
  ) {
    final y = cy + bodyH * 0.15 + math.sin(phase * 2 * math.pi + 0.9) * 1.5 * u;
    final center = Offset(cx + 2 * u, y);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.06);
    canvas.translate(-center.dx, -center.dy);
    final paper = Rect.fromCenter(
      center: center,
      width: 64 * u,
      height: 42 * u,
    );
    final rr = RRect.fromRectAndRadius(paper, Radius.circular(3 * u));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFBF5E6));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = _inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * u
        ..strokeJoin = StrokeJoin.round,
    );
    // 낙서 곡선 — 고리 세 개. phase에 따라 앞에서부터 그려진다 (trim).
    final squiggle = Path()..moveTo(paper.left + 9 * u, center.dy + 7 * u);
    for (var i = 0; i < 3; i++) {
      final x0 = paper.left + (9 + i * 15.5) * u;
      squiggle.cubicTo(
        x0 + 12 * u,
        center.dy - 13 * u,
        x0 + 19 * u,
        center.dy + 9 * u,
        x0 + 15.5 * u,
        center.dy + 7 * u,
      );
    }
    final metric = squiggle.computeMetrics().first;
    // 최소 25%는 항상 그려져 있게 — 새 종이로 넘어가는 순간에도, 정지
    // 프레임(위젯 스프라이트·Reduce Motion)에서도 빈 종이로 보이지 않는다.
    final prog = 0.25 + 0.75 * ((phase * 0.12) % 1.0);
    canvas.drawPath(
      metric.extractPath(0, metric.length * prog),
      Paint()
        ..color = const Color(0xFFE8913D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * u
        ..strokeCap = StrokeCap.round,
    );
    // 크레용 — 낙서 끝점을 따라다닌다 (몸 앞에 둥둥 뜬 소품 문법 그대로).
    final tip = metric.getTangentForOffset(metric.length * prog)?.position;
    if (tip != null) {
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(-0.55);
      final crayon = RRect.fromRectAndRadius(
        Rect.fromLTWH(-2.6 * u, -16 * u, 5.2 * u, 16 * u),
        Radius.circular(2.4 * u),
      );
      canvas.drawRRect(crayon, Paint()..color = const Color(0xFFE8913D));
      canvas.drawRRect(
        crayon,
        Paint()
          ..color = _inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * u,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  // ── 낮 일과 소품들 (개편 2026-08-08, 개정 2026-08-15: 손 제거) ──
  // 소품은 유령 몸 앞에 그냥 둥둥 떠 있다 — 몸통 위에 겹쳐 그리던 "쥔 손"은
  // 발주자 결정으로 제거했다 (몸 안에 손이 있는 것처럼 보였다).

  /// 독서: 펼친 책 — 몸 앞에 둥둥 떠 있다.
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
  }

  /// 커피: 김이 오르는 잔 — 몸 앞에 떠서 주기적으로 홀짝
  /// 들어올려진다.
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
  }

  /// 간식: 초코칩 쿠키 — 몸 앞에 둥둥. 한 입씩 사라졌다가
  /// 새 쿠키로.
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
      old.tickle != tickle ||
      old.joy != joy ||
      old.joyT != joyT ||
      old.hopPx != hopPx ||
      old.shakeDeg != shakeDeg ||
      old.gazeX != gazeX ||
      old.peekOpen != peekOpen ||
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
      old.zzzOpacity != zzzOpacity ||
      old.bodyImage != bodyImage;
}
