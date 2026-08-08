import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/tokens/color_ramp.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';

/// 상단 토스트 — 푸시 알림 형태 (개편 2026-08-08).
/// 할 일 추가 등 가벼운 확인 피드백에 쓴다. 루트 오버레이에 꽂혀
/// 시트·모달 위에서도 보인다. 자동으로 사라진다.
void showTopToast(BuildContext context,
    {required String title, String? body}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      title: title,
      body: body,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String title;
  final String? body;
  final VoidCallback onDismissed;

  const _TopToast(
      {required this.title, required this.body, required this.onDismissed});

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  static const _visibleMs = 2600; // 머무는 시간

  late final AnimationController _c;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.sheetMs));
    _c.forward();
    _timer = Timer(const Duration(milliseconds: _visibleMs), _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    await _c.reverse();
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
    // 홈 베이스는 항상 다크(darkGlow) — 밤 정거장 색으로 고정
    final colors = lerpRamp(1.0);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: UnwindSpacing.s16, vertical: UnwindSpacing.s8),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: _c, curve: UnwindMotion.settle)),
            child: FadeTransition(
              opacity: _c,
              child: GestureDetector(
                onTap: _dismiss,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(UnwindRadius.lg),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                          color: colors.shadow,
                          blurRadius: 24,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: UnwindSpacing.s16,
                        vertical: UnwindSpacing.s12),
                    child: Row(
                      children: [
                        // 램프 점등 인디케이터
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.lamp,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      colors.lamp.withValues(alpha: 0.6),
                                  blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(width: UnwindSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: UnwindType.bodyStrong.copyWith(
                                      color: colors.textPrimarySnap,
                                      decoration: TextDecoration.none)),
                              if (widget.body != null) ...[
                                const SizedBox(height: 2),
                                Text(widget.body!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: UnwindType.caption.copyWith(
                                        color: colors.textSecondary,
                                        decoration: TextDecoration.none)),
                              ],
                            ],
                          ),
                        ),
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
