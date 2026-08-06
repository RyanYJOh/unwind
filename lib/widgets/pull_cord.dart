import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/haptics/haptics.dart';
import '../core/theme/unwind_theme.dart';
import '../core/tokens/motion.dart';
import '../l10n/generated/app_localizations.dart';

/// §6.4 전등 줄 — 하루를 닫는 마무리 액션. 이 앱의 클라이맥스.
///
/// - 당기는 중: 0~72px, 저항 곡선(뒤로 갈수록 무거워짐)
/// - 임계점 56px 통과: mediumImpact + 손잡이가 미세하게 밝아짐
/// - 임계 이상 놓음: 스프링으로 튕겨 올라가고 소등 시퀀스 시작
/// - 임계 미만 놓음: 원위치 복귀, 아무 일도 없음
/// - 비활성(할 일 0개 / 이미 당김): 흐리게, 당겨지지 않음
class PullCord extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPull;
  final UnwindHaptics haptics;

  /// 줄이 늘어져 있는 기본 길이(px)
  final double restLength;

  const PullCord({
    super.key,
    required this.enabled,
    required this.onPull,
    required this.haptics,
    this.restLength = 148,
  });

  @override
  State<PullCord> createState() => _PullCordState();
}

class _PullCordState extends State<PullCord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring; // 놓았을 때 복귀 (unbounded)
  double _rawDrag = 0.0; // 손가락 누적 이동
  double _extension = 0.0; // 화면에 보이는 늘어남 (저항 적용)
  bool _pastThreshold = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this, value: 0.0)
      ..addListener(() {
        setState(() => _extension = math.max(0.0, _spring.value));
      });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  /// 저항 곡선: 뒤로 갈수록 무거워짐. raw → 표시 늘어남.
  double _resist(double raw) =>
      UnwindMotion.cordMaxDragPx * (1 - math.exp(-raw / 55.0));

  void _onDragStart(DragStartDetails d) {
    if (!widget.enabled) return;
    _spring.stop();
    _dragging = true;
    _rawDrag = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.enabled || !_dragging) return;
    _rawDrag = math.max(0.0, _rawDrag + d.delta.dy);
    final ext = _resist(_rawDrag);
    final past = ext >= UnwindMotion.cordThresholdPx;
    if (past && !_pastThreshold) {
      widget.haptics.medium(); // §6.4 임계점 통과
    }
    setState(() {
      _extension = ext;
      _pastThreshold = past;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.enabled || !_dragging) return;
    _dragging = false;
    final fired = _extension >= UnwindMotion.cordThresholdPx;
    // 스프링으로 튕겨 올라감 (§9.1 spring)
    _spring.animateWith(SpringSimulation(
      UnwindMotion.spring,
      _extension,
      0.0,
      fired ? -900 : -200, // 발동 시 더 세게 튕긴다
    ));
    _pastThreshold = false;
    if (fired) widget.onPull();
  }

  void _cancelDrag() {
    if (!_dragging) return;
    _dragging = false;
    _pastThreshold = false;
    _spring.animateWith(
        SpringSimulation(UnwindMotion.spring, _extension, 0.0, -200));
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final height = widget.restLength + UnwindMotion.cordMaxDragPx + 28;

    return Semantics(
      label: AppLocalizations.of(context).endDayLabel, // §12 — 제스처 없이도 실행 가능해야 함
      button: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? widget.onPull : null,
      child: GestureDetector(
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        onVerticalDragCancel: _cancelDrag,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.35,
          child: CustomPaint(
            size: Size(56, height),
            painter: _CordPainter(
              extension: _extension,
              restLength: widget.restLength,
              glowing: _pastThreshold,
              cordColor: colors.textMuted,
              handleColor: colors.lamp,
            ),
          ),
        ),
      ),
    );
  }
}

class _CordPainter extends CustomPainter {
  final double extension;
  final double restLength;
  final bool glowing;
  final Color cordColor;
  final Color handleColor;

  const _CordPainter({
    required this.extension,
    required this.restLength,
    required this.glowing,
    required this.cordColor,
    required this.handleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final endY = restLength + extension;

    // 줄 — 늘어날수록 아주 살짝 팽팽해지는 곡선
    final slack = math.max(0.0, 6.0 - extension * 0.1);
    final cord = Path()
      ..moveTo(x, 0)
      ..quadraticBezierTo(x + slack, endY * 0.55, x, endY);
    canvas.drawPath(
      cord,
      Paint()
        ..color = cordColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // 손잡이 (나무 구슬) — 임계점 통과 시 미세하게 밝아진다 (§6.4)
    final handleC = Offset(x, endY + 9);
    if (glowing) {
      final glowR = 22.0;
      canvas.drawCircle(
        handleC,
        glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            handleColor.withValues(alpha: 0.35),
            handleColor.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: handleC, radius: glowR)),
      );
    }
    canvas.drawCircle(
      handleC,
      7.5,
      Paint()..color = Color.lerp(cordColor, handleColor, glowing ? 0.65 : 0.25)!,
    );
  }

  @override
  bool shouldRepaint(_CordPainter old) =>
      old.extension != extension ||
      old.glowing != glowing ||
      old.cordColor != cordColor ||
      old.handleColor != handleColor;
}
