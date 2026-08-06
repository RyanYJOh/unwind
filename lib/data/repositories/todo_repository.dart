import 'dart:math' as math;

import '../db/database.dart';

/// §3.2 오늘의 방에 대한 쓰기 창구.
/// §5.2 단조 감소 규칙을 DB(days.peakProgress)에 영속화하는 책임을 진다.
/// 조도 값 자체는 brightnessProvider가 days+todos 스트림에서 파생한다.
class TodoRepository {
  final UnwindDatabase db;

  TodoRepository(this.db);

  Stream<List<Todo>> watchTodos(String date) => db.todoDao.watchByDate(date);

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
  }) {
    return db.todoDao.insertTodo(title: title, memo: memo, date: date);
  }

  /// 완료 토글 (§5.2)
  /// - 완료: peak = max(peak, raw)
  /// - 취소: peak = raw (명시적 되돌리기이므로 하강 허용)
  Future<void> setDone(Todo todo, bool done) async {
    await db.todoDao.setDone(todo.id, done);
    final raw = await _rawProgress(todo.date);
    final peak =
        done ? math.max(await _peak(todo.date), raw) : raw;
    await db.dayDao.upsertPeak(todo.date, peak);
  }

  /// 삭제 — peak = max(peak, raw) (§5.2)
  Future<void> remove(Todo todo) async {
    await db.todoDao.deleteTodo(todo.id);
    final raw = await _rawProgress(todo.date);
    await db.dayDao
        .upsertPeak(todo.date, math.max(await _peak(todo.date), raw));
  }

  Future<void> edit(Todo todo, {String? title, String? memo}) =>
      db.todoDao.updateContent(todo.id, title: title, memo: memo);

  /// 전등 줄 (§6.4) — 남은 항목의 상태는 pending 유지, 불만 끈다.
  /// TODO(unwind): 미결정 — §15 미루기 처리. v1은 상태 변경 없음.
  Future<void> pullCord(String date, DateTime at) =>
      db.dayDao.markLightsOut(date, at);
}
