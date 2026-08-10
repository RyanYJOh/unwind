import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/utils/dates.dart';
import '../../data/db/daos/todo_dao.dart';
import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart';
import 'brightness_engine.dart';

/// §5.3 자정 롤오버 — 정확히는 dayStartHour(기본 6시) 경계.
///
/// 세계관(§2): 내일의 방은 아직 불이 켜지지 않은 옆방이다.
/// 경계가 지나면 지난 방의 finalT를 봉인하고 새 방의 키를 발급한다.
class DayRolloverService {
  final UnwindDatabase db;
  final int dayStartHour;
  final void Function(String newTodayKey) onRollover;

  Timer? _timer;
  String _todayKey;
  bool _disposed = false;

  DayRolloverService({
    required this.db,
    required this.onRollover,
    this.dayStartHour = 6,
    DateTime? now,
  }) : _todayKey = logicalTodayKey(
         now ?? DateTime.now(),
         dayStartHour: dayStartHour,
       );

  String get todayKey => _todayKey;

  /// 앱 시작 시 호출: 지난 날들을 봉인하고 다음 경계 타이머를 건다.
  Future<void> start() async {
    await sealAndDefer(DateTime.now());
    _schedule();
  }

  void _schedule() {
    if (_disposed) return; // dispose 이후 start()의 잔여 비동기가 타이머를 걸지 않도록
    _timer?.cancel();
    final now = DateTime.now();
    final next = nextRolloverAt(now, dayStartHour: dayStartHour);
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), () async {
      final now2 = DateTime.now();
      await sealAndDefer(now2);
      _todayKey = logicalTodayKey(now2, dayStartHour: dayStartHour);
      onRollover(_todayKey);
      _schedule();
    });
  }

  Future<void> sealAndDefer(DateTime now) async {
    await sealPastDays(now);
    final today = logicalTodayKey(now, dayStartHour: dayStartHour);
    await TodoRepository(db).processAutoDefer(today);
  }

  /// 오늘 이전의, finalT가 비어 있는 날을 전부 봉인한다.
  /// finalT 규칙(§4.3·§5.3):
  ///   전등 줄을 당겼으면 이미 1.0이 기록되어 있음(여기 안 옴)
  ///   항목이 있었으면 그날의 peakProgress
  ///   항목이 0개였으면 빈 방 조도 0.15
  Future<void> sealPastDays(DateTime now) async {
    final today = logicalTodayKey(now, dayStartHour: dayStartHour);

    // 봉인 대상 후보: days에 행이 있는 날 + todos가 있는 날 (합집합, 오늘 제외)
    final dayRows = await db.dayDao.getRange('0000-00-00', today);
    final candidates = <String>{
      for (final d in dayRows)
        if (d.date != today) d.date,
    };
    final datesWithTodos = await db.todoDao.distinctDatesBefore(today);
    candidates.addAll(datesWithTodos);

    for (final date in candidates) {
      final row = await db.dayDao.getDay(date);
      if (row?.finalT != null) continue;
      final (done, total) = await db.todoDao.countsForDate(date);
      final peak = row?.peakProgress ?? 0.0;
      final raw = done / math.max(total, 1);
      final finalT = total == 0
          ? BrightnessEngine.emptyRoomT
          : math.max(peak, raw);
      await db.dayDao.sealDay(date, finalT);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

/// (테스트 및 M2 반복 전개에서 재사용)
extension TodoDatesQuery on TodoDao {
  Future<List<String>> distinctDatesBefore(String today) async {
    final q = selectOnly(todos, distinct: true)
      ..addColumns([todos.date])
      ..where(todos.date.isSmallerThanValue(today));
    final rows = await q.get();
    return [for (final r in rows) r.read(todos.date)!];
  }
}
