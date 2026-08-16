import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        colorScheme: const ColorScheme.dark(
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
    _lifecycle = AppLifecycleListener(
      onInactive: () => ref.invalidate(widgetSyncProvider),
    );
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
