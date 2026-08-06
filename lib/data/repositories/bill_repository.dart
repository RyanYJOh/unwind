import 'dart:convert';

import '../../core/utils/dates.dart';
import '../../domain/services/bill_calculator.dart';
import '../db/database.dart';

/// §6.5 청구서 생성·조회.
/// 생성 시점: 매주 월요일 첫 앱 실행 시 — 실제로는 "지난주 청구서가 없으면
/// 생성"으로 구현한다 (월요일을 놓치고 화요일에 열어도 생성된다).
class BillRepository {
  final UnwindDatabase db;

  BillRepository(this.db);

  Stream<List<WeeklyBill>> watchUnread() => db.billDao.watchUnread();

  Future<WeeklyBill?> getBill(String weekStart) => db.billDao.getBill(weekStart);

  Future<WeeklyBill?> getLatestBefore(String weekStart) =>
      db.billDao.getLatestBefore(weekStart);

  Future<void> markRead(String weekStart) => db.billDao.markRead(weekStart);

  /// 지난주(월~일) 청구서가 없으면 생성한다.
  /// 지난주에 항목이 하나도 없었다면 청구할 것이 없으므로 만들지 않는다.
  Future<WeeklyBill?> ensureLastWeekBill(String todayKey) async {
    final today = parseDayKey(todayKey);
    final thisMonday = addDays(today, -(today.weekday - 1));
    final lastMonday = addDays(thisMonday, -7);
    final lastSunday = addDays(thisMonday, -1);
    final weekStartKey = dayKey(lastMonday);

    final existing = await db.billDao.getBill(weekStartKey);
    if (existing != null) return existing;

    final todos = await _todosInRange(dayKey(lastMonday), dayKey(lastSunday));
    if (todos.isEmpty) return null; // 빈 주 — 청구서 없음

    final dayRows =
        await db.dayDao.getRange(dayKey(lastMonday), dayKey(lastSunday));

    final result = BillCalculator.calcWeek(
      weekStartKey: weekStartKey,
      todosByDate: _groupByDate(todos),
      daysByDate: {for (final d in dayRows) d.date: d},
    );

    await db.billDao.insertBill(WeeklyBillsCompanion.insert(
      weekStart: weekStartKey,
      kwh: result.kwh,
      amount: result.amount,
      sleepMinutes: result.sleepMinutes,
      generatedAt: DateTime.now(),
      isRead: false,
      payload: jsonEncode([for (final d in result.days) d.toJson()]),
    ));
    return db.billDao.getBill(weekStartKey);
  }

  Future<List<Todo>> _todosInRange(String from, String to) =>
      db.todoDao.watchRange(from, to).first;

  Map<String, List<Todo>> _groupByDate(List<Todo> todos) {
    final map = <String, List<Todo>>{};
    for (final t in todos) {
      map.putIfAbsent(t.date, () => []).add(t);
    }
    return map;
  }
}

/// payload JSON → 일별 상세
List<DayBill> decodeBillPayload(String payload) => [
      for (final e in jsonDecode(payload) as List)
        DayBill.fromJson(e as Map<String, dynamic>)
    ];
