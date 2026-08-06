import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/tokens/typography.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/settings/settings_controller.dart';
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
    final onboarded = ref.watch(settingsControllerProvider
        .select((s) => s.value?.onboardingCompleted));
    // 기본 영어 — 설정에서 변경 (지원 언어는 l10n/*.arb 추가로 확장)
    final languageCode = ref.watch(settingsControllerProvider
            .select((s) => s.value?.languageCode)) ??
        'en';
    return MaterialApp(
      title: 'Unwind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: UnwindType.fontFamily),
      locale: Locale(languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // §8.2 Dynamic Type: 최대 1.3배까지, 그 이상은 클램프
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = math.min(
            mq.textScaler.scale(16) / 16, UnwindType.maxTextScale);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      // M0 감각 프로토타입은 lib/features/today/m0_prototype_screen.dart에 유지
      // (실기기 감각 검증용 — §13 M0 승인 전까지 보존)
      home: onboarded == false
          ? const OnboardingFlow()
          : const TodayScreen(),
    );
  }
}
