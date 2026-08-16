import 'dart:convert';

import '../../core/utils/dates.dart';
import '../../domain/services/bill_calculator.dart';
import '../db/database.dart';

/// §6.5 청구서 생성·조회.
/// 생성 시점: 매주 월요일 첫 앱 실행 시 — 실제로는 "지난주 청구서가 없으면
/// 생성"으로 구현한다 (월요일을 놓치고 화요일에 열어도 생성된다).
/// 화면은 월요일에만 지난주를 보여 준다.
class BillRepository {
  final UnwindDatabase db;

  BillRepository(this.db);

  Stream<List<WeeklyBill>> watchUnread() => db.billDao.watchUnread();

  Future<WeeklyBill?> getBill(String weekStart) =>
      db.billDao.getBill(weekStart);

  Future<WeeklyBill?> getLatestBefore(String weekStart) =>
      db.billDao.getLatestBefore(weekStart);

  Future<void> markRead(String weekStart) => db.billDao.markRead(weekStart);

  /// 지난주(월~일) 청구서가 없으면 생성한다. 빈 주도 0원 영수증으로 남긴다.
  Future<WeeklyBill?> ensureLastWeekBill(
    String todayKey, {
    int wakeHour = 5,
    int bedtimeHour = 22,
  }) async {
    final weekStartKey = lastMondayKeyOf(todayKey);
    final lastSunday = dayKey(addDays(parseDayKey(weekStartKey), 6));

    final existing = await db.billDao.getBill(weekStartKey);
    if (existing != null) return existing;

    final todos = await _todosInRange(weekStartKey, lastSunday);
    final dayRows = await db.dayDao.getRange(weekStartKey, lastSunday);

    final result = BillCalculator.calcWeek(
      weekStartKey: weekStartKey,
      todosByDate: _groupByDate(todos),
      daysByDate: {for (final d in dayRows) d.date: d},
      wakeHour: wakeHour,
      bedtimeHour: bedtimeHour,
    );

    await db.billDao.insertBill(
      WeeklyBillsCompanion.insert(
        weekStart: weekStartKey,
        kwh: result.kwh,
        amount: result.amount,
        sleepMinutes: result.sleepMinutes,
        generatedAt: DateTime.now(),
        isRead: false,
        payload: encodeBillPayload(result),
      ),
    );
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

String encodeBillPayload(WeekBillResult result) => jsonEncode({
  'completed': result.completed,
  'total': result.total,
  'sleepScore': result.sleepScore,
  'days': [for (final d in result.days) d.toJson()],
});

/// payload JSON → 영수증 내용. 옛 배열 포맷도 읽는다.
BillContents decodeBillPayload(String payload) {
  final raw = jsonDecode(payload);
  if (raw is List) {
    final days = [
      for (final e in raw) DayBill.fromJson(e as Map<String, dynamic>),
    ];
    final closed = days.where((d) => d.lightsOut).length;
    return BillContents(
      completed: 0,
      total: 0,
      sleepScore: days.isEmpty ? 0 : closed / days.length,
      days: days,
    );
  }
  final map = raw as Map<String, dynamic>;
  return BillContents(
    completed: (map['completed'] as num?)?.toInt() ?? 0,
    total: (map['total'] as num?)?.toInt() ?? 0,
    sleepScore: (map['sleepScore'] as num?)?.toDouble() ?? 0,
    days: [
      for (final e in (map['days'] as List? ?? const []))
        DayBill.fromJson(e as Map<String, dynamic>),
    ],
  );
}
