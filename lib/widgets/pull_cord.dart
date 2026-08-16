import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/haptics/haptics.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/palette.dart';
import '../l10n/generated/app_localizations.dart';

/// §6.4 전등 줄 — 하루를 닫는 마무리 액션. 이 앱의 클라이맥스.
///
/// - 당기는 중: 0~72px, 저항 곡선(뒤로 갈수록 무거워짐)
/// - 임계점 56px 통과: mediumImpact + 손잡이가 미세하게 밝아짐
/// - 임계 이상 놓음: 튕겨 올라가고 소등 시퀀스 시작
/// - 임계 미만 놓음: 튕겼다가 흔들리며 잦아든다. 아무 일도 없지만 기분은 좋다
/// - 비활성(할 일 0개 / 이미 당김): 흐리게, 당겨지지 않음
///
/// **놓았을 때의 물리 (개편 2026-08-12)**: 두 축을 각각 damped spring으로
/// 적분한다 (`flutter/physics`의 [SpringSimulation]).
///   - 세로: 원위치를 **지나쳐** 위로 튀었다가 통통 되돌아온다.
///     (이전에는 오버슈트를 `max(0, …)`로 잘라내 튕김이 보이지 않았다)
///   - 가로: 느린 진자. 줄이 슬랙해지며 옆으로 부푸는 걸 흉내낸다 —
///     구슬이 가장 많이, 줄 중간은 그 절반쯤 흔들려 자연스러운 호를 그린다.
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

  /// 손잡이(구슬) 중심의 전역 좌표 — 코치마크가 가리킬 때 쓴다.
  static Offset? handleCenterOf(GlobalKey key, {double restLength = 148}) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset(box.size.width / 2, restLength + 11));
  }

  @override
  State<PullCord> createState() => _PullCordState();
}

class _PullCordState extends State<PullCord> with TickerProviderStateMixin {
  /// 세로 되튐 (unbounded — 음수면 원위치 위로 튄 것)
  late final AnimationController _recoil;

  /// 가로 흔들림 (unbounded — 0 주위로 진동하는 진자)
  late final AnimationController _sway;

  double _rawDrag = 0.0; // 손가락 누적 이동
  double _extension = 0.0; // 화면에 보이는 늘어남 (저항 적용)
  double _swayX = 0.0; // 구슬의 좌우 변위
  bool _pastThreshold = false;
  bool _dragging = false;

  /// 되튐이 원위치를 처음 지나칠 때 한 번만 울리는 "탁" (아래 참고)
  bool _snapPending = false;

  /// tension 연속 햅틱 (개정 2026-08-07): 당길수록 틱 간격이 좁아진다.
  /// 팽팽함을 손끝의 "다다다다"로 표현 — 멈춰 있어도 tension만큼 계속 뛴다.
  Timer? _tensionTimer;

  static const _tensionMinExt = 8.0; // 이 이하로는 틱 없음
  static const _tensionSlowMs = 150; // 살짝 당김 — 느긋한 틱
  static const _tensionFastMs = 38; // 끝까지 당김 — 다다다다

  void _scheduleTension() {
    _tensionTimer?.cancel();
    if (!_dragging || _extension < _tensionMinExt) return;
    final f =
        ((_extension - _tensionMinExt) /
                (UnwindMotion.cordMaxDragPx - _tensionMinExt))
            .clamp(0.0, 1.0);
    final interval = (_tensionSlowMs + (_tensionFastMs - _tensionSlowMs) * f)
        .round();
    _tensionTimer = Timer(Duration(milliseconds: interval), () {
      if (!mounted || !_dragging) return;
      widget.haptics.tensionTick();
      _scheduleTension(); // 현재 tension 기준으로 다음 틱 재예약
    });
  }

  @override
  void initState() {
    super.initState();
    _recoil = AnimationController.unbounded(vsync: this, value: 0.0)
      ..addListener(_onRecoilTick);
    _sway = AnimationController.unbounded(vsync: this, value: 0.0)
      ..addListener(() => setState(() => _swayX = _sway.value));
  }

  void _onRecoilTick() {
    // 원위치 위로는 조금만 — 헤더를 침범하지 않는다
    final v = _recoil.value.clamp(-UnwindMotion.cordRecoilLimitPx, 1e4);
    // 줄이 팽팽해지며 원위치를 처음 지나치는 순간의 "탁"
    if (_snapPending && v <= 0) {
      _snapPending = false;
      widget.haptics.tensionTick();
    }
    setState(() => _extension = v);
  }

  @override
  void dispose() {
    _tensionTimer?.cancel();
    _recoil.dispose();
    _sway.dispose();
    super.dispose();
  }

