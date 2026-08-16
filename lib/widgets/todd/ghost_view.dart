import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart' as rive;

import '../../domain/models/todd_state.dart' show ToddMode, ToddDayActivity;
import 'ghost_contract.dart';
import 'ghost_painter_view.dart';

export 'ghost_contract.dart' show GhostEvent;

/// Rive 브리프 §0 — 캐릭터 캡슐화 위젯.
/// 앱 본체는 이 인터페이스로만 캐릭터를 다루며 내부가 Rive인지 알지 못한다.
///
/// - [sleepiness]: 0.0(말똥말똥) ~ 1.0(잠들기 직전)
/// - [event]: 이산 이벤트. 같은 이벤트 연속 발사는 [eventTick] 증가로 구분.
/// - 하품 랜덤 타이머는 내부에 캡슐화 (§6.3)
/// - Reduce Motion([reduceMotion])이면 하품 타이머를 멈춘다 (앱 §9.5)
class GhostView extends StatefulWidget {
  final double sleepiness;
  final GhostEvent? event;
  final int eventTick;
  final double size;
  final bool reduceMotion;

  /// 생활 모드 (개편 2026-08-08) — null이면 기존 sleepiness 매핑.
  /// Rive 에셋이 생기면 뷰모델 입력으로 연결한다. 현재는 painter 전용.
  final ToddMode? mode;
  final ToddDayActivity? activity;
  final double dazzle;

  /// 전날 못 잔 밤의 흔적 (세계관 2026-08-15) — 눈 밑 다크서클
  final bool darkCircles;

  /// .riv 로드 실패 시 대신 그릴 위젯.
  /// 지정하지 않으면 [GhostPainterView] (브리프 사양의 Flutter 구현)를 쓴다.
  final WidgetBuilder? fallbackBuilder;

  const GhostView({
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
    this.fallbackBuilder,
  });

  @override
  State<GhostView> createState() => _GhostViewState();
}

class _GhostViewState extends State<GhostView> {
  rive.FileLoader? _fileLoader;
  rive.ViewModelInstance? _vmi;

  /// .riv 에셋 존재 여부 — 없으면 RiveWidgetBuilder를 만들지 않는다
  /// (없는 에셋을 로드하면 비동기 예외가 테스트/콘솔로 샌다)
  bool _assetOk = false;
  Timer? _yawnTimer;
  Timer? _happyResetTimer;
  DateTime _lastEventAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _seenTick = -1;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    // 기본 Rive Renderer, 기기 이슈 시 Factory.flutter 폴백 (브리프 §6.1).
    // 네이티브 런타임이 없는 환경(위젯 테스트 등)에서는 폴백 렌더러로 동작.
    _checkAssetAndLoad();
  }

  Future<void> _checkAssetAndLoad() async {
    try {
      await rootBundle.load(GhostContract.asset);
      if (!mounted) return;
      _fileLoader = rive.FileLoader.fromAsset(
        GhostContract.asset,
        riveFactory: rive.Factory.rive,
      );
      setState(() => _assetOk = true);
    } catch (_) {
      // 에셋 없음 / 런타임 사용 불가 — 폴백 렌더러 유지
      _fileLoader = null;
    }
  }

  /// 브리프 §6.3 — sleepiness가 높을수록 자주 하품. 이벤트 직후 2초 금지.
  /// Rive 로드 성공 후에만 시작한다 (§9.5 Reduce Motion 시 발사 안 함).
  void _startYawnTimer() {
    _yawnTimer?.cancel();
    _yawnTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (widget.reduceMotion) return;
      if (DateTime.now().difference(_lastEventAt).inSeconds < 2) return;
      final chance = widget.sleepiness * 0.4; // 최대 40%
      if (_rng.nextDouble() < chance) {
        _vmi?.trigger(GhostContract.vmYawn)?.trigger();
      }
    });
  }

  void _applySleepiness() {
    // prop 0.0~1.0 → 뷰모델 Number 0~100 (브리프 §6.3)
    _vmi?.number(GhostContract.vmSleepiness)?.value =
        (widget.sleepiness.clamp(0.0, 1.0) * 100);
  }

  void _applyDarkCircles() {
    _vmi?.boolean(GhostContract.vmDarkCircles)?.value = widget.darkCircles;
  }

  void _fireEvent(GhostEvent event) {
    _lastEventAt = DateTime.now();
    switch (event) {
      case GhostEvent.checkOff:
        _vmi?.trigger(GhostContract.vmCheckOff)?.trigger();
      case GhostEvent.poke:
        _vmi?.trigger(GhostContract.vmPoke)?.trigger();
      case GhostEvent.allDone:
        _vmi?.boolean(GhostContract.vmAllDone)?.value = true;
      case GhostEvent.wakeUpHappy:
        final happy = _vmi?.boolean(GhostContract.vmHappy);
        happy?.value = true;
        // 재생 후 false 복귀 (브리프 §6.3)
        _happyResetTimer?.cancel();
        _happyResetTimer = Timer(const Duration(milliseconds: 1600), () {
          happy?.value = false;
        });
    }
  }

  @override
  void didUpdateWidget(GhostView old) {
    super.didUpdateWidget(old);
    if (old.sleepiness != widget.sleepiness) _applySleepiness();
    if (old.darkCircles != widget.darkCircles) _applyDarkCircles();
    if (widget.event != null && widget.eventTick != _seenTick) {
      _seenTick = widget.eventTick;
      _fireEvent(widget.event!);
    }
    // allDone 해제 (다음 날)
    if (old.event == GhostEvent.allDone && widget.event != GhostEvent.allDone) {
      _vmi?.boolean(GhostContract.vmAllDone)?.value = false;
    }
  }

  @override
  void dispose() {
    _yawnTimer?.cancel();
    _happyResetTimer?.cancel();
    _vmi?.dispose();
    _fileLoader?.dispose(); // 브리프 §6.1: fileLoader만 dispose
    super.dispose();
  }

  Widget _painterFallback() => GhostPainterView(
    sleepiness: widget.sleepiness,
    event: widget.event,
    eventTick: widget.eventTick,
    size: widget.size,
    reduceMotion: widget.reduceMotion,
    mode: widget.mode,
    activity: widget.activity,
    dazzle: widget.dazzle,
    darkCircles: widget.darkCircles,
  );

  @override
  Widget build(BuildContext context) {
    final loader = _fileLoader;
    if (!_assetOk || loader == null) {
      // 에셋 없음 / Rive 런타임 사용 불가 — Flutter 고스트 렌더러
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.fallbackBuilder?.call(context) ?? _painterFallback(),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: rive.RiveWidgetBuilder(
        fileLoader: loader,
        artboardSelector: rive.ArtboardSelector.byName(GhostContract.artboard),
        stateMachineSelector: rive.StateMachineSelector.byName(
          GhostContract.stateMachine,
        ),
        dataBind: rive.DataBind.byName(GhostContract.vmName),
        onLoaded: (state) {
          _vmi = state.viewModelInstance;
          _applySleepiness();
          _applyDarkCircles();
          if (widget.event == GhostEvent.allDone) {
            _vmi?.boolean(GhostContract.vmAllDone)?.value = true;
          }
          _startYawnTimer();
        },
        builder: (context, state) => switch (state) {
          rive.RiveLoaded() => rive.RiveWidget(
            controller: state.controller,
            fit: rive.Fit.contain,
          ),
          rive.RiveFailed() =>
            widget.fallbackBuilder?.call(context) ?? _painterFallback(),
          rive.RiveLoading() => const SizedBox.shrink(),
        },
      ),
    );
  }
}
