import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../domain/models/lumi_state.dart';
import '../../widgets/lumi/lumi_view.dart';
import '../compose/compose_sheet.dart';
import '../settings/settings_controller.dart';
import '../today/m0_prototype_screen.dart';
import '../today/providers.dart';
import '../today/today_screen.dart';

/// §6.6 온보딩 — 계정 없음, 3화면 이내.
/// 1. 컨셉 설명 (Lumi가 눈부셔하는 그림)
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
        transitionDuration:
            const Duration(milliseconds: UnwindMotion.pageMs),
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
        return M0PrototypeScreen(
          itemTitles: const ['오늘 온 메일에 답장하기', '빌린 책 반납하기', '저녁 산책 20분'],
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

/// 1단계 — 컨셉 설명. Lumi가 눈부셔한다 (밝은 방 + 눈꺼풀 살짝).
class _ConceptPage extends StatelessWidget {
  final VoidCallback onNext;
  const _ConceptPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = lerpRamp(0.0); // 가장 밝은 정오 — 눈부신 방
    return UnwindTheme(
      colors: colors,
      child: DefaultTextStyle(
        style: UnwindType.body.copyWith(decoration: TextDecoration.none),
        child: ColoredBox(
          color: colors.bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(UnwindSpacing.s32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // 눈부셔하는 Lumi — 밝음(0.0)인데 눈꺼풀이 내려온 모습은
                  // brightness를 살짝 올린 상태로 표현 (찡그림 금지 §7.3)
                  const LumiView(
                      state: LumiState(brightness: 0.45)),
                  const Spacer(),
                  PrimaryText('Lumi는 자고 싶어요',
                      style: UnwindType.display, textAlign: TextAlign.center),
                  const SizedBox(height: UnwindSpacing.s16),
                  Text(
                    '할 일 하나가 등 하나예요.\n하나씩 끝내면 방이 조금씩 어두워져요.\n마지막 불이 꺼지면 Lumi가 잠들어요.',
                    textAlign: TextAlign.center,
                    style: UnwindType.body.copyWith(
                        color: colors.textSecondary,
                        decoration: TextDecoration.none),
                  ),
                  const Spacer(flex: 2),
                  GestureDetector(
                    onTap: onNext,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: UnwindSpacing.s12,
                          horizontal: UnwindSpacing.s32),
                      decoration: BoxDecoration(
                        color: colors.lamp.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(UnwindRadius.pill),
                        border: Border.all(color: colors.lamp),
                      ),
                      child: Text('불 끄러 가기', // 버튼은 동사로 (§8.5)
                          style: UnwindType.bodyStrong.copyWith(
                              color: colors.textPrimarySnap,
                              decoration: TextDecoration.none)),
                    ),
                  ),
                  const SizedBox(height: UnwindSpacing.s24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3단계 — 체험 후 전환.
class _TransitionPage extends StatelessWidget {
  final VoidCallback onStart;
  const _TransitionPage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final colors = lerpRamp(1.0); // 체험 직후 — 아직 밤의 여운
    return UnwindTheme(
      colors: colors,
      child: DefaultTextStyle(
        style: UnwindType.body.copyWith(decoration: TextDecoration.none),
        child: ColoredBox(
          color: colors.bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(UnwindSpacing.s32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const LumiView(
                      state: LumiState(brightness: 1.0, isAsleep: true)),
                  const Spacer(),
                  PrimaryText('이제 진짜 오늘의 할 일을 적어볼까요',
                      style: UnwindType.title, textAlign: TextAlign.center),
                  const Spacer(flex: 2),
                  GestureDetector(
                    onTap: onStart,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: UnwindSpacing.s12,
                          horizontal: UnwindSpacing.s32),
                      decoration: BoxDecoration(
                        color: colors.lamp.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(UnwindRadius.pill),
                        border: Border.all(color: colors.lamp),
                      ),
                      child: Text('적으러 가기',
                          style: UnwindType.bodyStrong.copyWith(
                              color: colors.textPrimarySnap,
                              decoration: TextDecoration.none)),
                    ),
                  ),
                  const SizedBox(height: UnwindSpacing.s24),
                ],
              ),
            ),
          ),
        ),
      ),
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