  /// 저항 곡선: 뒤로 갈수록 무거워짐. raw → 표시 늘어남.
  double _resist(double raw) =>
      UnwindMotion.cordMaxDragPx * (1 - math.exp(-raw / 55.0));

  void _onDragStart(DragStartDetails d) {
    if (!widget.enabled) return;
    _recoil.stop();
    _sway.stop();
    _snapPending = false;
    _dragging = true;
    _rawDrag = math.max(0.0, _extension); // 흔들리는 중에 다시 잡아도 이어진다
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
    final fired = _extension >= UnwindMotion.cordThresholdPx;
    _release(fired: fired, flingVelocity: d.primaryVelocity ?? 0);
    if (fired) widget.onPull();
  }

  void _cancelDrag() {
    if (!_dragging) return;
    _release(fired: false, flingVelocity: 0);
  }

  /// 손을 뗐다 — 두 축을 각각 스프링에 넘긴다.
  void _release({required bool fired, required double flingVelocity}) {
    _dragging = false;
    _tensionTimer?.cancel();
    _pastThreshold = false;

    // 당긴 만큼이 되튐과 흔들림의 에너지가 된다 (0~1)
    final energy = (_extension / UnwindMotion.cordMaxDragPx).clamp(0.0, 1.0);

    // 세로 — 원위치를 지나쳐 튀어 올랐다가 통통 잦아든다.
    // 손가락이 위로 튕겨 놓았다면(음수 속도) 그 힘도 얹는다.
    final up = -(360 + 620 * energy) + math.min(0.0, flingVelocity) * 0.35;
    _snapPending = _extension > 4;
    _recoil.animateWith(
      SpringSimulation(UnwindMotion.cordRecoil, _extension, 0.0, up),
    );

    // 가로 — 줄이 슬랙해지며 옆으로 부푸는 진자. 오른쪽으로 늘어져 있던
    // 줄이라 왼쪽으로 먼저 부푼다.
    _sway.animateWith(
      SpringSimulation(
        UnwindMotion.cordSway,
        _swayX,
        0.0,
        -UnwindMotion.cordSwayKick * energy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.restLength + UnwindMotion.cordMaxDragPx + 28;

    return Semantics(
      label: AppLocalizations.of(
        context,
      ).endDayLabel, // §12 — 제스처 없이도 실행 가능해야 함
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
            painter: CordPainter(
              extension: _extension,
              sway: _swayX,
              restLength: widget.restLength,
              glowing: _pastThreshold,
              cordColor: UnwindColors.textMuted,
              handleColor: UnwindColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// 공개 이유: 놓았을 때의 물리(되튐·흔들림)를 위젯 테스트에서 검증한다.
/// (`test/features/pull_cord_test.dart`)
@visibleForTesting
class CordPainter extends CustomPainter {
  final double extension;

  /// 구슬의 좌우 변위 (진자). 줄 중간은 이보다 덜 흔들린다.
  final double sway;
  final double restLength;
  final bool glowing;
  final Color cordColor;
  final Color handleColor;

  const CordPainter({
    required this.extension,
    required this.sway,
    required this.restLength,
    required this.glowing,
    required this.cordColor,
    required this.handleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final endY = restLength + extension;

    // 줄 — 위는 천장에 고정, 아래로 갈수록 크게 흔들리는 진자 호.
    // 중간점을 구슬 변위의 60%에 두면 자연스러운 활 모양이 된다.
    // 늘어나 팽팽해질수록 원래의 처짐(slack)은 사라진다.
    final slack = math.max(0.0, 6.0 - extension * 0.1);
    final endX = x + sway;
    final midX = x + sway * 0.6 + slack;
    final cord = Path()
      ..moveTo(x, 0)
      ..quadraticBezierTo(midX, endY * 0.55, endX, endY);
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
    // 구슬은 줄 끝의 접선 방향으로 매달린다 — 흔들릴수록 바깥으로 실린다
    final tangent = (endX - midX) * 0.10;
    final handleC = Offset(endX + tangent, endY + 11);
    const handleR = 10.0;
    if (glowing) {
      const glowR = 26.0;
      canvas.drawCircle(
        handleC,
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              handleColor.withValues(alpha: 0.45),
              handleColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: handleC, radius: glowR)),
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
        ).createShader(Rect.fromCircle(center: handleC, radius: handleR)),
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
  bool shouldRepaint(CordPainter old) =>
      old.extension != extension ||
      old.sway != sway ||
      old.glowing != glowing ||
      old.cordColor != cordColor ||
      old.handleColor != handleColor;
}
