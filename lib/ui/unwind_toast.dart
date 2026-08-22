import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/tokens/motion.dart';
import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_button.dart';

/// 상단 토스트 — 푸시 알림 형태. 가벼운 확인 피드백에 쓴다.
/// 루트 오버레이에 꽂혀 시트·모달 위에서도 보이고, 자동으로 사라진다.
void showUnwindToast(
  BuildContext context, {
  required String title,
  String? body,

  /// 되돌리기 같은 즉시 액션. 누르면 토스트가 닫히고 [onAction]이 실행된다.
  String? actionLabel,
  VoidCallback? onAction,

  /// 머무는 시간 오버라이드 — 안내(instruction)처럼 읽을 시간이 더 필요한
  /// 토스트만 지정한다. null이면 기본값 (확인 2.6초 / 액션 2초).
  Duration? visibleFor,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _UnwindToast(
      title: title,
      body: body,
      actionLabel: actionLabel,
      onAction: onAction,
      visibleFor: visibleFor,
      onDismissed: entry.remove,
    ),
  );
  overlay.insert(entry);
}

class _UnwindToast extends StatefulWidget {
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? visibleFor;
  final VoidCallback onDismissed;

  const _UnwindToast({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.visibleFor,
    required this.onDismissed,
  });

  @override
  State<_UnwindToast> createState() => _UnwindToastState();
}

class _UnwindToastState extends State<_UnwindToast>
    with SingleTickerProviderStateMixin {
  /// 머무는 시간. 삭제 되돌리기는 짧게 — 2초면 읽고 스와이프할 여유가 있다.
  static const _visibleMs = 2600;
  static const _visibleWithActionMs = 2000;

  late final AnimationController _c;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.sheetMs),
    );
    _c.forward();
    _timer = Timer(
      widget.visibleFor ??
          Duration(
            milliseconds: widget.onAction == null
                ? _visibleMs
                : _visibleWithActionMs,
          ),
      _dismiss,
    );
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDismissed();
  }

  /// 스와이프는 [Dismissible]이 이미 올려 보냈으니 역재생 없이 바로 제거.
  void _dismissFromSwipe() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnwindSpacing.s16,
            vertical: UnwindSpacing.s8,
          ),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -1.4),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _c, curve: UnwindMotion.settle)),
            child: FadeTransition(
              opacity: _c,
              child: Dismissible(
                key: const ValueKey('unwind-toast'),
                direction: DismissDirection.up,
                resizeDuration: Duration.zero,
                onDismissed: (_) => _dismissFromSwipe(),
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UnwindSpacing.s16,
                      vertical: UnwindSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      color: UnwindColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(UnwindRadius.md),
                      border: Border.all(
                        color: UnwindColors.borderStrong,
                        width: UnwindStroke.base,
                      ),
                      boxShadow: const [
                        // §11 — 블러 없는 압출면
                        BoxShadow(
                          color: UnwindColors.solid,
                          offset: Offset(0, UnwindDepth.base),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 등이 하나 켜졌다는 표시
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: UnwindColors.accent,
                            borderRadius: BorderRadius.circular(UnwindRadius.sm),
                          ),
                        ),
                        const SizedBox(width: UnwindSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: UnwindType.bodyStrong.copyWith(
                                  color: UnwindColors.textPrimary,
                                ),
                              ),
                              if (widget.body != null) ...[
                                const SizedBox(height: UnwindSpacing.s2),
                                Text(
                                  widget.body!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: UnwindType.caption.copyWith(
                                    color: UnwindColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: UnwindSpacing.s8),
                          UnwindButton(
                            label: widget.actionLabel!,
                            small: true,
                            expand: false,
                            onPressed: () {
                              _dismiss();
                              widget.onAction?.call();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
