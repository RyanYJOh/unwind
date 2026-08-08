import 'package:flutter/widgets.dart';

import '../../domain/models/lumi_state.dart';
import 'ghost_view.dart';
import 'lumi_dummy_view.dart';

/// 렌더러 전환 스위치 — Rive가 마음에 안 들면 [LumiRenderer.dummy]로
/// 한 줄만 바꾸면 즉시 기존 CustomPainter 더미로 돌아간다.
enum LumiRenderer { rive, dummy }

const kLumiRenderer = LumiRenderer.rive;

/// §7.2 Lumi 뷰 — 앱 본체가 사용하는 유일한 인터페이스 (PRD 계약 유지).
/// 내부적으로 Rive(GhostView) 또는 더미(LumiDummyView)로 렌더링한다.
/// .riv 로드 실패 시 자동으로 더미 폴백.
class LumiView extends StatelessWidget {
  final LumiState state;
  final bool reduceMotion;

  /// 렌더 크기 (정사각). 홈에서는 화면 점유를 줄이기 위해 축소해 쓴다.
  final double size;

  const LumiView(
      {super.key,
      required this.state,
      this.reduceMotion = false,
      this.size = 240});

  @override
  Widget build(BuildContext context) {
    return switch (kLumiRenderer) {
      LumiRenderer.dummy =>
        LumiDummyView(state: state, reduceMotion: reduceMotion),
      LumiRenderer.rive =>
        _LumiRiveAdapter(state: state, reduceMotion: reduceMotion, size: size),
    };
  }
}

/// PRD LumiState → 브리프 GhostView 계약 변환.
///   brightness(0~1) ↔ sleepiness(0~1) — 의미상 동일 축
///   LumiEvent.react → GhostEvent.checkOff
///   isAsleep 상승 에지 → GhostEvent.allDone / 하강 에지 → 해제
class _LumiRiveAdapter extends StatefulWidget {
  final LumiState state;
  final bool reduceMotion;
  final double size;

  const _LumiRiveAdapter(
      {required this.state, required this.reduceMotion, this.size = 240});

  @override
  State<_LumiRiveAdapter> createState() => _LumiRiveAdapterState();
}

class _LumiRiveAdapterState extends State<_LumiRiveAdapter> {
  GhostEvent? _event;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    if (widget.state.isAsleep) {
      _event = GhostEvent.allDone;
      _tick++;
    }
  }

  @override
  void didUpdateWidget(_LumiRiveAdapter old) {
    super.didUpdateWidget(old);
    final s = widget.state;
    if (!old.state.isAsleep && s.isAsleep) {
      _event = GhostEvent.allDone;
      _tick++;
    } else if (old.state.isAsleep && !s.isAsleep) {
      // 깨우기 (개정 2026-08-07): allDone 해제 + 기지개·미소 (wakeUpHappy)
      _event = GhostEvent.wakeUpHappy;
      _tick++;
    } else if (s.eventTick != old.state.eventTick &&
        s.event == LumiEvent.react &&
        !s.isAsleep) {
      _event = GhostEvent.checkOff;
      _tick++;
    }
  }

  @override
  Widget build(BuildContext context) {
    // .riv가 있으면 Rive, 없으면 GhostPainterView(브리프 사양 Flutter 구현)
    return GhostView(
      sleepiness: widget.state.brightness,
      event: _event,
      eventTick: _tick,
      size: widget.size,
      reduceMotion: widget.reduceMotion,
      // 생활 모드 (개편 2026-08-08) — null이면 이전 방식 그대로
      mode: widget.state.mode,
      activity: widget.state.activity,
      dazzle: widget.state.dazzle,
    );
  }
}
