import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/data/repositories/todo_repository.dart';
import 'package:unwind/domain/services/day_rollover_service.dart';
import 'package:unwind/domain/services/recurrence_expander.dart';

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

  test('v1→v2 마이그레이션은 기존 Todo를 보존하고 새 필드 기본값을 채운다', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE todos (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        memo TEXT,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        recurrence_id TEXT,
        deferred_from TEXT
      )
    ''');
    raw.execute('''
      CREATE TABLE recurrences (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        memo TEXT,
        rule TEXT NOT NULL,
        weekday_mask INTEGER,
        day_of_month INTEGER,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER NOT NULL
      )
    ''');
    raw.execute(
      "INSERT INTO todos VALUES "
      "('legacy', '기존 할 일', NULL, '$d', 'pending', 0, 0, NULL, NULL, NULL)",
    );
    raw.execute('PRAGMA user_version = 1');

    final migrated = UnwindDatabase.withExecutor(NativeDatabase.opened(raw));
    final todo = (await migrated.todoDao.getByDate(d)).single;

    expect(todo.id, 'legacy');
    expect(todo.autoDefer, false);
    expect(todo.scheduledTimeMinutes, isNull);
    await migrated.close();
  });

  Future<double> peak() async =>
      (await db.dayDao.getDay(d))?.peakProgress ?? 0.0;

  test('수용 기준: 3개 중 1개 완료 후 4개를 추가해도 peak가 유지된다', () async {
    final todos = [
      for (var i = 0; i < 3; i++) await repo.add(title: '할 일 $i', date: d),
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
      for (var i = 0; i < 3; i++) await repo.add(title: '할 일 $i', date: d),
    ];
    await repo.setDone(todos[0], true);
    await repo.setDone(todos[1], true);
    expect(await peak(), closeTo(2 / 3, 1e-9));

    await repo.setDone(todos[1], false);
    expect(await peak(), closeTo(1 / 3, 1e-9));
  });

  test('삭제 시 peak = max(peak, raw)', () async {
    final todos = [
      for (var i = 0; i < 4; i++) await repo.add(title: '할 일 $i', date: d),
    ];
    await repo.setDone(todos[0], true); // peak = 1/4
    await repo.remove(todos[1]); // 미완료 삭제 → raw = 1/3
    expect(await peak(), closeTo(1 / 3, 1e-9));
  });

  test('수정 시 날짜를 바꾸면 대상 날짜의 마지막 순서로 이동한다', () async {
    final todo = await repo.add(title: '옮길 일', date: d);
    await repo.add(title: '기존 내일 일', date: '2026-08-07');

    await repo.edit(todo, title: '옮겨진 일', memo: '메모', date: '2026-08-07');

    expect(await db.todoDao.getByDate(d), isEmpty);
    final moved = await db.todoDao.getByDate('2026-08-07');
    expect(moved.map((t) => t.title), ['기존 내일 일', '옮겨진 일']);
    expect(moved.last.memo, '메모');
  });

  test('시간 있는 항목을 먼저, 이른 시간과 sortIndex 순으로 조회한다', () async {
    await repo.add(title: '시간 없음 1', date: d);
    await repo.add(title: '오후', date: d, scheduledTimeMinutes: 18 * 60);
    await repo.add(title: '아침 1', date: d, scheduledTimeMinutes: 8 * 60);
    await repo.add(title: '아침 2', date: d, scheduledTimeMinutes: 8 * 60);
    await repo.add(title: '시간 없음 2', date: d);

    final rows = await db.todoDao.watchByDate(d).first;
    expect(rows.map((todo) => todo.title), [
      '아침 1',
      '아침 2',
      '오후',
      '시간 없음 1',
      '시간 없음 2',
    ]);
  });

  test('봉인 후 여러 과거 날짜의 미완료 자동 미루기 원본만 오늘로 이동한다', () async {
    final move1 = await repo.add(
      title: '그제 미완료',
      date: '2026-08-04',
      autoDefer: true,
    );
    await repo.add(title: '어제 미완료', date: '2026-08-05', autoDefer: true);
    final done = await repo.add(
      title: '완료됨',
      date: '2026-08-05',
      autoDefer: true,
    );
    await repo.setDone(done, true);
    await repo.add(title: '미루지 않음', date: '2026-08-05');

    final service = DayRolloverService(
      db: db,
      onRollover: (_) {},
      now: DateTime(2026, 8, 6, 12),
    );
    await service.sealAndDefer(DateTime(2026, 8, 6, 12));
    service.dispose();

    expect((await db.dayDao.getDay('2026-08-04'))!.finalT, 0);
    expect((await db.dayDao.getDay('2026-08-05'))!.finalT, closeTo(0.5, 1e-9));
    expect(
      (await db.todoDao.getByDate(
        '2026-08-04',
      )).any((todo) => todo.id == move1.id),
      false,
    );
    final today = await db.todoDao.getByDate('2026-08-06');
    expect(today.map((todo) => todo.title), ['그제 미완료', '어제 미완료']);
    expect(today.first.deferredFrom, '2026-08-04');
    expect(
      (await db.todoDao.getByDate('2026-08-05')).map((todo) => todo.title),
      ['완료됨', '미루지 않음'],
    );
  });

  test('반복 항목은 저장소 편집에서도 자동 미루기를 켤 수 없다', () async {
    final recurrence = await db.recurrenceDao.create(
      title: '반복',
      rule: RecurrenceRule.daily,
      startDate: d,
    );
    final todo = await db.todoDao.insertTodo(
      title: '반복',
      date: d,
      recurrenceId: recurrence.id,
    );

    await repo.edit(todo, autoDefer: true);

    expect((await db.todoDao.getByDate(d)).single.autoDefer, false);
  });

  test('반복 전체 삭제는 선택 날짜부터 모든 인스턴스를 지우고 규칙을 끈다', () async {
    final recurrence = await db.recurrenceDao.create(
      title: '매일 할 일',
      rule: RecurrenceRule.daily,
      startDate: d,
    );
    await RecurrenceExpander(db).expand(d);
    final selected = (await db.todoDao.getByDate('2026-08-08')).single;

    await repo.removeRecurringFrom(selected);

    final all = await db.todoDao.watchRange('0000', '9999').first;
    expect(all.every((todo) => todo.date.compareTo('2026-08-08') < 0), true);
    expect(
      (await db.recurrenceDao.getActive()).any(
        (rule) => rule.id == recurrence.id,
      ),
      false,
    );
  });

  test('반복 단건 삭제는 재전개 후에도 같은 회차가 다시 나타나지 않는다', () async {
    await db.recurrenceDao.create(
      title: '매일 할 일',
      rule: RecurrenceRule.daily,
      startDate: d,
    );
    final expander = RecurrenceExpander(db);
    await expander.expand(d);
    final selected = (await db.todoDao.getByDate(d)).single;

    await repo.remove(selected);
    await expander.expand(d);

    expect(await db.todoDao.watchByDate(d).first, isEmpty);
    final tombstone = (await db.todoDao.getByDate(d)).single;
    expect(tombstone.status, TodoStatus.deferred);
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
        db: db,
        onRollover: (_) {},
        now: DateTime(2026, 8, 6, 12),
      );
      await service.sealPastDays(DateTime(2026, 8, 6, 12));
      service.dispose();

      expect((await db.dayDao.getDay('2026-08-05'))!.finalT, 1.0);
    });

    test('전날 항목이 없으면(빈 방) 0.15로 봉인하지 않는다 — 후보에 없음', () async {
      final service = DayRolloverService(
        db: db,
        onRollover: (_) {},
        now: DateTime(2026, 8, 6, 12),
      );
      await service.sealPastDays(DateTime(2026, 8, 6, 12));
      service.dispose();
      expect(await db.dayDao.getDay('2026-08-05'), isNull);
    });

    test('이미 finalT가 있으면 덮어쓰지 않는다', () async {
      await repo.add(title: '지난 일', date: '2026-08-05');
      await repo.pullCord('2026-08-05', DateTime(2026, 8, 5, 22));
      final service = DayRolloverService(
        db: db,
        onRollover: (_) {},
        now: DateTime(2026, 8, 6, 12),
      );
      await service.sealPastDays(DateTime(2026, 8, 6, 12));
      service.dispose();
      expect((await db.dayDao.getDay('2026-08-05'))!.finalT, 1.0);
    });
  });
}
