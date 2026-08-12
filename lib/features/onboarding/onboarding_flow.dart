import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/motion.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../domain/models/lumi_state.dart';
import '../../ui/ui.dart';
import '../../widgets/corner_glow.dart';
import '../../widgets/lumi/lumi_view.dart';
import '../compose/compose_sheet.dart';
import '../settings/settings_controller.dart';
import '../today/m0_prototype_screen.dart';
import '../today/providers.dart';
import '../today/today_screen.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.6 온보딩 — 계정 없음, 3화면 이내.
/// 1. 컨셉 설명 (빛이 가득한 방 + 눈부셔하는 Lumi)
/// 2. 샘플 3개가 놓인 방 — 직접 끄고 전등 줄까지 체험 (아하 모먼트)
/// 3. 체험 후: `이제 진짜 오늘의 할 일을 적어볼까요` + 입력 시트 자동 오픈
///
/// 샘플 방은 DB에 쓰지 않는 M0 프로토타입 화면을 재사용한다 —
/// 체험이 끝나면 샘플은 흔적 없이 사라진다.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  int _step = 0;

  Future<void> _finish() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setOnboardingCompleted();
    // §10 권한은 온보딩 종료 후에 요청한다 (첫 실행 즉시 요청 금지)
    await ref.read(notificationServiceProvider).requestPermission();

    if (!mounted) return;
    // 진짜 오늘의 방으로 + 입력 시트 자동 오픈 (§6.6)
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: UnwindMotion.pageMs),
        pageBuilder: (_, animation, secondary) => FadeTransition(
          opacity: animation,
          child: const TodayScreenWithComposeOpen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 0:
        return _ConceptPage(onNext: () => setState(() => _step = 1));
      case 1:
        // 샘플 방 체험 — 소등 시퀀스 완료 시 다음 단계로
        final l10n = AppLocalizations.of(context);
        return M0PrototypeScreen(
          itemTitles: [
            l10n.onboardSample1,
            l10n.onboardSample2,
            l10n.onboardSample3,
          ],
          showReset: false,
          onSequenceComplete: () {
            if (mounted) setState(() => _step = 2);
          },
        );
      default:
        return _TransitionPage(onStart: _finish);
    }
  }
}

/// 온보딩 페이지 공통 뼈대 — 빛의 양만 다르다.
class _OnboardPage extends StatelessWidget {
  final double light;
  final Widget lumi;
  final String title;
  final String? body;
  final String cta;
  final VoidCallback onTap;

  const _OnboardPage({
    required this.light,
    required this.lumi,
    required this.title,
    required this.cta,
    required this.onTap,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return UnwindScreen(
      safeArea: false,
      child: Stack(
        children: [
          Positioned.fill(child: CornerGlow(light: light)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(UnwindSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  Center(child: lumi),
                  const Spacer(),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: UnwindType.display.copyWith(
                      color: UnwindColors.textPrimary,
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: UnwindSpacing.s16),
                    Text(
                      body!,
                      textAlign: TextAlign.center,
                      style: UnwindType.body.copyWith(
                        color: UnwindColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                  UnwindButton(label: cta, onPressed: onTap),
                  const SizedBox(height: UnwindSpacing.s16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1단계 — 컨셉 설명. 방에 불이 가득하고 Lumi가 눈부셔한다.
class _ConceptPage extends StatelessWidget {
  final VoidCallback onNext;
  const _ConceptPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _OnboardPage(
      light: 1.0,
      lumi: const LumiView(state: LumiState(brightness: 0.45)),
      title: l10n.onboardTitle,
      body: l10n.onboardBody,
      cta: l10n.onboardGo, // 버튼은 동사로 (§8.5)
      onTap: onNext,
    );
  }
}

/// 3단계 — 체험 후 전환. 불은 다 꺼졌다.
class _TransitionPage extends StatelessWidget {
  final VoidCallback onStart;
  const _TransitionPage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _OnboardPage(
      light: 0.0,
      lumi: const LumiView(state: LumiState(brightness: 1.0, isAsleep: true)),
      title: l10n.onboardTransition,
      cta: l10n.onboardStart,
      onTap: onStart,
    );
  }
}

/// 온보딩 완료 후 오늘 화면 최초 진입 시 입력 시트 자동 오픈 (§6.6)
class TodayScreenWithComposeOpen extends StatefulWidget {
  const TodayScreenWithComposeOpen({super.key});

  @override
  State<TodayScreenWithComposeOpen> createState() =>
      _TodayScreenWithComposeOpenState();
}

class _TodayScreenWithComposeOpenState
    extends State<TodayScreenWithComposeOpen> {
  @override
  void initState() {
    super.initState();
    // 권한 다이얼로그(§10)가 닫힌 뒤 시트가 열리도록 한 박자 늦춘다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) showComposeSheet(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) => const TodayScreen();
}
