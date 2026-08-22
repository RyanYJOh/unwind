import 'package:flutter/widgets.dart';

/// 톡 — 폭신한 몸이 납작 눌렸다 탱글하게 되튀는 스쿼시&바운스
/// (온보딩 2026-08-22 → 공용화 3차: 홈의 Todd도 같은 물성을 갖는다).
/// 밑단을 고정한 채(스커트가 바닥에 앉아 있으므로) 세로로 눌리고 가로로
/// 퍼졌다가, elasticOut으로 살짝 키를 넘겨 되튀며 잦아든다 — Todd를
/// 두드릴 때 손끝이 정말 닿는 느낌.
/// [tick]이 바뀔 때마다 한 번 재생한다. Reduce Motion이면 정지.
class ToddPokeSquish extends StatefulWidget {
  final int tick;
  final Widget child;

  const ToddPokeSquish({super.key, required this.tick, required this.child});

  @override
  State<ToddPokeSquish> createState() => _ToddPokeSquishState();
}

class _ToddPokeSquishState extends State<ToddPokeSquish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// 눌리는 구간 (전체의 앞 15%) — 짧고 단호하게 눌려야 "탄력"이 산다
  static const _press = 0.15;
  static const _squashY = 0.10; // 세로로 10% 눌림
  static const _squashX = 0.062; // 가로로 6% 퍼짐 (부피 보존의 인상)

  @override
  void didUpdateWidget(ToddPokeSquish old) {
    super.didUpdateWidget(old);
    if (widget.tick != old.tick && !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 스쿼시 양 k(t): 0→1로 확 눌렸다가, elasticOut을 뒤집어 0으로 —
  /// 도중에 음수로 살짝 넘치며(= 키가 조금 커졌다가) 통통 잦아든다.
  double _envelope(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < _press) return Curves.easeOutCubic.transform(t / _press);
    final u = (t - _press) / (1 - _press);
    return 1 - Curves.elasticOut.transform(u);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final k = _envelope(_c.value);
        if (k == 0) return child!;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(
            1 + _squashX * k,
            1 - _squashY * k,
            1,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
