import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../core/haptics/haptics.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';

/// 바텀시트를 §9.4 시트 모션(320ms, theme)으로 띄운다.
/// Material 바텀시트를 쓰지 않는 이유: 모션·배리어·모서리를 전부 우리가 쥔다.
///
/// [dismissible]이면 배리어 탭과 그랩 핸들 아래로 드래그로 닫힌다.
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

  _UnwindSheetRoute({required this.builder, this.dismissible = true});

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
    return _UnwindSheetDragScope(
      controller: controller!,
      dismissible: dismissible,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: UnwindMotion.theme)),
        child: builder(context),
      ),
    );
  }
}

/// 라우트의 애니메이션 컨트롤러를 시트 껍데기에 흘린다 (핸들 드래그용).
class _UnwindSheetDragScope extends InheritedWidget {
  final AnimationController controller;
  final bool dismissible;

  const _UnwindSheetDragScope({
    required this.controller,
    required this.dismissible,
    required super.child,
  });

  static _UnwindSheetDragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UnwindSheetDragScope>();

  @override
  bool updateShouldNotify(_UnwindSheetDragScope old) =>
      controller != old.controller || dismissible != old.dismissible;
}

/// 시트의 껍데기 — 둥근 상단 + 굵은 상단 테두리 + 그랩 핸들.
/// 키보드 인셋은 여기서 흡수한다 (§6.3 함정 2: viewInsets를 즉시 반영).
class UnwindSheet extends StatefulWidget {
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
  State<UnwindSheet> createState() => _UnwindSheetState();
}

class _UnwindSheetState extends State<UnwindSheet> {
  final _bodyKey = GlobalKey();
  bool _popped = false;

  void _pop() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    final scope = _UnwindSheetDragScope.maybeOf(context);
    if (scope == null || !scope.dismissible || _popped) return;
    final box = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    final height = box?.size.height ?? 0;
    if (height <= 0) return;
    final next = (scope.controller.value - details.delta.dy / height).clamp(
      0.0,
      1.0,
    );
    scope.controller.value = next;
    if (next <= 0) _pop();
  }

  void _onHandleDragEnd(DragEndDetails details) {
    if (_popped || !mounted) return;
    final scope = _UnwindSheetDragScope.maybeOf(context);
    if (scope == null || !scope.dismissible) return;
    final velocity = details.primaryVelocity ?? 0;
    final dismiss =
        scope.controller.value < UnwindMotion.sheetDismissFraction ||
        velocity > UnwindMotion.sheetDismissVelocity;
    if (dismiss) {
      _pop();
    } else {
      scope.controller.animateTo(
        1,
        duration: const Duration(milliseconds: UnwindMotion.sheetMs),
        curve: UnwindMotion.theme,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canDrag =
        widget.showHandle &&
        (_UnwindSheetDragScope.maybeOf(context)?.dismissible ?? false);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            key: _bodyKey,
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
                if (widget.showHandle)
                  _GrabHandle(
                    onDragUpdate: canDrag ? _onHandleDragUpdate : null,
                    onDragEnd: canDrag ? _onHandleDragEnd : null,
                  ),
                if (widget.title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      UnwindSpacing.s20,
                      0,
                      UnwindSpacing.s20,
                      UnwindSpacing.s12,
                    ),
                    child: Text(
                      widget.title!,
                      style: UnwindType.headline.copyWith(
                        color: UnwindColors.textPrimary,
                      ),
                    ),
                  ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
                ?widget.bottomBar,
                if (widget.bottomBar == null && bottomInset == 0)
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
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  const _GrabHandle({this.onDragUpdate, this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    final handle = const Center(
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
    );
    return GestureDetector(
      key: const ValueKey('unwindSheetHandle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: UnwindTouch.minTarget,
          minWidth: double.infinity,
        ),
        child: handle,
      ),
    );
  }
}
