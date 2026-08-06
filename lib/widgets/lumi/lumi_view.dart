import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/motion.dart';
import '../../domain/models/lumi_state.dart';
import 'lumi_parts.dart';

/// §7 Lumi 뷰 (v1 더미). [LumiState]만 받아 렌더링한다 — 이 인터페이스를
/// 유지한 채 나중에 실제 에셋/Rive로 교체한다.
///
/// §7.3 행동 규칙 / §1.3 금지: 원망·실망 표현 없음. 졸림·기다림·안도만.
class LumiView extends StatefulWidget {
  final LumiState state;

  /// Reduce Motion (§9.5) — 부유·물결·호흡 정지
  final bool reduceMotion;

  const LumiView({super.key, required this.state, this.reduceMotion = false});

  @override
  State<LumiView> createState() => _LumiViewState();
}

class _LumiViewState extends State<LumiView> with TickerProviderStateMixin {
  late final AnimationController _idle; // 부유 + hem 위상 공용 틱
  late final AnimationController _blink; // 깜빡임 (내려갔다 올라옴)
  late final AnimationController _yawn;
  late final AnimationController _react; // 체크 반응: 0.03 커졌다 복귀
  late final AnimationController _doze; // 꾸벅 졸다 화들짝
  late final AnimationController _sleep; // fallAsleep 1400ms

  Timer? _behaviorTimer;
  final _rng = math.Random();
  int _seenEventTick = 0;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _yawn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _react = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.lumiReactMs));
    _doze = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _sleep = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.lumiFallAsleepMs));
    _scheduleBehavior();
  }

  @override
  void didUpdateWidget(LumiView old) {
    super.didUpdateWidget(old);
    if (!old.state.isAsleep && widget.state.isAsleep) {
      _behaviorTimer?.cancel();
      _sleep.forward(from: 0);
    }
    if (widget.state.eventTick != _seenEventTick) {
      _seenEventTick = widget.state.eventTick;
      if (widget.state.event == LumiEvent.react && !widget.state.isAsleep) {
        _react.forward(from: 0);
      }
    }
    if (widget.reduceMotion && _idle.isAnimating) {
      _idle.stop();
    } else if (!widget.reduceMotion && !_idle.isAnimating &&
        !widget.state.isAsleep) {
      _idle.repeat();
    }
  }

  /// §7.3 조도 구간별 자율 행동 스케줄러
  void _scheduleBehavior() {
    _behaviorTimer?.cancel();
    if (widget.state.isAsleep) return;
    final b = widget.state.brightness;
    late final Duration next;
    late final void Function() action;

    if (b < 0.3) {
      // 눈 뜨고 있음, 가끔 깜빡임 4~8초
      next = Duration(
          milliseconds: (UnwindMotion.lumiBlinkMinS * 1000 +
                  _rng.nextInt((UnwindMotion.lumiBlinkMaxS -
                          UnwindMotion.lumiBlinkMinS) *
                      1000))
              .toInt());
      action = _doBlink;
    } else if (b < 0.6) {
      // 하품 시작 12~20초 (사이사이 깜빡임)
      final yawnNow = _rng.nextBool();
      if (yawnNow) {
        next = Duration(
            milliseconds: UnwindMotion.lumiYawnMinS * 1000 +
                _rng.nextInt((UnwindMotion.lumiYawnMaxS -
                        UnwindMotion.lumiYawnMinS) *
                    1000));
        action = _doYawn;
      } else {
        next = Duration(milliseconds: 4000 + _rng.nextInt(4000));
        action = _doBlink;
      }
    } else if (b < 0.9) {
      // 꾸벅 졸다가 화들짝 깨는 동작
      next = Duration(milliseconds: 6000 + _rng.nextInt(6000));
      action = _doDoze;
    } else {
      // 거의 감김 — 움직임 최소
      next = Duration(milliseconds: 10000 + _rng.nextInt(8000));
      action = _doBlink;
    }

    _behaviorTimer = Timer(next, () {
      if (!mounted || widget.state.isAsleep) return;
      action();
      _scheduleBehavior();
    });
  }

  Future<void> _doBlink() async {
    await _blink.forward(from: 0);
    if (mounted) await _blink.reverse();
  }

  Future<void> _doYawn() async {
    await _yawn.forward(from: 0);
    if (mounted) _yawn.value = 0;
  }

  Future<void> _doDoze() async {
    await _doze.forward(from: 0);
    if (mounted) _doze.value = 0;
  }

  @override
  void dispose() {
    _behaviorTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    _yawn.dispose();
    _react.dispose();
    _doze.dispose();
    _sleep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final b = widget.state.brightness;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_idle, _blink, _yawn, _react, _doze, _sleep]),
        builder: (context, _) {
          final asleepP = _sleep.value; // 0 → 1 잠드는 진행
          final isAsleep = widget.state.isAsleep;

          // 부유 (Reduce Motion / 취침 시 정지)
          final floatY = widget.reduceMotion || isAsleep
              ? 0.0
              : math.sin(_idle.value * 2 * math.pi) * 3.0 * (1 - b * 0.6);

          // 꾸벅 졸기: 천천히 내려갔다(0~0.75) 화들짝 복귀(0.75~1)
          final dozeT = _doze.value;
          final dozeDip = dozeT < 0.75
              ? Curves.easeInOut.transform(dozeT / 0.75) * 7.0
              : (1 - Curves.easeOutBack.transform((dozeT - 0.75) / 0.25)) * 7.0;

          // §7.1 lid: 조도에 비례해 감김. 취침 시퀀스가 나머지를 마저 감는다.
          final lidClose =
              (b * 0.85 + asleepP * (1 - b * 0.85)).clamp(0.0, 1.0);
          final blinkClose = _blink.value; // 깜빡임 순간 감김
          final eyeOpen = isAsleep && asleepP == 1
              ? 0.0
              : (1 - lidClose) * (1 - blinkClose);

          // 하품: 올라갔다 내려오는 산 모양
          final yawnP = math.sin(_yawn.value * math.pi);

          // 체크 반응: 0.03 커졌다 돌아옴 (§7.3)
          final reactScale = 1.0 +
              math.sin(_react.value * math.pi) * UnwindMotion.lumiReactScale;

          // 취침 시 아주 느린 호흡만 (§7.3)
          final sleepBreath = isAsleep && !widget.reduceMotion
              ? 1.0 + math.sin(_idle.value * 2 * math.pi * 0.7) * 0.008
              : 1.0;

          return Transform.translate(
            offset: Offset(0, floatY + dozeDip + asleepP * 6),
            child: Transform.scale(
              scale: reactScale * sleepBreath,
              child: CustomPaint(
                size: const Size(220, 190),
                painter: LumiPainter(
                  brightness: b,
                  eyeOpenness: eyeOpen,
                  yawn: yawnP,
                  hemPhase: _idle.value * 2 * math.pi * 1.5,
                  // 물결: 조도가 낮을수록 진폭·속도 감소, 취침 시 정지 (§7.1)
                  hemAmplitude: widget.reduceMotion || isAsleep
                      ? 0.0
                      : (1 - b) .clamp(0.15, 1.0),
                  droop: b * 8.0, // 조도에 따라 아래로 쳐짐
                  glowStrength:
                      (0.25 + 0.75 * b) * (isAsleep ? 0.7 : 1.0),
                  glowColor: colors.lamp,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
