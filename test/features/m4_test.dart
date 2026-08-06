import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/settings/settings_controller.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/main.dart';
import 'package:unwind/widgets/lamp_row.dart';

/// M4 — 설정 영속성 · 온보딩 라우팅 · 접근성 라벨 (§12)
void main() {
  late UnwindDatabase db;

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  });

  Future<ProviderContainer> makeContainer(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return const SizedBox();
      }),
    ));
    return container;
  }

  group('설정 (§6.7)', () {
    testWidgets('기본값과 저장·복원', (tester) async {
      final c = await makeContainer(tester);
      var s = await c.read(settingsControllerProvider.future);
      expect(s.nightReminderEnabled, true);
      expect(s.nightReminderTime, '22:00');
      expect(s.soundEnabled, true);
      expect(s.hapticsEnabled, true);
      expect(s.dayStartHour, 6);
      expect(s.onboardingCompleted, false);

      final ctrl = c.read(settingsControllerProvider.notifier);
      await ctrl.setNightReminderTime('23:30');
      await ctrl.setSoundEnabled(false);
      await ctrl.setDayStartHour(4);

      // DB에 실제 영속화됐는지 확인
      expect(await db.settingsDao.getValue('nightReminderTime'), '23:30');
      expect(await db.settingsDao.getValue('soundEnabled'), 'false');
      expect(await db.settingsDao.getValue('dayStartHour'), '4');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('데이터 초기화 — 모든 데이터 삭제, 설정은 유지', (tester) async {
      final c = await makeContainer(tester);
      await c.read(todoRepositoryProvider).add(title: '지울 일', date: '2026-08-06');
      await db.settingsDao.setValue('soundEnabled', 'false');

      await c.read(settingsControllerProvider.notifier).resetAllData();

      expect(await db.todoDao.getByDate('2026-08-06'), isEmpty);
      expect(await db.settingsDao.getValue('soundEnabled'), 'false'); // 유지

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('온보딩 (§6.6)', () {
    testWidgets('첫 실행 → 컨셉 화면 → 샘플 방 3개', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const UnwindApp(),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // 1단계: 컨셉 (크로스페이드 2겹)
      expect(find.text('Lumi는 자고 싶어요'), findsNWidgets(2));

      await tester.tap(find.text('불 끄러 가기'));
      await tester.pump(const Duration(milliseconds: 100));

      // 2단계: 샘플 3개가 놓인 방 (아하 모먼트)
      expect(find.byType(LampRow), findsNWidgets(3));
      expect(find.text('빌린 책 반납하기'), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('온보딩 완료 상태면 홈으로 바로 진입', (tester) async {
      await db.settingsDao.setValue('onboardingCompleted', 'true');
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const UnwindApp(),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Lumi는 자고 싶어요'), findsNothing);
      expect(find.text('오늘'), findsWidgets); // 홈

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('접근성 (§12)', () {
    testWidgets('VoiceOver 라벨: 전등 줄·FAB·등 상태', (tester) async {
      await db.settingsDao.setValue('onboardingCompleted', 'true');
      await db.todoDao.insertTodo(title: '접근성 확인', date: _todayKey());

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const UnwindApp(),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel('하루 마치기'), findsOneWidget); // 전등 줄
      expect(find.bySemanticsLabel('할 일 추가'), findsOneWidget); // FAB
      // 등 상태 라벨 (켜짐/꺼짐)
      final semantics = tester.getSemantics(find.byType(LampRow));
      expect(semantics.value, '켜짐');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}

String _todayKey() {
  final now = DateTime.now().subtract(const Duration(hours: 6));
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
