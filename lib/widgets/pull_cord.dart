import 'dart:async';
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

  /// tension 연속 햅틱 (개정 2026-08-07): 당길수록 틱 간격이 좁아진다.
  /// 팽팽함을 손끝의 "다다다다"로 표현 — 멈춰 있어도 tension만큼 계속 뛴다.
  Timer? _tensionTimer;

  static const _tensionMinExt = 8.0; // 이 이하로는 틱 없음
  static const _tensionSlowMs = 150; // 살짝 당김 — 느긋한 틱
  static const _tensionFastMs = 38; // 끝까지 당김 — 다다다다

  void _scheduleTension() {
    _tensionTimer?.cancel();
    if (!_dragging || _extension < _tensionMinExt) return;
    final f = ((_extension - _tensionMinExt) /
            (UnwindMotion.cordMaxDragPx - _tensionMinExt))
        .clamp(0.0, 1.0);
    final interval =
        (_tensionSlowMs + (_tensionFastMs - _tensionSlowMs) * f).round();
    _tensionTimer = Timer(Duration(milliseconds: interval), () {
      if (!mounted || !_dragging) return;
      widget.haptics.tensionTick();
      _scheduleTension(); // 현재 tension 기준으로 다음 틱 재예약
    });
  }

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
    _tensionTimer?.cancel();
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
    _scheduleTension();
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
    // 당기는 동안 tension이 커지면 다음 틱이 더 빨리 온다
    if (_tensionTimer == null || !_tensionTimer!.isActive) {
      _scheduleTension();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.enabled || !_dragging) return;
    _dragging = false;
    _tensionTimer?.cancel();
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
    _tensionTimer?.cancel();
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
        // deferToChild + painter.hitTest — 줄 아래의 빈 공간이 뒤에 있는
        // 체크리스트의 탭을 삼키지 않게 한다 (개정 2026-08-08)
        behavior: HitTestBehavior.deferToChild,
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

    // 손잡이 (나무 구슬) — 임계점 통과 시 미세하게 밝아진다 (§6.4).
    // 개정 2026-08-08: 밝아진 코너 글로우 위에서도 확실히 읽히도록
    // 크기를 키우고 잉크 아웃라인 + 상단 하이라이트를 넣는다.
    final handleC = Offset(x, endY + 11);
    const handleR = 10.0;
    if (glowing) {
      const glowR = 26.0;
      canvas.drawCircle(
        handleC,
        glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            handleColor.withValues(alpha: 0.45),
            handleColor.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: handleC, radius: glowR)),
      );
    }
    // 구슬 본체 — 위가 밝고 아래가 어두운 나무 결
    canvas.drawCircle(
      handleC,
      handleR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: glowing
              ? const [Color(0xFFFFE0A8), Color(0xFFD79B45)]
              : const [Color(0xFFE8D6B4), Color(0xFFB08E62)],
        ).createShader(
            Rect.fromCircle(center: handleC, radius: handleR)),
    );
    // 잉크 아웃라인 — 밝은 배경에서도 실루엣이 유지된다
    canvas.drawCircle(
      handleC,
      handleR,
      Paint()
        ..color = const Color(0xFF2A2233)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // 하이라이트 — 구형 볼륨감
    canvas.drawCircle(
      handleC.translate(-handleR * 0.32, -handleR * 0.36),
      handleR * 0.26,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55),
    );
  }

  /// 줄과 손잡이가 실제로 있는 곳만 터치를 받는다. 캔버스는 드래그 여유분
  /// 때문에 세로로 길지만, 그 빈 아래쪽까지 탭을 삼키면 뒤에 있는 체크리스트를
  /// 가린다 (개정 2026-08-08).
  @override
  bool hitTest(Offset position) {
    // 손잡이 아래로 최소 터치 타깃(44)의 절반만큼만 여유를 둔다
    final reach = restLength + extension + 11 + 22;
    return position.dy <= reach;
  }

  @override
  bool shouldRepaint(_CordPainter old) =>
      old.extension != extension ||
      old.glowing != glowing ||
      old.cordColor != cordColor ||
      old.handleColor != handleColor;
}
