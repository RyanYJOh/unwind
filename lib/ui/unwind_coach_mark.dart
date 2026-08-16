import 'package:flutter/widgets.dart';

import '../core/tokens/motion.dart';
import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';

/// 특정 점을 가리키는 코치마크 — 스크림에 원형 구멍을 뚫어 손잡이 등이
/// 드러나게 한다. §11 블러 금지: 구멍은 path even-odd로만 판다.
///
/// 구멍 안은 히트 테스트를 통과시켜 아래 위젯(전등 줄)을 당길 수 있다.
class UnwindCoachMark extends StatefulWidget {
  final Offset holeCenter;
  final double holeRadius;
  final String message;
  final VoidCallback onDismiss;
  final bool reduceMotion;

  const UnwindCoachMark({
    super.key,
    required this.holeCenter,
    required this.holeRadius,
    required this.message,
    required this.onDismiss,
    this.reduceMotion = false,
  });

  @override
  State<UnwindCoachMark> createState() => _UnwindCoachMarkState();
}

class _UnwindCoachMarkState extends State<UnwindCoachMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.coachPulseMs),
    );
    if (!widget.reduceMotion) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(UnwindCoachMark old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion != old.reduceMotion) {
      if (widget.reduceMotion) {
        _pulse.stop();
        _pulse.value = 0;
      } else {
        _pulse.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = context.findRenderObject() as RenderBox?;
        final local = box?.hasSize == true
            ? box!.globalToLocal(widget.holeCenter)
            : widget.holeCenter;
        final r = widget.holeRadius;
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  size: Size(w, h),
                  painter: _CoachPainter(
                    hole: local,
                    radius: r,
                    pulse: widget.reduceMotion ? 0 : _pulse.value,
                  ),
                ),
              ),
            ),
            // 구멍 밖만 탭 — 안쪽은 전등 줄로 통과
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: (local.dy - r).clamp(0, h),
              child: GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              left: 0,
              top: (local.dy + r).clamp(0, h),
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              left: 0,
              top: (local.dy - r).clamp(0, h),
              width: (local.dx - r).clamp(0, w),
              height: r * 2,
              child: GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              left: (local.dx + r).clamp(0, w),
              top: (local.dy - r).clamp(0, h),
              right: 0,
              height: r * 2,
              child: GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            _Bubble(
              hole: local,
              holeRadius: r,
              screenSize: Size(w, h),
              message: widget.message,
              onTap: widget.onDismiss,
            ),
          ],
        );
      },
    );
  }
}

class _CoachPainter extends CustomPainter {
  final Offset hole;
  final double radius;
  final double pulse;

  const _CoachPainter({
    required this.hole,
    required this.radius,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final holeRect = Rect.fromCircle(center: hole, radius: radius);
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(holeRect);
    canvas.drawPath(scrim, Paint()..color = UnwindColors.scrim);

    final ringR = radius + UnwindSpacing.s4 * pulse;
    canvas.drawCircle(
      hole,
      ringR,
      Paint()
        ..color = UnwindColors.accent.withValues(
          alpha: 0.55 + 0.45 * (1 - pulse),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = UnwindStroke.base,
    );
  }

  @override
  bool shouldRepaint(_CoachPainter old) =>
      old.hole != hole || old.radius != radius || old.pulse != pulse;
}

class _Bubble extends StatelessWidget {
  final Offset hole;
  final double holeRadius;
  final Size screenSize;
  final String message;
  final VoidCallback onTap;

  const _Bubble({
    required this.hole,
    required this.holeRadius,
    required this.screenSize,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const maxW = 220.0;
    final right = screenSize.width - (hole.dx - holeRadius - UnwindSpacing.s12);
    final top = (hole.dy - UnwindSpacing.s20).clamp(
      UnwindSpacing.s48,
      screenSize.height - UnwindSpacing.s48,
    );

    return Positioned(
      right: right,
      top: top,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxW),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: UnwindColors.surfaceHigh,
              borderRadius: BorderRadius.circular(UnwindRadius.md),
              border: Border.all(
                color: UnwindColors.accent,
                width: UnwindStroke.base,
              ),
              boxShadow: const [
                BoxShadow(
                  color: UnwindColors.solid,
                  offset: Offset(0, UnwindDepth.base),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UnwindSpacing.s16,
                vertical: UnwindSpacing.s12,
              ),
              child: Text(
                message,
                style: UnwindType.bodyStrong.copyWith(
                  color: UnwindColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
