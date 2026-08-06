import 'package:flutter/widgets.dart';

import '../core/theme/unwind_theme.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';

/// §6.1 등 하나 = 할 일 하나. §9.2 개별 체크 인터랙션.
///
/// - 텍스트 영역 어디를 눌러도 토글 (등 아이콘만이 아님)
/// - 완료해도 리스트에서 사라지지 않는다 — 꺼진 등 + 흐려진 텍스트로 제자리
/// - 잔광은 생략 불가: 필라멘트가 식듯이. 형광등처럼 딱 꺼지면 안 된다.
class LampRow extends StatefulWidget {
  final String title;
  final bool isOn;
  final VoidCallback? onTap;

  /// 롱프레스 → 편집/삭제 메뉴 (§6.1)
  final VoidCallback? onLongPress;

  /// §5.5 호흡 — 켜진 등의 glow만 미세하게 오르내린다. null이면 정지.
  final Animation<double>? breath;

  const LampRow({
    super.key,
    required this.title,
    required this.isOn,
    this.onTap,
    this.onLongPress,
    this.breath,
  });

  @override
  State<LampRow> createState() => _LampRowState();
}

class _LampRowState extends State<LampRow> with TickerProviderStateMixin {
  /// 소등 진행: 0 = 켜짐, 1 = 완전히 꺼짐 (잔광까지 종료)
  late final AnimationController _off;

  /// 아이콘 눌림 (scale 1.0 → 0.94 → 1.0, 140ms)
  late final AnimationController _press;

  // §9.2 타임라인(총 260ms) 안에서의 구간
  static const _totalMs = UnwindMotion.afterglowDelayMs + UnwindMotion.afterglowMs; // 260
  late final Animation<double> _coreOff; // 필라멘트 감쇠 (0~220ms, switchOff)
  late final Animation<double> _glowOff; // 잔광 (60~260ms)

  @override
  void initState() {
    super.initState();
    _off = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
      value: widget.isOn ? 0.0 : 1.0,
    );
    _coreOff = CurvedAnimation(
      parent: _off,
      curve: Interval(0.0, UnwindMotion.lampOffMs / _totalMs,
          curve: UnwindMotion.switchOff),
    );
    _glowOff = CurvedAnimation(
      parent: _off,
      curve: Interval(UnwindMotion.afterglowDelayMs / _totalMs, 1.0,
          curve: Curves.easeOut),
    );
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.iconPressMs),
    );
  }

  @override
  void didUpdateWidget(LampRow old) {
    super.didUpdateWidget(old);
    if (old.isOn != widget.isOn) {
      if (widget.isOn) {
        _off.reverse();
      } else {
        _off.forward();
      }
    }
  }

  @override
  void dispose() {
    _off.dispose();
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    _press.forward(from: 0); // §9.2 눌림
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);

    return Semantics(
      label: widget.title,
      value: widget.isOn ? '켜짐' : '꺼짐', // §12 VoiceOver 상태 라벨
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: UnwindTouch.minTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s8),
            child: Row(
              children: [
                // 등 아이콘 — 체크 인터랙션만은 확실한 물성 (§8.4 예외)
                AnimatedBuilder(
                  animation: _press,
                  builder: (context, child) {
                    // 1.0 → 0.94 → 1.0
                    final p = _press.value;
                    final scale = 1.0 -
                        (UnwindMotion.iconPressScale > 0
                            ? (1.0 - UnwindMotion.iconPressScale) *
                                (p < 0.5 ? p * 2 : (1 - p) * 2)
                            : 0.0);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: SizedBox(
                    width: UnwindTouch.minTarget,
                    height: UnwindTouch.minTarget,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_off, if (widget.breath != null) widget.breath!]),
                      builder: (context, _) => CustomPaint(
                        painter: _LampIconPainter(
                          core: 1 - _coreOff.value,
                          glow: 1 - _glowOff.value,
                          breath: widget.breath?.value ?? 0.0,
                          lampColor: colors.lamp,
                          offColor: colors.border,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: UnwindSpacing.s12),
                // 제목 — 완료 시 흐려짐 (opacity 1.0 → 0.4, 180ms)
                Expanded(
                  child: AnimatedOpacity(
                    duration:
                        const Duration(milliseconds: UnwindMotion.textFadeMs),
                    opacity: widget.isOn
                        ? 1.0
                        : UnwindMotion.textFadedOpacity,
                    child: PrimaryText(widget.title, style: UnwindType.body),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 등 아이콘: 켜짐 = 채워진 전구 + RadialGradient 발광(블러 금지, §11).
/// core: 필라멘트 밝기 0~1, glow: 잔광 0~1 (core보다 늦게 사라짐 = 잔광).
class _LampIconPainter extends CustomPainter {
  final double core;
  final double glow;
  final double breath;
  final Color lampColor;
  final Color offColor;

  const _LampIconPainter({
    required this.core,
    required this.glow,
    required this.breath,
    required this.lampColor,
    required this.offColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.16;

    // 잔광 (등 주변 발광) — 호흡이 여기 실린다
    if (glow > 0.01) {
      final glowR = size.width * (0.44 + breath * 2.5);
      canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            lampColor.withValues(alpha: 0.45 * glow),
            lampColor.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: glowR)),
      );
    }

    if (core > 0.01) {
      // 켜진 필라멘트 — 식어가는 색 (밝음 → offColor로 감쇠)
      final coreColor = Color.lerp(offColor, lampColor, core)!;
      canvas.drawCircle(c, r, Paint()..color = coreColor);
      // 중심 하이라이트
      canvas.drawCircle(
        c.translate(-r * 0.25, -r * 0.25),
        r * 0.35,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * core),
      );
    } else {
      // 꺼진 등 — 테두리만 남은 원
      canvas.drawCircle(
        c,
        r * 0.92,
        Paint()
          ..color = offColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(_LampIconPainter old) =>
      old.core != core ||
      old.glow != glow ||
      old.breath != breath ||
      old.lampColor != lampColor ||
      old.offColor != offColor;
}
