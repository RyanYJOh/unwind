import 'package:flutter/widgets.dart';

import '../../domain/models/todd_state.dart';
import 'ghost_view.dart';
import 'todd_dummy_view.dart';

/// 렌더러 전환 스위치 — Rive가 마음에 안 들면 [ToddRenderer.dummy]로
/// 한 줄만 바꾸면 즉시 기존 CustomPainter 더미로 돌아간다.
enum ToddRenderer { rive, dummy }

const kToddRenderer = ToddRenderer.rive;

/// §7.2 Todd 뷰 — 앱 본체가 사용하는 유일한 인터페이스 (PRD 계약 유지).
/// 내부적으로 Rive(GhostView) 또는 더미(ToddDummyView)로 렌더링한다.
/// .riv 로드 실패 시 자동으로 더미 폴백.
class ToddView extends StatelessWidget {
  final ToddState state;
  final bool reduceMotion;

  /// 렌더 크기 (정사각). 홈에서는 화면 점유를 줄이기 위해 축소해 쓴다.
  final double size;

  const ToddView({
    super.key,
    required this.state,
    this.reduceMotion = false,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    return switch (kToddRenderer) {
      ToddRenderer.dummy => ToddDummyView(
        state: state,
        reduceMotion: reduceMotion,
      ),
      ToddRenderer.rive => _ToddRiveAdapter(
        state: state,
        reduceMotion: reduceMotion,
        size: size,
      ),
    };
  }
}

/// PRD ToddState → 브리프 GhostView 계약 변환.
///   brightness(0~1) ↔ sleepiness(0~1) — 의미상 동일 축
///   ToddEvent.react → GhostEvent.checkOff
///   isAsleep 상승 에지 → GhostEvent.allDone / 하강 에지 → 해제
class _ToddRiveAdapter extends StatefulWidget {
  final ToddState state;
  final bool reduceMotion;
  final double size;

  const _ToddRiveAdapter({
    required this.state,
    required this.reduceMotion,
    this.size = 240,
  });

  @override
  State<_ToddRiveAdapter> createState() => _ToddRiveAdapterState();
}

class _ToddRiveAdapterState extends State<_ToddRiveAdapter> {
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
  void didUpdateWidget(_ToddRiveAdapter old) {
    super.didUpdateWidget(old);
    final s = widget.state;
    if (!old.state.isAsleep && s.isAsleep) {
      _event = GhostEvent.allDone;
      _tick++;
    } else if (old.state.isAsleep && !s.isAsleep) {
      // 깨우기 (개정 2026-08-07): allDone 해제 + 기지개·미소 (wakeUpHappy).
      // 단, 깨어나는 순간의 이벤트가 명시되어 있으면 그쪽을 쓴다 —
      // 온보딩의 "톡톡 깨우기"는 poke로 깨어나 실눈만 겨우 뜬다 (2026-08-22).
      final explicit = s.eventTick != old.state.eventTick
          ? switch (s.event) {
              ToddEvent.react => GhostEvent.checkOff,
              ToddEvent.poke => GhostEvent.poke,
              _ => null,
            }
          : null;
      _event = explicit ?? GhostEvent.wakeUpHappy;
      _tick++;
    } else if (s.eventTick != old.state.eventTick && !s.isAsleep) {
      // 잠들어 있으면 어떤 이벤트도 전달하지 않는다 — 깨우지 않는다
      final mapped = switch (s.event) {
        ToddEvent.react => GhostEvent.checkOff,
        ToddEvent.poke => GhostEvent.poke,
        _ => null,
      };
      if (mapped != null) {
        _event = mapped;
        _tick++;
      }
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
      darkCircles: widget.state.darkCircles,
    );
  }
}
