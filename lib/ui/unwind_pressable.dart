import 'package:flutter/widgets.dart';

import '../core/haptics/haptics.dart';
import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';

/// 컴포넌트가 발사할 햅틱의 의미 단위. 화면이 아니라 컴포넌트가 고른다.
enum UnwindHapticKind {
  none,
  tap,
  selection,
  toggleOn,
  toggleOff,
  success,
  warning,
  error,
}

extension UnwindHapticFire on UnwindHaptics {
  Future<void> fire(UnwindHapticKind kind) => switch (kind) {
    UnwindHapticKind.none => Future<void>.value(),
    UnwindHapticKind.tap => tap(),
    UnwindHapticKind.selection => selection(),
    UnwindHapticKind.toggleOn => toggle(on: true),
    UnwindHapticKind.toggleOff => toggle(on: false),
    UnwindHapticKind.success => success(),
    UnwindHapticKind.warning => warning(),
    UnwindHapticKind.error => error(),
  };
}

/// 디자인 시스템 v2의 **물성 원자**.
///
/// 듀오링고식 3D: 요소 아래에 [depth]만큼 압출면(blur 0의 solid offset
/// shadow)이 깔려 있고, 누르면 그 위로 내려앉아 압출면이 사라진다.
/// §11 "블러 금지"를 어기지 않으면서 확실한 촉감을 준다.
///
/// 레이아웃은 흔들리지 않는다 — 압출 높이만큼 아래 여백을 미리 잡아 두고
/// 안쪽에서만 움직인다.
///
/// 모든 탭에 [haptic]이 붙는다. 이 위젯을 쓰면 햅틱 배선은 공짜다.
class UnwindPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 압출 깊이. 0이면 3D 없이 눌림 축소만.
  final double depth;
  final Color shadowColor;
  final BorderRadius? borderRadius;
  final UnwindHapticKind haptic;
  final String? semanticLabel;

  /// 스크린리더가 읽는 현재 값 (예: 스위치의 켜짐/꺼짐)
  final String? semanticValue;
  final bool isButton;
  final bool? isToggled;

  /// 3D가 없을 때(depth == 0) 눌림 축소 배율
  final double pressScale;

  const UnwindPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.depth = UnwindDepth.base,
    this.shadowColor = UnwindColors.solid,
    this.borderRadius,
    this.haptic = UnwindHapticKind.tap,
    this.semanticLabel,
    this.semanticValue,
    this.isButton = true,
    this.isToggled,
    this.pressScale = 0.96,
  });

  bool get _enabled => onTap != null || onLongPress != null;

  @override
  State<UnwindPressable> createState() => _UnwindPressableState();
}

class _UnwindPressableState extends State<UnwindPressable> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    UnwindHapticsScope.of(context).fire(widget.haptic);
    widget.onTap!();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    UnwindHapticsScope.of(context).fire(UnwindHapticKind.warning);
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down && widget._enabled;
    final depth = widget.depth;
    const dur = Duration(milliseconds: UnwindDepth.pressMs);

    Widget body = widget.child;

    if (depth > 0) {
      body = AnimatedContainer(
        duration: dur,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, pressed ? depth : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, pressed ? 0 : depth),
              blurRadius: 0, // §11 — 블러 금지. 압출면은 단색이다.
            ),
          ],
        ),
        child: body,
      );
      // 압출 높이만큼 아래 자리를 미리 비워 둔다 — 눌러도 레이아웃 불변
      body = Padding(
        padding: EdgeInsets.only(bottom: depth),
        child: body,
      );
    } else {
      body = AnimatedScale(
        duration: dur,
        curve: Curves.easeOut,
        scale: pressed ? widget.pressScale : 1.0,
        child: body,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      value: widget.semanticValue,
      button: widget.isButton,
      toggled: widget.isToggled,
      enabled: widget._enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        onTapDown: widget._enabled ? (_) => _setDown(true) : null,
        onTapUp: widget._enabled ? (_) => _setDown(false) : null,
        onTapCancel: widget._enabled ? () => _setDown(false) : null,
        child: body,
      ),
    );
  }
}
