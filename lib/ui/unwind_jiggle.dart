import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 편집 모드의 달달 떨림 (2026-09-14) — 아이폰 홈 화면처럼 "지금은 옮기거나
/// 지울 수 있다"는 신호다.
///
/// 타일이 가로로 길어서 각도를 아주 작게 둔다 (0.6° — 350pt 타일의 끝이
/// ±2pt 남짓 흔들린다). 아이콘처럼 크게 흔들면 멀미가 난다.
///
/// - [seed]로 위상·주기를 흩어 이웃 타일이 같은 박자로 떨지 않게 한다
/// - Reduce Motion이면 떨지 않는다 (§12) — 편집 모드임은 배지·핸들이 알린다
/// - [UnwindJiggle.still] 아래에서는 멈춘다 (손에 들려 끌려 다니는 타일)
/// - 떨지 않을 때도 트리 모양이 같다 — 켜고 끌 때 자식 상태가 날아가지 않는다
class UnwindJiggle extends StatefulWidget {
  final bool active;
  final int seed;
  final Widget child;

  const UnwindJiggle({
    super.key,
    required this.active,
    required this.child,
    this.seed = 0,
  });

  /// 이 아래의 떨림을 멈춘다 — 드래그 프록시처럼 손에 들린 것은 떨지 않는다.
  static Widget still({required Widget child}) => _JiggleStill(child: child);

  @override
  State<UnwindJiggle> createState() => _UnwindJiggleState();
}

class _UnwindJiggleState extends State<UnwindJiggle>
    with SingleTickerProviderStateMixin {
  static const _amplitude = 0.6 * math.pi / 180;
  static const _lift = 0.5; // 세로 들썩임 (pt)

  late final AnimationController _c = AnimationController(
    vsync: this,
    // 250~298ms — 타일마다 박자가 조금씩 다르다
    duration: Duration(milliseconds: 250 + (widget.seed * 37 % 5) * 12),
  );

  /// 짝·홀 타일은 반대 방향에서 출발한다
  double get _phase => (widget.seed.isEven ? 0.0 : 0.5) + widget.seed * 0.13;

  bool _running = false;

  void _sync() {
    final run =
        widget.active &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_JiggleStill.isStill(context);
    if (run == _running) return;
    _running = run;
    if (run) {
      _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UnwindJiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        if (!_running) return Transform.rotate(angle: 0, child: child);
        final a = 2 * math.pi * (_c.value + _phase);
        return Transform.rotate(
          angle: _amplitude * math.sin(a),
          child: Transform.translate(
            offset: Offset(0, _lift * math.cos(a)),
            child: child,
          ),
        );
      },
    );
  }
}

class _JiggleStill extends InheritedWidget {
  const _JiggleStill({required super.child});

  static bool isStill(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_JiggleStill>() != null;

  @override
  bool updateShouldNotify(_JiggleStill oldWidget) => false;
}
