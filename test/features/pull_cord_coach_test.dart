import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/settings/settings_controller.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/features/today/pull_cord_coach.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UnwindDatabase db;

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await pumpEventQueue();
    await db.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      await pumpEventQueue();
      container.dispose();
    });
    return container;
  }

  test('온보딩 완료가 코치마크 대기를 켠다', () async {
    final c = makeContainer();
    await c.read(settingsControllerProvider.future);
    await c.read(settingsControllerProvider.notifier).setOnboardingCompleted();
    final s = await c.read(settingsControllerProvider.future);
    expect(s.pullCordCoachAwaiting, isTrue);
    expect(s.pullCordCoachShown, isFalse);
  });

  test('오늘 새 할 일이 2개가 되면 한 번만 켠다', () async {
    final c = makeContainer();
    await c.read(settingsControllerProvider.future);
    await c.read(settingsControllerProvider.notifier).setOnboardingCompleted();

    final today = c.read(todayKeyProvider);
    final repo = c.read(todoRepositoryProvider);
    final coach = c.read(pullCordCoachVisibleProvider.notifier);

    await repo.add(title: '하나', date: today);
    await coach.onNewTodoAdded(today);
    expect(c.read(pullCordCoachVisibleProvider), isFalse);

    await repo.add(title: '둘', date: today);
    await coach.onNewTodoAdded(today);
    expect(c.read(pullCordCoachVisibleProvider), isTrue);

    await coach.dismiss();
    expect(c.read(pullCordCoachVisibleProvider), isFalse);
    final s = await c.read(settingsControllerProvider.future);
    expect(s.pullCordCoachShown, isTrue);
    expect(s.pullCordCoachAwaiting, isFalse);

    await repo.add(title: '셋', date: today);
    await coach.onNewTodoAdded(today);
    expect(c.read(pullCordCoachVisibleProvider), isFalse);
    await pumpEventQueue();
  });

  test('다른 날짜에 넣으면 켜지지 않는다', () async {
    final c = makeContainer();
    await c.read(settingsControllerProvider.future);
    await c.read(settingsControllerProvider.notifier).setOnboardingCompleted();

    final repo = c.read(todoRepositoryProvider);
    await repo.add(title: '하나', date: '2020-01-01');
    await repo.add(title: '둘', date: '2020-01-01');
    await c
        .read(pullCordCoachVisibleProvider.notifier)
        .onNewTodoAdded('2020-01-01');
    expect(c.read(pullCordCoachVisibleProvider), isFalse);
    await pumpEventQueue();
  });
}
