import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/haptics/haptics.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/settings/push_settings_screen.dart';
import 'package:unwind/features/settings/settings_controller.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';
import 'package:unwind/main.dart';
import 'package:unwind/ui/ui.dart';

/// M4 — 설정 영속성 · 온보딩 라우팅 · 접근성 라벨 (§12)
void main() {
  late UnwindDatabase db;

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  });

  Future<ProviderContainer> makeContainer(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return container;
  }

  group('설정 (§6.7)', () {
    testWidgets('기본값과 저장·복원', (tester) async {
      final c = await makeContainer(tester);
      var s = await c.read(settingsControllerProvider.future);
      expect(s.nightReminderEnabled, true);
      expect(s.billNotificationEnabled, true);
      expect(s.morningGreetingEnabled, true);
      expect(s.todoReminderEnabled, true);
      expect(s.soundEnabled, true);
      expect(s.hapticsEnabled, true);
      // 세계관 통합 (2026-08-15): 기상 05시 · 취침 22시
      expect(s.wakeHour, 5);
      expect(s.bedtimeHour, 22);
      expect(s.onboardingCompleted, false);

      final ctrl = c.read(settingsControllerProvider.notifier);
      await ctrl.setSoundEnabled(false);
      await ctrl.setWakeHour(4);
      await ctrl.setBedtimeHour(23);

      // DB에 실제 영속화됐는지 확인
      expect(await db.settingsDao.getValue('soundEnabled'), 'false');
      expect(await db.settingsDao.getValue('wakeHour'), '4');
      expect(await db.settingsDao.getValue('bedtimeHour'), '23');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('데이터 초기화 — 모든 데이터 삭제, 설정은 유지', (tester) async {
      final c = await makeContainer(tester);
      await c
          .read(todoRepositoryProvider)
          .add(title: '지울 일', date: '2026-08-06');
      await db.settingsDao.setValue('soundEnabled', 'false');

      await c.read(settingsControllerProvider.notifier).resetAllData();

      expect(await db.todoDao.getByDate('2026-08-06'), isEmpty);
      expect(await db.settingsDao.getValue('soundEnabled'), 'false'); // 유지

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('설정 > 푸시에서 네 가지 알림을 끄고 켠다', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: UnwindHapticsScope(
            haptics: UnwindHaptics(enabled: false),
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PushSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Morning hello'), findsOneWidget);
      expect(find.text('Unwind reminder'), findsOneWidget);
      expect(find.text('Timed tasks'), findsOneWidget);
      expect(find.text('Bill arrival'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Morning hello'));
      await tester.pump();
      expect(await db.settingsDao.getValue('morningGreetingEnabled'), 'false');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('온보딩 (§6.6, 전면 개편 2026-08-15)', () {
    /// "다음" 버튼 활성 여부 — 라벨로 UnwindButton을 찾아 onPressed를 본다
    bool ctaEnabled(WidgetTester tester, String label) =>
        tester
            .widget<UnwindButton>(find.widgetWithText(UnwindButton, label))
            .onPressed !=
        null;

    testWidgets('첫 실행: 환영 1초 잠금 → 밤 → 소등 체험은 전부 꺼야 통과', (tester) async {
      // 커진 Todd(200) 아래 타일 3개가 다 보이도록 실기기 크기로
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const UnwindApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 1. 환영 — CTA는 1초 뒤에야 열린다
      expect(find.text('Hey! I\'m Todd.'), findsOneWidget);
      expect(ctaEnabled(tester, 'Next'), false);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(ctaEnabled(tester, 'Next'), true);
      await tester.tap(find.text('Next'));
      // 누름 상태 setState가 첫 프레임을 먹는다 (§10 검증 루틴)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      // 2. 눈부신 밤 + 소등 체험 (병합 2026-08-15 2차) —
      //    반드시 전부 꺼야 다음으로 (발주자 요구)
      expect(find.text('I need to sleep but..'), findsOneWidget);
      expect(find.byType(UnwindTodoTile), findsNWidgets(3));
      expect(ctaEnabled(tester, 'Next'), false);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(UnwindLampSwitch).at(i));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text("That's perfect!"), findsOneWidget);
      expect(
        find.text('I can finally get some\ngood sleep tonight. Thanks!'),
        findsOneWidget,
      );
      expect(
        find.text('The light is too bright to sleep in.\nFlip a switch to turn it off!'),
        findsNothing,
      );
      expect(ctaEnabled(tester, 'Next'), true);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('온보딩 완료 상태면 홈으로 바로 진입', (tester) async {
      await db.settingsDao.setValue('onboardingCompleted', 'true');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const UnwindApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Hey! I\'m Todd.'), findsNothing);
      expect(find.text('Today'), findsWidgets); // 홈

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('접근성 (§12)', () {
    testWidgets('VoiceOver 라벨: 전등 줄·FAB·등 상태', (tester) async {
      await db.settingsDao.setValue('onboardingCompleted', 'true');
      await db.todoDao.insertTodo(title: '접근성 확인', date: _todayKey());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const UnwindApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel('End the day'), findsOneWidget); // 전등 줄
      expect(find.bySemanticsLabel('Add a task'), findsOneWidget); // FAB
      // 등 상태 라벨 (켜짐/꺼짐) — 개정: 스위치가 상태를 보고
      final semantics = tester.getSemantics(find.byType(UnwindLampSwitch));
      expect(semantics.value, 'On');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}

String _todayKey() {
  final now = DateTime.now().subtract(const Duration(hours: 6));
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
