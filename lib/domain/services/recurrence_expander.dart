import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';

/// §4.2 반복 전개 — 앱 시작 시 및 날짜 롤오버 시,
/// `오늘 ~ 오늘+14일` 범위의 반복 인스턴스를 실제 todos 행으로 생성한다.
/// 이미 존재하면 건너뛴다. 과거 날짜에는 소급 생성하지 않는다.
class RecurrenceExpander {
  final UnwindDatabase db;

  /// 전개 범위 (§4.2)
  static const horizonDays = 14;

  RecurrenceExpander(this.db);

  /// [todayKey]부터 14일치 인스턴스를 materialize한다.
  Future<void> expand(String todayKey) async {
    final today = parseDayKey(todayKey);
    final actives = await db.recurrenceDao.getActive();

    for (final rec in actives) {
      final start = parseDayKey(rec.startDate);
      final end = rec.endDate != null ? parseDayKey(rec.endDate!) : null;

      for (var i = 0; i <= horizonDays; i++) {
        final day = addDays(today, i);
        if (day.isBefore(start)) continue; // 시작 전
        if (end != null && day.isAfter(end)) continue; // 종료 후
        if (!_matches(rec, day)) continue;

        final key = dayKey(day);
        // (recurrenceId, date) UNIQUE 인덱스가 중복을 막는다 — 존재하면 건너뜀
        final exists = await db.todoDao.existsInstance(rec.id, key);
        if (exists) continue;
        await db.todoDao.insertTodo(
          title: rec.title,
          memo: rec.memo,
          date: key,
          recurrenceId: rec.id,
          scheduledTimeMinutes: rec.scheduledTimeMinutes,
        );
      }
    }
  }

  /// 규칙이 해당 날짜에 적용되는가.
  /// weekdayMask 비트: 월=1, 화=2, 수=4, 목=8, 금=16, 토=32, 일=64 (§4.2)
  bool _matches(Recurrence rec, DateTime day) {
    switch (rec.rule) {
      case RecurrenceRule.daily:
        return true;
      case RecurrenceRule.weekdays:
        return day.weekday <= DateTime.friday;
      case RecurrenceRule.weekly:
        final mask = rec.weekdayMask ?? 0;
        return (mask & (1 << (day.weekday - 1))) != 0;
      case RecurrenceRule.monthly:
        final dom = rec.dayOfMonth ?? parseDayKey(rec.startDate).day;
        // 해당 달에 없는 날(예: 31일)은 건너뛴다 — 임의로 말일로 옮기지 않는다
        return day.day == dom;
    }
  }
}
