import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/unwind_theme.dart';
import '../core/tokens/color_ramp.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import '../l10n/generated/app_localizations.dart';

/// §6.1 등 하나 = 할 일 하나 — 형광등 패널 (개정 2026-08-07).
///
/// 사실적 디테일:
/// - 켜진 패널 = 면광원: 중심이 가장 밝은 코어 + 이중 발광(타이트한 광원
///   블룸 + 넓은 은은한 번짐)
/// - **방이 어두워질수록 켜진 형광등이 상대적으로 더 눈부시다** — 발광
///   강도가 전역 조도(t)에 비례해 커진다
/// - 켤 때 형광등 점화 플리커(스타터 깜빡임) 후 안정
/// - 끌 때는 §9.2 유지: 감쇠 220ms + 잔광 60+200ms (개정 기록대로 보존)
/// - 우측에 진짜 벽 스위치(로커) — 위를 누르면 켜지고 아래를 누르면 꺼진다
/// - 패널 탭 = 편집, 롱프레스 = 메뉴
class LampRow extends StatefulWidget {
  final String title;
  final bool isOn;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// §5.5 호흡 — 켜진 등의 발광만 미세하게 오르내린다. null이면 정지.
  final Animation<double>? breath;

  const LampRow({
    super.key,
    required this.title,
    required this.isOn,
    this.onToggle,
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

  /// 스위치 눌림 (딸깍 물성, 140ms)
  late final AnimationController _press;

  /// 형광등 점화 플리커 (켜질 때만, 380ms)
  late final AnimationController _ignite;
  late final Animation<double> _igniteAnim;

  static const _totalMs =
      UnwindMotion.afterglowDelayMs + UnwindMotion.afterglowMs; // 260
  late final Animation<double> _coreOff;
  late final Animation<double> _glowOff;

  // 형광등 팔레트 — 웜 화이트
  static const _coreCenter = Color(0xFFFFFFF8); // 튜브 코어 (가장 밝음)
  static const _coreEdge = Color(0xFFFFF3DC); // 패널 가장자리
  static const _glowColor = Color(0xFFFFE3AC); // 발광 번짐
  static const _panelEdgeOn = Color(0xFFE4CFA5); // 아랫면 두께 (빛의 일부)
  static const _textOn = Color(0xFF4A3A26);

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

    // 점화 플리커: 확 켜짐 → 살짝 죽음 → 켜짐 → 반쯤 → 안정 (스타터 느낌)
    _ignite = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _igniteAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.30), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 0.30, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.65), weight: 16),
      TweenSequenceItem(
          tween: Tween(begin: 0.65, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
    ]).animate(_ignite);
    if (widget.isOn) _ignite.value = 1.0;
  }

  @override
  void didUpdateWidget(LampRow old) {
    super.didUpdateWidget(old);
    if (old.isOn != widget.isOn) {
      if (widget.isOn) {
        _off.reverse();
        _ignite.forward(from: 0); // 형광등 점화
      } else {
        _off.forward();
      }
    }
  }

  @override
  void dispose() {
    _off.dispose();
    _press.dispose();
    _ignite.dispose();
    super.dispose();
  }

  void _handleToggle() {
    if (widget.onToggle == null) return;
    _press.forward(from: 0);
    widget.onToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final l10n = AppLocalizations.of(context);
    // 어두운 방일수록 켜진 형광등이 눈부시다 — 전역 조도 t에 비례한 발광 증폭
    final darkBoost = 0.55 + 1.25 * colors.t;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s8 - 2),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          label: widget.title,
          button: true,
          child: AnimatedBuilder(
            animation: Listenable.merge(
                [_off, _ignite, if (widget.breath != null) widget.breath!]),
            builder: (context, child) {
              final ignite = widget.isOn ? _igniteAnim.value : 1.0;
              final lit = (1 - _coreOff.value) * ignite; // 튜브 밝기
              final glow = (1 - _glowOff.value) * ignite; // 발광 (잔광 담당)
              final breath = widget.breath?.value ?? 0.0;

              final edgeColor = Color.lerp(
                  colors.border.withValues(alpha: 0.4), _panelEdgeOn, lit)!;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 발광 2겹 — 넓고 은은한 번짐 (바깥)
                  if (glow > 0.01)
                    Positioned.fill(
                      top: -22,
                      bottom: -22,
                      left: -18,
                      right: -18,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(UnwindRadius.lg + 8),
                            gradient: RadialGradient(
                              radius: 1.15,
                              colors: [
                                _glowColor.withValues(
                                    alpha: (0.22 + breath * 1.6) *
                                        glow *
                                        darkBoost),
                                _glowColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 발광 2겹 — 타이트한 광원 블룸 (패널에 붙은 눈부심)
                  if (glow > 0.01)
                    Positioned.fill(
                      top: -7,
                      bottom: -7,
                      left: -5,
                      right: -5,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(UnwindRadius.lg),
                            gradient: RadialGradient(
                              radius: 0.95,
                              colors: [
                                const Color(0xFFFFF6DE).withValues(
                                    alpha: (0.34 + breath * 1.2) *
                                        glow *
                                        darkBoost),
                                const Color(0xFFFFF6DE)
                                    .withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 패널 본체 — 면광원: 중심이 가장 밝은 코어 그라디언트.
                  // 아랫면 두께는 빛의 일부라 꺼지면 함께 사라진다 (§8.4)
                  Container(
                    decoration: BoxDecoration(
                      color: Color.lerp(colors.surface, _coreEdge, lit),
                      gradient: lit > 0.03
                          ? RadialGradient(
                              radius: 1.35,
                              colors: [
                                Color.lerp(colors.surface, _coreCenter,
                                    lit)!,
                                Color.lerp(
                                    colors.surface, _coreEdge, lit)!,
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(UnwindRadius.md),
                      border: Border(
                        left: BorderSide(color: edgeColor, width: 0.8),
                        top: BorderSide(color: edgeColor, width: 0.8),
                        right: BorderSide(color: edgeColor, width: 0.8),
                        bottom: BorderSide(
                            color: edgeColor, width: 0.8 + 2.4 * lit),
                      ),
                      boxShadow: lit > 0.05
                          ? [
                              BoxShadow(
                                color: colors.shadow
                                    .withValues(alpha: colors.shadow.a * lit),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: UnwindTouch.minTarget + 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: UnwindSpacing.s16,
                            vertical: UnwindSpacing.s8),
                        child: Row(
                          children: [
                            Expanded(
                              child: lit > 0.5
                                  ? Text(
                                      widget.title,
                                      style: UnwindType.body.copyWith(
                                          color: Color.lerp(
                                              colors.textMuted, _textOn,
                                              (lit - 0.5) * 2),
                                          decoration: TextDecoration.none),
                                    )
                                  : Opacity(
                                      opacity: UnwindMotion.textFadedOpacity +
                                          (1 - UnwindMotion.textFadedOpacity) *
                                              lit *
                                              2,
                                      child: PrimaryText(widget.title,
                                          style: UnwindType.body),
                                    ),
                            ),
                            const SizedBox(width: UnwindSpacing.s12),
                            LampSwitch(
                              isOn: widget.isOn,
                              lit: lit,
                              press: _press,
                              colors: colors,
                              enabled: widget.onToggle != null,
                              onTap: _handleToggle,
                              semanticsOn: l10n.lampOn,
                              semanticsOff: l10n.lampOff,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 진짜 벽 전등 스위치 (로커) — §8.4 예외: 여기만 확실한 물성.
/// 위쪽이 눌리면 ON, 아래쪽이 눌리면 OFF. 플레이트 + 3D 기울어지는 로커 +
/// ON일 때 켜지는 호박색 인디케이터.
class LampSwitch extends StatelessWidget {
  final bool isOn;
  final double lit;
  final Animation<double> press;
  final UnwindColors colors;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticsOn;
  final String semanticsOff;

  const LampSwitch({
    super.key,
    required this.isOn,
    required this.lit,
    required this.press,
    required this.colors,
    required this.enabled,
    required this.onTap,
    required this.semanticsOn,
    required this.semanticsOff,
  });

  static const _plate = Color(0xFFF3EDDE);
  static const _plateEdge = Color(0xFFD9CDB2);
  static const _rockerHi = Color(0xFFFCF8EE);
  static const _rockerLo = Color(0xFFE2D8C2);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsOn,
      value: isOn ? semanticsOn : semanticsOff,
      toggled: isOn,
      button: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: UnwindTouch.minTarget,
          height: UnwindTouch.minTarget,
          child: Center(
            child: AnimatedBuilder(
              animation: press,
              builder: (context, _) {
                final p = press.value;
                final squash = 1.0 - 0.08 * (p < 0.5 ? p * 2 : (1 - p) * 2);
                return Transform.scale(
                  scale: squash,
                  // 벽 플레이트
                  child: Container(
                    width: 30,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _plate,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _plateEdge, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22403010),
                          blurRadius: 3,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Center(
                      // 로커 — 3D 기울기: ON = 위가 눌려 들어감
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: isOn ? 1.0 : -1.0),
                        duration: const Duration(
                            milliseconds: UnwindMotion.iconPressMs),
                        curve: Curves.easeOutBack,
                        builder: (context, tilt, _) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.006)
                              ..rotateX(tilt * 0.42),
                            child: Container(
                              width: 18,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3.5),
                                border: Border.all(
                                    color: _plateEdge, width: 0.8),
                                // 눌린 면이 어두워지는 셰이딩 — ON은 위가 눌림
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: tilt >= 0
                                      ? [_rockerLo, _rockerHi]
                                      : [_rockerHi, _rockerLo],
                                ),
                              ),
                              // ON 인디케이터 — 로커 아래쪽 호박색 불빛
                              child: Align(
                                alignment: const Alignment(0, 0.62),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  width: 7,
                                  height: 3.4,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(2),
                                    color: isOn
                                        ? Color.lerp(
                                            const Color(0xFFB9A88A),
                                            const Color(0xFFFFB84D),
                                            math.max(lit, 0.3))
                                        : const Color(0xFFB9A88A)
                                            .withValues(alpha: 0.5),
                                    boxShadow: isOn && lit > 0.2
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFFB84D)
                                                  .withValues(
                                                      alpha: 0.55 * lit),
                                              blurRadius: 4,
                                              spreadRadius: 0.5,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
