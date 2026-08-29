import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/analytics.dart';
import 'core/haptics/haptics.dart';
import 'core/tokens/palette.dart';
import 'core/tokens/typography.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/settings/settings_controller.dart';
import 'features/today/providers.dart';
import 'features/today/today_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ToddAnalytics.init(); // §8.8 — 릴리즈 빌드에서만 켜진다. await 금지
  // 콜드 스타트만. main()은 프로세스가 죽은 뒤 켜질 때만 돈다 —
  // 백그라운드→포그라운드는 AppLifecycleState.resumed이지 main()이 아니다.
  ToddAnalytics.track('App Open');
  runApp(const ProviderScope(child: UnwindApp()));
}

class UnwindApp extends ConsumerWidget {
  const UnwindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // §6.6 온보딩 — 완료 전에는 온보딩으로 (로딩 중에는 빈 화면 대신 홈 유지)
    final onboarded = ref.watch(
      settingsControllerProvider.select((s) => s.value?.onboardingCompleted),
    );
    // 기본 영어 — 설정에서 변경 (지원 언어는 l10n/*.arb 추가로 확장)
    final languageCode =
        ref.watch(
          settingsControllerProvider.select((s) => s.value?.languageCode),
        ) ??
        'en';
    // 방 조명의 색 (선택형 2026-08-22) — 설정을 정적 팔레트에 흘린다.
    // setLightColor는 같은 값이면 no-op이라 빌드마다 불러도 안전하고,
    // 바뀌면 paletteEpoch가 올라 모든 UnwindScreen이 새로 인플레이트된다.
    // 앰버 외 색은 Todd Plus (수익화 2026-08-22) — 구독이 꺼지면 저장된
    // 색은 남긴 채 표시만 앰버로 돌아가고, 다시 구독하면 그 색이 되살아난다.
    final lightName = ref.watch(
      settingsControllerProvider.select((s) => s.value?.lightColor),
    );
    final premium = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.premiumEnabled ?? false,
      ),
    );
    UnwindColors.setLightColor(
      premium ? UnwindLightColor.fromName(lightName) : UnwindLightColor.amber,
    );
    // 설정과 연동된 햅틱 인스턴스를 트리 전체에 흘려보낸다 —
    // lib/ui/ 컴포넌트는 이 스코프에서 꺼내 쓴다 (Riverpod을 모른다).
    final haptics = ref.watch(hapticsProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      // 앱은 항상 다크다 (디자인 시스템 v2). Material 위젯(TextField·
      // 다이얼로그 등)이 밝은 기본값으로 새는 것을 여기서 막는다.
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: UnwindType.fontFamily,
        scaffoldBackgroundColor: UnwindColors.ink,
        canvasColor: UnwindColors.ink,
        splashColor: const Color(0x00000000),
        highlightColor: const Color(0x00000000),
        colorScheme: ColorScheme.dark(
          surface: UnwindColors.surface,
          primary: UnwindColors.accent,
          onPrimary: UnwindColors.onAccent,
          error: UnwindColors.danger,
        ),
      ),
      locale: Locale(languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // §8.2 Dynamic Type: 최대 1.3배까지, 그 이상은 클램프
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = math.min(
          mq.textScaler.scale(16) / 16,
          UnwindType.maxTextScale,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: UnwindHapticsScope(
            haptics: haptics,
            child: _WidgetSync(child: child!),
          ),
        );
      },
      // M0 감각 프로토타입은 lib/features/today/m0_prototype_screen.dart에 유지
      // (실기기 감각 검증용 — §13 M0 승인 전까지 보존)
      home: onboarded == false ? const OnboardingFlow() : const TodayScreen(),
    );
  }
}

/// 온보딩·홈 모두에서 위젯 스냅샷을 밀어 넣는다.
/// 홈으로 나갈 때도 한 번 더 써서, 빈 방 write가 이긴 위젯을 고친다.
class _WidgetSync extends ConsumerStatefulWidget {
  const _WidgetSync({required this.child});
  final Widget child;

  @override
  ConsumerState<_WidgetSync> createState() => _WidgetSyncState();
}

class _WidgetSyncState extends ConsumerState<_WidgetSync> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // 백그라운드 진입 직전 DB를 직접 읽어 **즉시** 쓴다 (2026-08-22).
    // invalidate는 캐시된 스트림 값으로 다시 쓰는 방식이라, 변이 직후
    // 바로 나가면 아직 안 따라온 옛 값을 쓸 수 있었다. 디바운스 중인
    // 스냅샷도 이 플러시가 확정한다 (suspend되면 타이머가 언다).
    //
    // resume 시엔 날짜 경계부터 재검사한다 (2026-08-27): 5시 롤오버
    // 타이머는 suspend로 얼고 기기 잠들기로 모노토닉 결손이 쌓여, 밤을
    // 넘긴 뒤 앱을 다시 열어도 안 터질 수 있다. 그러면 todayKey가 어제에
    // 고착돼 위젯이 "Good morning"에서 영영 안 벗어난다.
    // resume 때는 경계 재검사 후 **무조건** 스냅샷을 다시 쓰고 리로드한다
    // (2026-08-29): 롤오버가 이미 끝난 날의 조용한 resume은 어떤 프로바이더도
    // 안 바뀌어 write가 0번이었다 — 그 전에 나간 리로드가 WidgetKit에
    // 흘려졌다면(coalescing) 앱을 아무리 열어도 위젯이 "Good morning"에
    // 낡은 채 남았다. 앱 진입 = 위젯 최신화 보장이 이 플러시의 계약이다.
    _lifecycle = AppLifecycleListener(
      onResume: () async {
        try {
          await ref.read(todayKeyProvider.notifier).checkNow();
        } finally {
          if (mounted) {
            flushWidgetSnapshot(ref);
            _reportWidgetPresence();
          }
        }
      },
      onInactive: () => flushWidgetSnapshot(ref),
    );
    // 콜드 스타트에서도 한 번 — resume 콜백은 상태 전이 때만 온다
    _reportWidgetPresence();
  }

  /// 위젯 설치 여부 → Mixpanel has_widget (값이 바뀌었을 때만 전송).
  /// 위젯이 있으면 대기 중인 설치 넛지 푸시도 거둬 간다 — 예약 후 5분
  /// 안에 설치를 마친 유저에게 뒷북 안내를 보내지 않는다 (2026-08-27).
  Future<void> _reportWidgetPresence() async {
    final present = await ref
        .read(widgetSnapshotServiceProvider)
        .reportPresence();
    if (present == true) {
      await ref.read(notificationServiceProvider).cancelWidgetNudge();
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(widgetSyncProvider);
    return widget.child;
  }
}
