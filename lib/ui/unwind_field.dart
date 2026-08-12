import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';

/// 듀오링고식 입력 필드 — 두툼한 면 + 2px 테두리.
/// 포커스가 들어오면 테두리가 앰버로 바뀐다 (다른 강조 수단 없음).
class UnwindTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool autofocus;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final TextStyle? textStyle;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// 시트의 주 입력처럼 테두리 없이 크게 쓸 때
  final bool bare;

  const UnwindTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.autofocus = false,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.textStyle,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.bare = false,
  });

  @override
  State<UnwindTextField> createState() => _UnwindTextFieldState();
}

class _UnwindTextFieldState extends State<UnwindTextField> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool _ownsNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focusNode == null;
    _node.addListener(_onFocus);
    _focused = _node.hasFocus;
  }

  void _onFocus() {
    if (!mounted || _focused == _node.hasFocus) return;
    setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.textStyle ?? UnwindType.bodyStrong).copyWith(
      color: UnwindColors.textPrimary,
    );

    // TextField는 Material 조상을 요구한다. 시트 밖(일반 화면)에서도 쓸 수
    // 있도록 컴포넌트가 스스로 투명 Material을 깐다.
    final field = Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        maxLength: widget.maxLength,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: style,
        cursorColor: UnwindColors.accent,
        cursorWidth: 2.5,
        cursorRadius: const Radius.circular(2),
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: () {}, // 포커스 유지 (연속 입력, §6.3)
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: style.copyWith(color: UnwindColors.textMuted),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );

    if (widget.bare) return field;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(
        horizontal: UnwindSpacing.s16,
        vertical: UnwindSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: UnwindColors.surfaceAlt,
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        border: Border.all(
          color: _focused ? UnwindColors.accent : UnwindColors.border,
          width: UnwindStroke.base,
        ),
      ),
      child: field,
    );
  }
}
