import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/haptics/haptics.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/typography.dart';
import '../../domain/models/todd_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/ui.dart';
import '../../widgets/corner_glow.dart';
import '../../widgets/todd/todd_view.dart';
import '../settings/settings_controller.dart';
import '../../domain/models/widget_background.dart';
import '../settings/widget_background_preview.dart';
import '../today/providers.dart';
import 'premium_providers.dart';

/// Todd Plus 페이월 (수익화 2026-08-22, 발주자 지시).
///
/// 감정 설계 — 레퍼런스: Duolingo(마스코트가 페이월의 주인공, 반응하는
/// 캐릭터가 텍스트보다 강하다)·Finch(코스메틱 프레이밍 + "펫을 위해"라는
/// 명분, 신뢰 요소로 전환).
/// - 기능 나열이 아니라 **Todd가 직접 묻는다** — "우리, 조금 더 가까워질까?"
/// - 히어로 Todd는 살아 있다: 들어오면 까르르, 결제하면 축하(점프+별).
/// - 기능 목록은 지금 실재하는 둘만 정직하게, 마지막 줄은
///   "…and many more to come!"으로 기대를 심는다 (발주자 요구).
/// - 신뢰 요소: 언제든 해지 캡션, 닫기 버튼은 즉시 노출 (다크패턴 금지 —
///   릴랙스 앱의 예의).
Future<void> showPaywall(BuildContext context, {required String from}) {
  ToddAnalytics.track('View paywall', {'from': from});
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PaywallScreen(),
    ),
  );
}

enum _Plan { monthly, yearly, lifetime }

