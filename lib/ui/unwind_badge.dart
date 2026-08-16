import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';

/// 아이콘 우측 상단의 미확인 점.
///
/// 앰버는 앱 전체가 쓰는 색이라 알림으로 안 읽힌다 — 점은 항상
/// [UnwindColors.danger] 코랄. 흰 아이콘 위에서도 떨어지게 ink 링을 두른다.
class UnwindBadgeDot extends StatelessWidget {
  final Widget child;
  final bool visible;

  const UnwindBadgeDot({
    super.key,
    required this.child,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: UnwindColors.danger,
                shape: BoxShape.circle,
                border: Border.all(
                  color: UnwindColors.ink,
                  width: UnwindStroke.base,
                ),
              ),
              // 지름 s12 = 채움 s8 + ink 링(base 2pt × 2). 8pt만 주면
              // 테두리가 안쪽으로 먹어 점이 너무 작아진다.
              child: const SizedBox(
                width: UnwindSpacing.s12,
                height: UnwindSpacing.s12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
