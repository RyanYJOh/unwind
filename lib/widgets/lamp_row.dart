import 'package:flutter/widgets.dart';

import '../core/theme/unwind_theme.dart';
import '../core/tokens/color_ramp.dart';
import '../core/tokens/motion.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import '../l10n/generated/app_localizations.dart';

/// §6.1 등 하나 = 할 일 하나 — 형광등 패널 (개정 2026-08-07).
///
/// - 켜진 아이템 = 웜 화이트로 발광하는 패널. 입체감의 출처는 빛(§8.4):
///   발광·부드러운 그림자·옅은 아랫면 두께가 꺼지면 빛과 함께 사라진다.
/// - 우측 스위치로 on/off (스위치만 단단한 물성 — §8.4 예외)
/// - 패널 탭 = 편집, 롱프레스 = 메뉴 (개정: 기존 탭=토글에서 변경)
/// - 소등 시 §9.2 유지: 필라멘트 감쇠 220ms + 잔광 60+200ms (생략 불가)
class LampRow extends StatefulWidget {
  final String title;
  final bool isOn;

  /// 우측 스위치 — on/off 토글
  final VoidCallback? onToggle;

  /// 패널 탭 — 편집 (개정 2026-08-07)
  final VoidCallback? onTap;

  /// 롱프레스 — 메뉴 (§6.1)
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

  static const _totalMs =
      UnwindMotion.afterglowDelayMs + UnwindMotion.afterglowMs; // 260
  late final Animation<double> _coreOff; // 필라멘트 감쇠 (0~220ms, switchOff)
  late final Animation<double> _glowOff; // 잔광 (60~260ms)

  // 형광등 패널 팔레트 — 웜 화이트 (①-c 절충: 차가운 흰색 아님)
  static const _panelOn = Color(0xFFFFFCF1);
  static const _panelGlow = Color(0xFFFFE9BE);
  static const _panelEdgeOn = Color(0xFFE8D5B0); // 아랫면 두께 (빛의 일부)
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

  void _handleToggle() {
    if (widget.onToggle == null) return;
    _press.forward(from: 0); // 스위치 딸깍 (§8.4 물성)
    widget.onToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final l10n = AppLocalizations.of(context);

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
                [_off, if (widget.breath != null) widget.breath!]),
            builder: (context, child) {
              final lit = 1 - _coreOff.value; // 필라멘트 밝기
              final glow = 1 - _glowOff.value; // 잔광 (더 늦게 사라짐)
              final breath = widget.breath?.value ?? 0.0;

              // 패널: 켜짐 = 웜 화이트 발광, 꺼짐 = 테마 표면으로 가라앉음
              final panelColor =
                  Color.lerp(colors.surface, _panelOn, lit)!;
              final edgeColor = Color.lerp(
                  colors.border.withValues(alpha: 0.4), _panelEdgeOn, lit)!;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 발광 — 패널 주변 웜 글로우 (잔광 담당, RadialGradient §11)
                  if (glow > 0.01)
                    Positioned.fill(
                      top: -14,
                      bottom: -14,
                      left: -10,
                      right: -10,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(UnwindRadius.lg),
                            gradient: RadialGradient(
                              radius: 1.1,
                              colors: [
                                _panelGlow.withValues(
                                    alpha: (0.38 + breath * 2.2) * glow),
                                _panelGlow.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 패널 본체 — 빛 기반 입체감: 아랫면 두께가 빛과 함께 사라진다
                  Container(
                    decoration: BoxDecoration(
                      color: panelColor,
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
                            // 제목 — 켜짐: 밝은 패널 위 고정 다크브라운
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
                            // 우측 스위치 (§8.4 예외 — 단단한 물성)
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

/// 아이템 우측 on/off 스위치 — 여기만 확실한 물성 (§8.4 예외)
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
        // 터치 타깃 44 확보 (§8.3)
        child: SizedBox(
          width: UnwindTouch.minTarget,
          height: UnwindTouch.minTarget,
          child: Center(
            child: AnimatedBuilder(
              animation: press,
              builder: (context, _) {
                final p = press.value;
                final squash =
                    1.0 - 0.10 * (p < 0.5 ? p * 2 : (1 - p) * 2);
                return Transform.scale(
                  scale: squash,
                  child: AnimatedContainer(
                    duration: const Duration(
                        milliseconds: UnwindMotion.iconPressMs),
                    curve: Curves.easeOut,
                    width: 38,
                    height: 22,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: isOn
                          ? Color.lerp(
                              colors.border, colors.lamp, lit)
                          : colors.border.withValues(alpha: 0.8),
                      borderRadius:
                          BorderRadius.circular(UnwindRadius.pill),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(
                          milliseconds: UnwindMotion.iconPressMs),
                      curve: Curves.easeOutBack,
                      alignment: isOn
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFFFFF),
                        ),
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
