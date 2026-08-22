import 'dart:async';

import 'package:flutter/widgets.dart';

/// 타이프라이터 텍스트 (온보딩 2026-08-22) — 글자가 하나씩 나타나며
/// 캐릭터가 직접 말을 거는 감각을 만든다.
///
/// - 레이아웃은 **처음부터 전체 문장 크기로 확정**된다: 아직 안 보인 글자를
///   투명 스팬으로 함께 그려서, 타이핑 중에 주변 위젯이 밀리지 않는다.
/// - 문장부호에서 숨을 고른다: `.`/`…`는 길게, `,`/`!`/`?`/줄바꿈은 짧게.
///   그래서 "Hi, I'm To..d.." 같은 문장은 점에서 늘어지며 **말끝이 흐려지는
///   (졸린) 리듬**이 공짜로 생긴다.
/// - [text]가 바뀌면 처음부터 다시 친다 (같은 자리에서 대사가 바뀌는 연출).
/// - Reduce Motion이면 전체 문장을 즉시 보여주고 [onDone]을 바로 부른다.
/// - 스크린 리더에는 항상 **전체 문장**을 읽힌다 (부분 문자열이 아니라).
class UnwindTypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// 기본 글자 간격. 문장부호는 이 값의 배수로 쉰다.
  final Duration charInterval;

  /// 첫 글자가 나오기까지의 지연 ([text]가 바뀌어 다시 칠 때도 적용).
  final Duration startDelay;

  /// false면 애니메이션 없이 정적으로 그린다.
  final bool animate;

  /// 마지막 글자가 나온 직후.
  final VoidCallback? onDone;

  /// 글자가 하나 나올 때마다, 지금까지 보인 문자열을 넘긴다 —
  /// 특정 지점(예: 첫 `.`)에 연출을 동기화할 때 쓴다.
  final ValueChanged<String>? onAdvance;

  const UnwindTypewriterText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.charInterval = const Duration(milliseconds: 45),
    this.startDelay = Duration.zero,
    this.animate = true,
    this.onDone,
    this.onAdvance,
  });

  @override
  State<UnwindTypewriterText> createState() => _UnwindTypewriterTextState();
}

class _UnwindTypewriterTextState extends State<UnwindTypewriterText> {
  late List<String> _clusters; // grapheme cluster 단위 (이모지 안전)
  int _shown = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _clusters = widget.text.characters.toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery(Reduce Motion)를 읽어야 해서 initState가 아니라 여기서 시작
    if (!_started) {
      _started = true;
      _start();
    }
  }

  @override
  void didUpdateWidget(UnwindTypewriterText old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text) {
      _timer?.cancel();
      _clusters = widget.text.characters.toList();
      _shown = 0;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final instant =
        !widget.animate ||
        MediaQuery.disableAnimationsOf(context) ||
        _clusters.isEmpty;
    if (instant) {
      setStateIfChanged(_clusters.length);
      // build 도중일 수 있으니 콜백은 다음 프레임으로
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone?.call();
      });
      return;
    }
    _timer = Timer(widget.startDelay + widget.charInterval, _advance);
  }

  void setStateIfChanged(int shown) {
    if (_shown == shown) return;
    if (mounted) setState(() => _shown = shown);
  }

  /// 방금 나온 글자에 따라 다음 글자까지 쉬는 시간.
  Duration _pauseAfter(String cluster) {
    final base = widget.charInterval;
    return switch (cluster) {
      '.' || '…' => base * 8, // 말끝이 흐려지는 (졸린) 점
      ',' || '!' || '?' || '\n' => base * 4,
      _ => base,
    };
  }

  void _advance() {
    if (!mounted) return;
    setState(() => _shown++);
    widget.onAdvance?.call(_clusters.take(_shown).join());
    if (_shown >= _clusters.length) {
      widget.onDone?.call();
      return;
    }
    _timer = Timer(_pauseAfter(_clusters[_shown - 1]), _advance);
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _clusters.take(_shown).join()),
          // 남은 글자는 투명으로 미리 그려 레이아웃을 고정한다
          TextSpan(
            text: _clusters.skip(_shown).join(),
            style: const TextStyle(color: Color(0x00000000)),
          ),
        ],
      ),
      textAlign: widget.textAlign,
      semanticsLabel: widget.text,
    );
  }
}
