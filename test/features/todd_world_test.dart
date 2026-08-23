import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/domain/models/todd_state.dart';
import 'package:unwind/features/onboarding/onboarding_flow.dart';
import 'package:unwind/features/settings/settings_controller.dart';
import 'package:unwind/features/today/providers.dart';

/// 세계관 (2026-08-15): Todd의 취침시간·기상시간과 다크서클.
/// - 취침시간(기본 22시) 전까지는 낮의 일과, 이후 불이 남아 있으면 못 잔다
/// - 전날 불을 남긴 채 넘어오면(restless) 다음날 다크서클이 남는다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UnwindDatabase db;

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer(DateTime clock) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWith((ref) => Stream.value(clock)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 오늘(논리적) 날짜에 시(hour)만 얹은 시각 — 롤오버 경계(기상 05시)와
  /// 무관하게 "오늘 밤"을 만들기 위해 실제 오늘 날짜를 쓴다.
  DateTime todayAt(int hour) {
    final today = logicalToday(DateTime.now());
    return DateTime(today.year, today.month, today.day, hour);
  }

  /// 모든 스트림(시계·할 일·설정)이 첫 값을 낼 때까지 listen 상태로 기다린 뒤
  /// 모드를 읽는다 — .future는 override된 Stream.value와 조합이 매끄럽지 않다.
  Future<ToddModeState> settledMode(ProviderContainer c) async {
    final sub = c.listen(toddModeProvider, (_, _) {});
    await c.read(settingsControllerProvider.future);
    await pumpEventQueue();
    final mode = c.read(toddModeProvider);
    sub.close();
    return mode;
  }

  Future<ToddModeState> modeWithPendingTodoAt(int hour) async {
    final c = makeContainer(todayAt(hour));
    final todayKey = c.read(todayKeyProvider);
    await c.read(todoRepositoryProvider).add(title: '남은 등', date: todayKey);
    return settledMode(c);
  }

  group('취침시간 경계 (기본 22시)', () {
    test('21시: 아직 낮의 일과 — 미완 항목이 있어도 행복하다', () async {
      final mode = await modeWithPendingTodoAt(21);
      expect(mode.mode, ToddMode.day);
    });

    test('22시: 취침시간인데 불이 남았다 — 못 자는 밤', () async {
      final mode = await modeWithPendingTodoAt(22);
      expect(mode.mode, ToddMode.nightAwake);
      expect(mode.dazzle, greaterThan(0));
    });

    test('22시의 빈 방 — 만족스러운 잠', () async {
      final c = makeContainer(todayAt(22));
      expect((await settledMode(c)).mode, ToddMode.asleep);
    });
  });

  group('온보딩 시간 매핑 (2026-08-15)', () {
    test('Todd는 3시간 먼저 자고 1시간 먼저 일어난다 — 자정 넘김 포함', () {
      expect(toddBedtimeFrom(23), 20);
      expect(toddBedtimeFrom(0), 21); // 자정 취침 → 21시
      expect(toddBedtimeFrom(2), 23);
      expect(toddWakeFrom(7), 6);
      expect(toddWakeFrom(4), 3);
      expect(toddWakeFrom(0), 23);
    });

    test('유저 시각이 없으면 Todd +1h 로 보여 준다', () {
      const s = UnwindSettings(wakeHour: 5, bedtimeHour: 22);
      expect(s.userWakeHour, isNull);
      expect(s.userBedtimeHour, isNull);
      expect(s.displayUserWakeHour, 6);
      expect(s.displayUserBedtimeHour, 23);
      const stored = UnwindSettings(
        wakeHour: 6,
        bedtimeHour: 20,
        userWakeHour: 7,
        userBedtimeHour: 23,
      );
      expect(stored.displayUserWakeHour, 7);
      expect(stored.displayUserBedtimeHour, 23);
    });
  });

  group('이름 easter egg', () {
    test('Todd/토드만 우연의 일치로 본다', () {
      expect(isToddCoincidenceName('Todd'), isTrue);
      expect(isToddCoincidenceName('todd'), isTrue);
      expect(isToddCoincidenceName('  Todd  '), isTrue);
      expect(isToddCoincidenceName('토드'), isTrue);
      expect(isToddCoincidenceName('Ryan'), isFalse);
      expect(isToddCoincidenceName('토드야'), isFalse);
    });
  });

  group('다크서클 (전날 불을 남긴 밤)', () {
    test('어제가 restless로 봉인됐으면 오늘 다크서클이 남는다', () async {
      final c = makeContainer(DateTime.now());
      final todayKey = c.read(todayKeyProvider);
      final yesterday = dayKey(addDays(parseDayKey(todayKey), -1));
      await db.dayDao.sealDay(yesterday, 0.5, restless: true);

      final sub = c.listen(darkCirclesProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(darkCirclesProvider), true);
      sub.close();
    });

    test('어제 잘 잤으면(또는 기록 없음) 다크서클이 없다', () async {
      final c = makeContainer(DateTime.now());
      final sub = c.listen(darkCirclesProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(darkCirclesProvider), false);
      sub.close();
    });
  });
}
