import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/domain/services/recurrence_expander.dart';

/// §4.2 반복 전개 — 오늘~+14일 materialize, 중복 방지, 과거 소급 금지
void main() {
  late UnwindDatabase db;
  late RecurrenceExpander expander;
  const today = '2026-08-06'; // 목요일

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    expander = RecurrenceExpander(db);
  });

  tearDown(() => db.close());

  Future<List<Todo>> allTodos() => db.todoDao.watchRange('0000', '9999').first;

  test('daily: 오늘부터 15일치 인스턴스 생성 (오늘~+14일)', () async {
    await db.recurrenceDao.create(
      title: '물 마시기',
      rule: RecurrenceRule.daily,
      startDate: today,
    );
    await expander.expand(today);

    final rows = await allTodos();
    expect(rows.length, 15);
    expect(rows.first.date, today);
    expect(rows.last.date, '2026-08-20');
    expect(rows.every((t) => t.status == TodoStatus.pending), true);
  });

  test('중복 방지: 두 번 전개해도 인스턴스가 늘지 않는다', () async {
    await db.recurrenceDao.create(
      title: '물 마시기',
      rule: RecurrenceRule.daily,
      startDate: today,
    );
    await expander.expand(today);
    await expander.expand(today);
    expect((await allTodos()).length, 15);
  });

  test('반복 규칙의 시간은 모든 생성 회차에 전파된다', () async {
    await db.recurrenceDao.create(
      title: '아침 약',
      rule: RecurrenceRule.daily,
      startDate: today,
      scheduledTimeMinutes: 7 * 60 + 30,
    );
    await expander.expand(today);

    expect(
      (await allTodos()).every(
        (todo) => todo.scheduledTimeMinutes == 7 * 60 + 30,
      ),
      true,
    );
  });

  test('과거 소급 금지: startDate가 과거여도 오늘 이전은 생성하지 않는다', () async {
    await db.recurrenceDao.create(
      title: '오래된 규칙',
      rule: RecurrenceRule.daily,
      startDate: '2026-01-01',
    );
    await expander.expand(today);
    final rows = await allTodos();
    expect(rows.every((t) => t.date.compareTo(today) >= 0), true);
  });

  test('weekdays: 주중만 생성된다', () async {
    await db.recurrenceDao.create(
      title: '출근 준비',
      rule: RecurrenceRule.weekdays,
      startDate: today,
    );
    await expander.expand(today);
    final rows = await allTodos();
    // 8/6(목)~8/20(목): 주말 8/8,9,15,16 제외 → 11일
    expect(rows.length, 11);
    expect(rows.any((t) => t.date == '2026-08-08'), false); // 토
    expect(rows.any((t) => t.date == '2026-08-09'), false); // 일
  });

  test('weekly: 비트마스크 요일만 (월=1 … 일=64)', () async {
    await db.recurrenceDao.create(
      title: '분리수거',
      rule: RecurrenceRule.weekly,
      weekdayMask: 1 | 8, // 월 + 목
      startDate: today,
    );
    await expander.expand(today);
    final rows = await allTodos();
    // 목 8/6, 월 8/10, 목 8/13, 월 8/17, 목 8/20 → 5개
    expect(rows.map((t) => t.date).toList(), [
      '2026-08-06',
      '2026-08-10',
      '2026-08-13',
      '2026-08-17',
      '2026-08-20',
    ]);
  });

  test('monthly: 해당 일자만, 없는 날은 건너뜀', () async {
    await db.recurrenceDao.create(
      title: '월세 이체',
      rule: RecurrenceRule.monthly,
      dayOfMonth: 15,
      startDate: today,
    );
    await expander.expand(today);
    final rows = await allTodos();
    expect(rows.map((t) => t.date).toList(), ['2026-08-15']);
  });

  test('endDate 이후에는 생성하지 않는다', () async {
    await db.recurrenceDao.create(
      title: '단기 습관',
      rule: RecurrenceRule.daily,
      startDate: today,
      endDate: '2026-08-08',
    );
    await expander.expand(today);
    expect((await allTodos()).length, 3); // 6, 7, 8일
  });

  test('규칙 수정: 미래의 미완료만 갱신, 완료된 것은 유지 (§4.2)', () async {
    final rec = await db.recurrenceDao.create(
      title: '옛 이름',
      rule: RecurrenceRule.daily,
      startDate: today,
    );
    await expander.expand(today);
    final rows = await allTodos();
    await db.todoDao.setDone(rows.first.id, true); // 오늘 것 완료

    await db.recurrenceDao.updateRule(rec.id, title: '새 이름', fromDate: today);

    final after = await allTodos();
    final doneOne = after.firstWhere((t) => t.status == TodoStatus.done);
    expect(doneOne.title, '옛 이름'); // 완료된 인스턴스는 건드리지 않는다
    expect(
      after
          .where((t) => t.status == TodoStatus.pending)
          .every((t) => t.title == '새 이름'),
      true,
    );
  });

  test('비활성화: 미래 미완료 삭제, 완료는 유지', () async {
    final rec = await db.recurrenceDao.create(
      title: '그만둘 습관',
      rule: RecurrenceRule.daily,
      startDate: today,
    );
    await expander.expand(today);
    final rows = await allTodos();
    await db.todoDao.setDone(rows.first.id, true);

    await db.recurrenceDao.deactivate(rec.id, fromDate: today);

    final after = await allTodos();
    expect(after.length, 1);
    expect(after.single.status, TodoStatus.done);

    // 비활성 후 재전개해도 생성되지 않는다
    await expander.expand(today);
    expect((await allTodos()).length, 1);
  });
}
