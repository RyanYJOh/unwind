import 'dart:math' as math;

import '../db/database.dart';

/// 삭제 실행취소 핸들 — 상단 토스트의 "되돌리기"가 이걸 실행한다.
/// 삭제 방식(단건·반복 tombstone·반복 전체)마다 되돌리는 법이 달라
/// 지식을 저장소 안에 가둬 둔다.
typedef TodoUndo = Future<void> Function();

/// §3.2 오늘의 방에 대한 쓰기 창구.
/// §5.2 단조 감소 규칙을 DB(days.peakProgress)에 영속화하는 책임을 진다.
/// 조도 값 자체는 brightnessProvider가 days+todos 스트림에서 파생한다.
class TodoRepository {
  final UnwindDatabase db;

  TodoRepository(this.db);

  Stream<List<Todo>> watchTodos(String date) => db.todoDao.watchByDate(date);

  Stream<List<Todo>> watchTimedPendingFrom(String date) =>
      db.todoDao.watchTimedPendingFrom(date);

  Stream<Day?> watchDay(String date) => db.dayDao.watchDay(date);

  Future<double> _rawProgress(String date) async {
    final (done, total) = await db.todoDao.countsForDate(date);
    return done / math.max(total, 1);
  }

  Future<double> _peak(String date) async =>
      (await db.dayDao.getDay(date))?.peakProgress ?? 0.0;

  /// 항목 추가 — peakProgress 유지 (§5.2: 미리 계획에 벌 주지 않는다)
  Future<Todo> add({
    required String title,
    String? memo,
    required String date,
    bool autoDefer = false,
    int? scheduledTimeMinutes,
  }) {
    return db.todoDao.insertTodo(
      title: title,
      memo: memo,
      date: date,
      autoDefer: autoDefer,
      scheduledTimeMinutes: scheduledTimeMinutes,
    );
  }

  /// 완료 토글 (§5.2)
  /// - 완료: peak = max(peak, raw)
  /// - 취소: peak = raw (명시적 되돌리기이므로 하강 허용)
  Future<void> setDone(Todo todo, bool done) async {
    await db.todoDao.setDone(todo.id, done);
    final raw = await _rawProgress(todo.date);
    final peak = done ? math.max(await _peak(todo.date), raw) : raw;
    await db.dayDao.upsertPeak(todo.date, peak);
  }

  /// 삭제 — peak = max(peak, raw) (§5.2).
  /// 되돌리기 핸들을 준다 (개편 2026-08-12: 삭제 토스트의 실행취소).
  Future<TodoUndo> remove(Todo todo) async {
    final prevPeak = await _peak(todo.date);
    if (todo.recurrenceId == null) {
      await db.todoDao.deleteTodo(todo.id);
    } else {
      // 반복 규칙이 다음 전개 때 같은 회차를 되살리지 않도록 tombstone 유지.
      await db.todoDao.suppressRecurringTodo(todo);
    }
    await _bumpPeak(todo.date);

    return () async {
      if (todo.recurrenceId == null) {
        await db.todoDao.restoreTodos([todo]);
      } else {
        await db.todoDao.unsuppressRecurringTodo(todo);
      }
      // 삭제로 올라갔던 peak을 원래대로 (명시적 되돌리기라 하강 허용, §5.2)
      await db.dayDao.upsertPeak(todo.date, prevPeak);
    };
  }

  /// 반복 항목의 선택 날짜부터 모든 인스턴스와 규칙을 삭제한다.
  Future<TodoUndo> removeRecurringFrom(Todo todo) async {
    final recurrenceId = todo.recurrenceId;
    if (recurrenceId == null) return remove(todo);

    final prevPeak = await _peak(todo.date);
    // 되살릴 수 있도록 지우기 전에 스냅샷을 뜬다
    final removed = await db.todoDao.getRecurringFrom(recurrenceId, todo.date);
    await db.recurrenceDao.deleteFrom(recurrenceId, fromDate: todo.date);
    await _bumpPeak(todo.date);

    return () async {
      await db.recurrenceDao.setActive(recurrenceId, true);
      await db.todoDao.restoreTodos(removed);
      await db.dayDao.upsertPeak(todo.date, prevPeak);
    };
  }

  Future<void> _bumpPeak(String date) async {
    final raw = await _rawProgress(date);
    await db.dayDao.upsertPeak(date, math.max(await _peak(date), raw));
  }

  Future<void> edit(
    Todo todo, {
    String? title,
    String? memo,
    String? date,
    bool? autoDefer,
    int? scheduledTimeMinutes,
    bool updateScheduledTime = false,
  }) async {
    final targetDate = date;
    final moved = targetDate != null && targetDate != todo.date;
    await db.todoDao.updateContent(
      todo.id,
      title: title,
      memo: memo,
      date: moved ? targetDate : null,
      autoDefer: todo.recurrenceId == null
          ? autoDefer
          : (autoDefer == null ? null : false),
      scheduledTimeMinutes: scheduledTimeMinutes,
      updateScheduledTime: updateScheduledTime,
    );
    if (targetDate == null || targetDate == todo.date) return;

    final oldRaw = await _rawProgress(todo.date);
    await db.dayDao.upsertPeak(
      todo.date,
      math.max(await _peak(todo.date), oldRaw),
    );

    final newRaw = await _rawProgress(targetDate);
    await db.dayDao.upsertPeak(
      targetDate,
      math.max(await _peak(targetDate), newRaw),
    );
  }

  /// 봉인된 과거 방의 미완료 자동 미루기 항목을 오늘로 원본 이동한다.
  Future<List<Todo>> processAutoDefer(String today) async {
    final pending = await db.todoDao.getPendingAutoDeferBefore(today);
    if (pending.isEmpty) return const [];

    var nextSort = await db.todoDao.nextSortIndex(today);
    for (final todo in pending) {
      await db.todoDao.moveAutoDeferredTodo(
        todo,
        date: today,
        sortIndex: nextSort++,
      );
    }
    return pending;
  }

  /// 전등 줄 (§6.4) — 남은 항목의 상태는 pending 유지, 불만 끈다.
  /// TODO(unwind): 미결정 — §15 미루기 처리. v1은 상태 변경 없음.
  Future<void> pullCord(String date, DateTime at) =>
      db.dayDao.markLightsOut(date, at);

  /// 유령 깨우기 (개정 2026-08-07) — 취침 후 스위치 ON = undo.
  /// 취침 기록(lightsOutAt·finalT) 삭제, 조도는 §5.2 되돌리기 규칙으로
  /// 재계산(raw, 하강 허용). 전등 줄은 다시 활성화된다.
  Future<void> wake(String date) async {
    final raw = await _rawProgress(date);
    await db.dayDao.clearLightsOut(date, raw);
  }
}
