import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/repositories/todo_repository.dart';
import 'package:unwind/domain/services/day_rollover_service.dart';

/// §5.2 단조 감소 규칙의 DB 영속화(§14 수용 기준) + 롤오버 봉인 검증.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late UnwindDatabase db;
  late TodoRepository repo;
  const d = '2026-08-06';

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    repo = TodoRepository(db);
  });

  tearDown(() => db.close());

  Future<double> peak() async =>
      (await db.dayDao.getDay(d))?.peakProgress ?? 0.0;

  test('수용 기준: 3개 중 1개 완료 후 4개를 추가해도 peak가 유지된다', () async {
    final todos = [
      for (var i = 0; i < 3; i++)
        await repo.add(title: '할 일 $i', date: d),
    ];
    await repo.setDone(todos[0], true);
    expect(await peak(), closeTo(1 / 3, 1e-9));

    for (var i = 0; i < 4; i++) {
      await repo.add(title: '추가 $i', date: d);
    }
    expect(await peak(), closeTo(1 / 3, 1e-9)); // raw는 1/7이지만 유지
  });

  test('수용 기준: 완료 취소 시 peak가 정확히 되돌아간다', () async {
    final todos = [
      for (var i = 0; i < 3; i++)
        await repo.add(title: '할 일 $i', date: d),
    ];
    await repo.setDone(todos[0], true);
    await repo.setDone(todos[1], true);
    expect(await peak(), closeTo(2 / 3, 1e-9));

    await repo.setDone(todos[1], false);
    expect(await peak(), closeTo(1 / 3, 1e-9));
  });

  test('삭제 시 peak = max(peak, raw)', () async {
    final todos = [
      for (var i = 0; i < 4; i++)
        await repo.add(title: '할 일 $i', date: d),
    ];
    await repo.setDone(todos[0], true); // peak = 1/4
    await repo.remove(todos[1]); // 미완료 삭제 → raw = 1/3
    expect(await peak(), closeTo(1 / 3, 1e-9));
  });

  test('깨우기(개정 2026-08-07): 취침 기록 삭제 + §5.2 규칙으로 재계산', () async {
    final todos = [
      for (var i = 0; i < 2; i++) await repo.add(title: '할 일 \$i', date: d),
    ];
    await repo.setDone(todos[0], true); // peak = 1/2
    await repo.pullCord(d, DateTime(2026, 8, 6, 22, 0));
    expect((await db.dayDao.getDay(d))!.lightsOutAt, isNotNull);

    await repo.wake(d);
    final day = (await db.dayDao.getDay(d))!;
    expect(day.lightsOutAt, isNull); // 취침 기록 삭제
    expect(day.finalT, isNull);
    expect(day.peakProgress, closeTo(0.5, 1e-9)); // raw로 재계산

    // 깨운 뒤 완료 취소하면 §5.2대로 더 내려간다
    await repo.setDone(todos[0], false);
    expect((await db.dayDao.getDay(d))!.peakProgress, 0.0);
  });

  test('수용 기준: 전등 줄 후 추가해도 lightsOutAt/peak=1.0 유지', () async {
    await repo.add(title: '할 일', date: d);
    await repo.pullCord(d, DateTime(2026, 8, 6, 23, 30));
    await repo.add(title: '내일 몫', date: d);

    final day = await db.dayDao.getDay(d);
    expect(day!.lightsOutAt, isNotNull);
    expect(day.peakProgress, 1.0);
    expect(day.finalT, 1.0);
  });

  group('롤오버 봉인 (§4.3 finalT)', () {
    test('전날 항목이 있으면 peak로 봉인', () async {
      final t = await repo.add(title: '지난 일', date: '2026-08-05');
      await repo.setDone(t, true); // peak = 1.0
      final service = DayRolloverService(
          db: db, onRollover: (_) {}, now: DateTime(2026, 8, 6, 12));
      await service.sealPastDays(DateTime(2026, 8, 6, 12));
      service.dispose();

      expect((await db.dayDao.getDay('2026-08-05'))!.finalT, 1.0);
    });

    test('전날 항목이 없으면(빈 방) 0.15로 봉인하지 않는다 — 후보에 없음', () async {
      final service = DayRolloverService(
          db: db, onRollover: (_) {}, now: DateTime(2026, 8, 6, 12));
      await service.sealPastDays(DateTime(2026, 8, 6, 12));
      service.dispose();
      expect(await db.dayDao.getDay('2026-08-05'), isNull);
    });

    test('이미 finalT가 있으면 덮어쓰지 않는다', () async {
      await repo.add(title: '지난 일', date: '2026-08-05');
      await repo.pullCord('2026-08-05', DateTime(2026, 8, 5, 22));
      final service = DayRolloverService(
          db: db, onRollover: (_) {}, now: DateTime(2026, 8, 6, 12));
      await service.sealPastDays(DateTime(2026, 8, 6, 12));
      service.dispose();
      expect((await db.dayDao.getDay('2026-08-05'))!.finalT, 1.0);
    });
  });
}
