import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../core/haptics/haptics.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';

/// 바텀시트를 §9.4 시트 모션(320ms, theme)으로 띄운다.
/// Material 바텀시트를 쓰지 않는 이유: 모션·배리어·모서리를 전부 우리가 쥔다.
Future<T?> showUnwindSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  UnwindHapticsScope.of(context).sheetOpen();
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(_UnwindSheetRoute<T>(builder: builder, dismissible: dismissible));
}

class _UnwindSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final bool dismissible;

  _UnwindSheetRoute({required this.builder, required this.dismissible});

  @override
  Color? get barrierColor => UnwindColors.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => 'Close';

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: UnwindMotion.sheetMs);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: UnwindMotion.theme)),
      child: builder(context),
    );
  }
}

/// 시트의 껍데기 — 둥근 상단 + 굵은 상단 테두리 + 그랩 핸들.
/// 키보드 인셋은 여기서 흡수한다 (§6.3 함정 2: viewInsets를 즉시 반영).
class UnwindSheet extends StatelessWidget {
  final Widget child;

  /// 키보드 위에 고정되는 바 (입력 시트의 날짜 바 등)
  final Widget? bottomBar;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry padding;

  const UnwindSheet({
    super.key,
    required this.child,
    this.bottomBar,
    this.title,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(
      UnwindSpacing.s20,
      0,
      UnwindSpacing.s20,
      UnwindSpacing.s16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: UnwindColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(UnwindRadius.lg),
              ),
              border: Border(
                top: BorderSide(
                  color: UnwindColors.borderStrong,
                  width: UnwindStroke.base,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHandle) const _GrabHandle(),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      UnwindSpacing.s20,
                      0,
                      UnwindSpacing.s20,
                      UnwindSpacing.s12,
                    ),
                    child: Text(
                      title!,
                      style: UnwindType.headline.copyWith(
                        color: UnwindColors.textPrimary,
                      ),
                    ),
                  ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(padding: padding, child: child),
                ),
                ?bottomBar,
                if (bottomBar == null && bottomInset == 0)
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: UnwindSpacing.s12),
    child: Center(
      child: SizedBox(
        width: 44,
        height: 5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: UnwindColors.borderStrong,
            borderRadius: BorderRadius.all(Radius.circular(UnwindRadius.pill)),
          ),
        ),
      ),
    ),
  );
}
