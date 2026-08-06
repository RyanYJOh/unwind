import 'package:flutter/widgets.dart';

import '../tokens/color_ramp.dart';

/// t에서 파생된 색 묶음을 하위 트리에 공급한다.
/// §5.6 성능 계약: 리스트 아이템은 t를 직접 구독하지 않는다 — 상위에서 계산된
/// [UnwindColors]를 전달받는다. 이 InheritedWidget은 그 전달 통로다.
class UnwindTheme extends InheritedWidget {
  final UnwindColors colors;

  const UnwindTheme({super.key, required this.colors, required super.child});

  static UnwindColors of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<UnwindTheme>()!
      .colors;

  @override
  bool updateShouldNotify(UnwindTheme oldWidget) =>
      oldWidget.colors != colors;
}

/// §8.1 textPrimary 크로스페이드 — 어두운↔밝은 텍스트를 겹쳐 그리고
/// kTextCrossfadeMs(180ms) 동안 불투명도를 교차한다. 보간 금지.
class PrimaryText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  const PrimaryText(this.text, {super.key, required this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final flip = colors.textFlipProgress;
    const dur = Duration(milliseconds: kTextCrossfadeMs);
    return Stack(
      children: [
        AnimatedOpacity(
          duration: dur,
          opacity: 1.0 - flip,
          child: Text(text,
              textAlign: textAlign,
              style: style.copyWith(color: colors.textPrimaryDark)),
        ),
        AnimatedOpacity(
          duration: dur,
          opacity: flip,
          child: Text(text,
              textAlign: textAlign,
              style: style.copyWith(color: colors.textPrimaryLight)),
        ),
      ],
    );
  }
}