String _planAnalyticsName(_Plan plan) => switch (plan) {
  _Plan.monthly => 'monthly',
  _Plan.yearly => 'annual',
  _Plan.lifetime => 'lifetime',
};

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// 연간이 기본 선택 — 앵커이자 추천 (BEST 배지)
  _Plan _plan = _Plan.yearly;

  ToddEvent? _event;
  int _tick = 0;
  bool _celebrating = false;
  Timer? _helloTimer;
  Timer? _doneTimer;

  /// 조명 색 체험 (개정 2026-08-22 2차) — 스와치를 누르면 **페이월 자체가
  /// 그 색으로 물든다** (CTA·글로우·카드 전부). 페이월이 곧 데모다.
  UnwindLightColor? _preview;

  /// 체험 시작 시점의 원래(자격 있는) 색 — 구독 없이 닫으면 되돌린다
  UnwindLightColor? _entitled;

  @override
  void initState() {
    super.initState();
    // 들어오고 한 박자 뒤 스스로 까르르 — 파는 사람이 아니라 반가운 친구
    _helloTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_celebrating) {
        setState(() {
          _event = ToddEvent.poke;
          _tick++;
        });
      }
    });
  }

  @override
  void dispose() {
    _helloTimer?.cancel();
    _doneTimer?.cancel();
    // 맛만 보고 닫았다 — 원래 색으로. 구독했다면 settings가 이미
    // 체험하던 색을 확정했으므로 되돌리지 않는다.
    // ⚠️ 다음 프레임으로 미룬다: dispose는 라우트 해체 중(트리 잠금)에
    // 불려서, 여기서 바로 epoch를 올리면 뒤 화면들이 markNeedsBuild에
    // 실패해 체험 색이 얼룩덜룩 남는다.
    if (!_celebrating && _entitled != null) {
      final entitled = _entitled!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UnwindColors.setLightColor(entitled);
      });
    }
    super.dispose();
  }

  void _tryColor(UnwindLightColor c) {
    _entitled ??= UnwindColors.lightColor;
    setState(() => _preview = c);
    UnwindColors.setLightColor(c);
  }

  /// TODO(unwind): StoreKit 결제 연동 — 지금은 바로 Plus를 켠다 (테스트용).
  /// 구매 성공의 감정 연출(축하 → 닫힘)은 그대로 재사용한다.
  Future<void> _subscribe() async {
    if (_celebrating) return;
    _celebrating = true;
    ref.read(hapticsProvider).success();
    setState(() {
      _event = ToddEvent.react; // 체크 축하 — 점프 + 별 버스트
      _tick++;
    });
    final ctrl = ref.read(settingsControllerProvider.notifier);
    await ctrl.setPremiumEnabled(true);
    ToddAnalytics.track('Click confirm-subscription', {
      'plan': _planAnalyticsName(_plan),
    });
    // 체험하던 색이 있으면 그대로 내 색이 된다 — "이 색으로 살래"의 순간
    if (_preview != null) await ctrl.setLightColor(_preview!.name);
    // 축하가 눈에 담긴 뒤에 닫는다 — 고마움이 마지막 인상이 되게
    _doneTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final premium = ref.watch(premiumProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return UnwindScreen(
      safeArea: false,
      child: Stack(
        children: [
          // 방의 온기 — 페이월도 이 앱의 방이다
          const Positioned.fill(
            child: IgnorePointer(child: CornerGlow(light: 0.45)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 닫기 — 즉시, 잘 보이게 (다크패턴 금지)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: UnwindSpacing.s4,
                      right: UnwindSpacing.s8,
                    ),
                    child: UnwindIconButton(
                      icon: Icons.close_rounded,
                      semanticLabel: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    // 색 체험마다 화면이 재인플레이트된다 — 스크롤을 지킨다
                    key: const PageStorageKey('paywall-list'),
                    padding: const EdgeInsets.fromLTRB(
                      UnwindSpacing.s20,
                      0,
                      UnwindSpacing.s20,
                      UnwindSpacing.s16,
                    ),
                    children: [
                      Center(
                        child: ToddView(
                          state: ToddState(
                            brightness: 0.1,
                            mode: ToddMode.day,
                            event: _event,
                            eventTick: _tick,
                          ),
                          reduceMotion: reduce,
                          size: 150,
                        ),
                      ),
                      const SizedBox(height: UnwindSpacing.s8),
                      Text(
                        _celebrating || premium
                            ? l10n.plusHeroThanks
                            : l10n.plusHeroTitle,
                        textAlign: TextAlign.center,
                        style: UnwindType.display.copyWith(
                          color: UnwindColors.textPrimary,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: UnwindSpacing.s4),
                      Center(
                        child: Text(
                          l10n.plusTitle,
                          style: UnwindType.label.copyWith(
                            color: UnwindColors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: UnwindSpacing.s16),
                      UnwindCard(
                        child: Column(
                          children: [
                            _FeatureRow(
                              emoji: '🌈',
                              title: l10n.plusFeatureColors,
                              caption: l10n.plusFeatureColorsCaption,
                            ),
                            const SizedBox(height: UnwindSpacing.s8),
                            // 직접 체험 (발주자 요구): 누르는 순간 페이월이
                            // 통째로 그 색이 된다
                            _TryColorsRow(
                              selected: _preview ?? UnwindColors.lightColor,
                              onTap: _tryColor,
                            ),
                            const SizedBox(height: UnwindSpacing.s12),
                            _FeatureRow(
                              emoji: '♾️',
                              title: l10n.plusFeatureRecurrence,
                              caption: l10n.plusFeatureRecurrenceCaption,
                            ),
                            const SizedBox(height: UnwindSpacing.s12),
                            // 위젯 배경 8종 (2026-08-28) — 행을 누르면
                            // 캐러셀 시트로 하나씩 구경한다. 페이월에서
                            // 사는 물건을 직접 보여준다 (조명 색 체험과
                            // 같은 원칙).
                            UnwindPressable(
                              onTap: () => _showWidgetBgPeek(context),
                              haptic: UnwindHapticKind.tap,
                              depth: 0,
                              pressScale: 0.98,
                              semanticLabel: l10n.plusFeatureWidgetBg,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _FeatureRow(
                                      emoji: '🌙',
                                      title: l10n.plusFeatureWidgetBg,
                                      caption: l10n.plusFeatureWidgetBgCaption,
                                    ),
                                  ),
                                  Text(
                                    '›',
                                    style: UnwindType.title.copyWith(
                                      color: UnwindColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: UnwindSpacing.s12),
                            // 기대를 심는 마지막 줄 (발주자 요구) — 로드맵은
                            // 약속하지 않되 계속 자란다는 신호만
                            Row(
                              children: [
                                const _FeatureEmoji(emoji: '✨'),
                                const SizedBox(width: UnwindSpacing.s12),
                                Expanded(
                                  child: Text(
                                    l10n.plusFeatureMore,
                                    style: UnwindType.bodyStrong.copyWith(
                                      color: UnwindColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: UnwindSpacing.s16),
                      if (!premium) ...[
                        _PlanCard(
                          label: l10n.plusYearly,
                          price: l10n.plusYearlyPrice,
                          caption: l10n.plusYearlyCaption,
                          badge: l10n.plusBest,
                          selected: _plan == _Plan.yearly,
                          onTap: () => setState(() => _plan = _Plan.yearly),
                        ),
                        const SizedBox(height: UnwindSpacing.s8),
                        _PlanCard(
                          label: l10n.plusMonthly,
                          price: l10n.plusMonthlyPrice,
                          caption: l10n.plusMonthlyCaption,
                          selected: _plan == _Plan.monthly,
                          onTap: () => setState(() => _plan = _Plan.monthly),
                        ),
                        const SizedBox(height: UnwindSpacing.s8),
                        _PlanCard(
                          label: l10n.plusLifetime,
                          price: l10n.plusLifetimePrice,
                          caption: l10n.plusLifetimeCaption,
                          selected: _plan == _Plan.lifetime,
                          onTap: () => setState(() => _plan = _Plan.lifetime),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UnwindSpacing.s20,
                    UnwindSpacing.s8,
                    UnwindSpacing.s20,
                    UnwindSpacing.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!premium) ...[
                        UnwindButton(
                          label: l10n.plusCta,
                          onPressed: _celebrating ? null : _subscribe,
                        ),
                        const SizedBox(height: UnwindSpacing.s8),
                        Center(
                          child: Text(
                            l10n.plusCancelNote,
                            style: UnwindType.caption.copyWith(
                              color: UnwindColors.textMuted,
                            ),
                          ),
                        ),
                      ] else
                        // TODO(unwind): 배포 빌드에서 제거 — 테스트용 해제
                        UnwindButton.ghost(
                          label: 'Plus 해제 (dev)',
                          onPressed: () async {
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .setPremiumEnabled(false);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureEmoji extends StatelessWidget {
  final String emoji;

  const _FeatureEmoji({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: UnwindColors.surfaceHigh,
          borderRadius: BorderRadius.circular(UnwindRadius.sm),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String caption;

  const _FeatureRow({
    required this.emoji,
    required this.title,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FeatureEmoji(emoji: emoji),
        const SizedBox(width: UnwindSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: UnwindType.bodyStrong.copyWith(
                  color: UnwindColors.textPrimary,
                ),
              ),
              const SizedBox(height: UnwindSpacing.s2),
              Text(
                caption,
                style: UnwindType.caption.copyWith(
                  color: UnwindColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 요금제 카드 — 선택형. 연간에 BEST 배지.
/// TODO(unwind): 가격은 StoreKit 상품 정보로 대체 (지금은 표시용 문자열).
class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String caption;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.caption,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return UnwindPressable(
      onTap: onTap,
      depth: 0,
      haptic: UnwindHapticKind.selection,
      semanticLabel: '$label $price',
      isToggled: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? UnwindColors.accentSoft : UnwindColors.surface,
          borderRadius: BorderRadius.circular(UnwindRadius.md),
          border: Border.all(
            color: selected ? UnwindColors.accent : UnwindColors.border,
            width: UnwindStroke.base,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnwindSpacing.s16,
            vertical: UnwindSpacing.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: UnwindType.bodyStrong.copyWith(
                            color: UnwindColors.textPrimary,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: UnwindSpacing.s8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: UnwindColors.accent,
                              borderRadius: BorderRadius.circular(
                                UnwindRadius.pill,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UnwindSpacing.s8,
                                vertical: 2,
                              ),
                              child: Text(
                                badge!,
                                style: UnwindType.caption.copyWith(
                                  color: UnwindColors.onAccent,
                                  fontVariations: const [
                                    FontVariation('wght', 800),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: UnwindSpacing.s2),
                    Text(
                      caption,
                      style: UnwindType.caption.copyWith(
                        color: UnwindColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: UnwindType.headline.copyWith(
                  color: selected
                      ? UnwindColors.accent
                      : UnwindColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// 조명 색 체험 스와치 (개정 2026-08-22 2차) — 자물쇠 없이 전부 눌러 볼 수
/// 있다. 맛보기가 없으면 욕망도 없다: 누르는 순간 페이월 전체(CTA·글로우·
/// 카드)가 그 색으로 물들고, 구독 없이 닫으면 원래 색으로 돌아간다.
class _TryColorsRow extends StatelessWidget {
  final UnwindLightColor selected;
  final ValueChanged<UnwindLightColor> onTap;

  const _TryColorsRow({required this.selected, required this.onTap});

  String _label(AppLocalizations l10n, UnwindLightColor c) => switch (c) {
    UnwindLightColor.amber => l10n.lightAmber,
    UnwindLightColor.sunset => l10n.lightSunset,
    UnwindLightColor.rose => l10n.lightRose,
    UnwindLightColor.lavender => l10n.lightLavender,
    UnwindLightColor.sky => l10n.lightSky,
    UnwindLightColor.mint => l10n.lightMint,
    UnwindLightColor.moon => l10n.lightMoon,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final c in UnwindLightColor.values)
          UnwindPressable(
            onTap: () => onTap(c),
            depth: 0,
            pressScale: 0.85,
            haptic: UnwindHapticKind.selection,
            semanticLabel: _label(l10n, c),
            isToggled: c == selected,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == selected
                          ? UnwindColors.textPrimary
                          : const Color(0x00000000),
                      width: UnwindStroke.base,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c.seed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


/// 위젯 배경 미리보기 캐러셀 (2026-08-28, 발주자 지시) — 페이월의
/// "위젯 배경 8종" 행에서 연다. 깊은 밤(무료)은 빼고 Plus 8종만 —
/// 여기서 보여주는 것이 곧 사는 물건이다.
Future<void> _showWidgetBgPeek(BuildContext context) {
  return showUnwindSheet(
    context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return UnwindSheet(
        title: l10n.widgetBackgroundTitle,
        child: const _WidgetBgCarousel(),
      );
    },
  );
}

class _WidgetBgCarousel extends StatefulWidget {
  const _WidgetBgCarousel();

  @override
  State<_WidgetBgCarousel> createState() => _WidgetBgCarouselState();
}

class _WidgetBgCarouselState extends State<_WidgetBgCarousel> {
  // 무료 기본(깊은 밤)은 캐러셀에서 뺀다 — Plus로 열리는 8종만
  static final _bgs = [
    for (final b in WidgetBackground.values)
      if (b != WidgetBackground.deepNight) b,
  ];

  final _controller = PageController(viewportFraction: 0.62);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: UnwindSpacing.s8),
        SizedBox(
          height: 232,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) {
              setState(() => _page = i);
              UnwindHapticsScope.of(context).selection();
            },
            itemCount: _bgs.length,
            itemBuilder: (context, i) => Center(
              child: AnimatedScale(
                scale: i == _page ? 1.0 : 0.88,
                duration: const Duration(
                  milliseconds: UnwindMotion.textFadeMs,
                ),
                child: SizedBox(
                  width: 216,
                  height: 216,
                  child: WidgetBackgroundPreviewCard(
                    bg: _bgs[i],
                    accent: UnwindColors.accent,
                    borderRadius: UnwindRadius.xl,
                    toddSize: 88,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: UnwindSpacing.s12),
        Text(
          widgetBackgroundLabel(l10n, _bgs[_page]),
          style: UnwindType.headline.copyWith(color: UnwindColors.textPrimary),
        ),
        const SizedBox(height: UnwindSpacing.s8),
        // 페이지 점 — 지금 몇 번째 밤인지
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _bgs.length; i++)
              Container(
                width: i == _page ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _page
                      ? UnwindColors.accent
                      : UnwindColors.borderStrong,
                ),
              ),
          ],
        ),
        const SizedBox(height: UnwindSpacing.s8),
      ],
    );
  }
}
