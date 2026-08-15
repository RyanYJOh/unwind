import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'todo_dao.g.dart';

/// §4.1 todos DAO — 모든 쓰기는 동기적으로 DB에 반영되고 UI는 스트림을
/// 구독한다 (§3.2). 낙관적 업데이트 없음.
@DriftAccessor(tables: [Todos])
class TodoDao extends DatabaseAccessor<UnwindDatabase> with _$TodoDaoMixin {
  TodoDao(super.db);

  static const _uuid = Uuid();

  void _validateTime(int? minutes) {
    if (minutes != null && (minutes < 0 || minutes > 1439)) {
      throw RangeError.range(minutes, 0, 1439, 'scheduledTimeMinutes');
    }
  }

  /// 특정 날짜의 할 일 스트림 — 시간이 있는 항목 우선, 이른 시간 순.
  Stream<List<Todo>> watchByDate(String date) {
    return (select(todos)
          ..where(
            (t) =>
                t.date.equals(date) &
                t.status.equalsValue(TodoStatus.deferred).not(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes.isNull()),
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes),
            (t) => OrderingTerm.asc(t.sortIndex),
          ]))
        .watch();
  }

  Future<List<Todo>> getByDate(String date) {
    return (select(todos)
          ..where((t) => t.date.equals(date))
          ..orderBy([
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes.isNull()),
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes),
            (t) => OrderingTerm.asc(t.sortIndex),
          ]))
        .get();
  }

  /// 새 항목 추가 — sortIndex는 그 날의 맨 뒤
  Future<Todo> insertTodo({
    required String title,
    String? memo,
    required String date,
    String? recurrenceId,
    bool autoDefer = false,
    int? scheduledTimeMinutes,
  }) async {
    _validateTime(scheduledTimeMinutes);
    final maxSort =
        await (selectOnly(todos)
              ..addColumns([todos.sortIndex.max()])
              ..where(todos.date.equals(date)))
            .map((row) => row.read(todos.sortIndex.max()))
            .getSingle();
    final entry = TodosCompanion.insert(
      id: _uuid.v4(),
      title: title,
      memo: Value(memo),
      date: date,
      status: TodoStatus.pending,
      sortIndex: (maxSort ?? -1) + 1,
      createdAt: DateTime.now(),
      recurrenceId: Value(recurrenceId),
      autoDefer: Value(recurrenceId == null && autoDefer),
      scheduledTimeMinutes: Value(scheduledTimeMinutes),
    );
    await into(todos).insert(entry);
    return (select(
      todos,
    )..where((t) => t.id.equals(entry.id.value))).getSingle();
  }

  /// 일괄 완료 (전등 줄, 개정 2026-08-15) — 그날의 pending 등을 전부 끈다.
  /// completedAt은 줄을 당긴 시각 — 청구서의 등 사용 시간 계산과 일치한다.
  Future<void> completeAllPending(String date, DateTime completedAt) {
    return (update(todos)
          ..where((t) => t.date.equals(date))
          ..where((t) => t.status.equalsValue(TodoStatus.pending)))
        .write(
          TodosCompanion(
            status: const Value(TodoStatus.done),
            completedAt: Value(completedAt),
          ),
        );
  }

  /// 완료 토글 (§6.1: 탭 → 토글)
  Future<void> setDone(String id, bool done) {
    return (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        status: Value(done ? TodoStatus.done : TodoStatus.pending),
        completedAt: Value(done ? DateTime.now() : null),
      ),
    );
  }

  Future<void> updateContent(
    String id, {
    String? title,
    String? memo,
    String? date,
    bool? autoDefer,
    int? scheduledTimeMinutes,
    bool updateScheduledTime = false,
  }) async {
    if (updateScheduledTime) _validateTime(scheduledTimeMinutes);
    int? nextSortIndex;
    if (date != null) {
      final maxSort =
          await (selectOnly(todos)
                ..addColumns([todos.sortIndex.max()])
                ..where(todos.date.equals(date)))
              .map((row) => row.read(todos.sortIndex.max()))
              .getSingle();
      nextSortIndex = (maxSort ?? -1) + 1;
    }
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        memo: Value(memo),
        date: date != null ? Value(date) : const Value.absent(),
        autoDefer: autoDefer != null ? Value(autoDefer) : const Value.absent(),
        scheduledTimeMinutes: updateScheduledTime
            ? Value(scheduledTimeMinutes)
            : const Value.absent(),
        sortIndex: nextSortIndex != null
            ? Value(nextSortIndex)
            : const Value.absent(),
      ),
    );
  }

  Future<void> deleteTodo(String id) {
    return (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  /// 삭제 실행취소 — 지워진 행을 id·정렬·생성시각까지 그대로 되살린다.
  Future<void> restoreTodos(List<Todo> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(todos, rows));
  }

  /// 반복 규칙의 [fromDate] 이후 인스턴스 (삭제 전 스냅샷용)
  Future<List<Todo>> getRecurringFrom(String recurrenceId, String fromDate) {
    return (select(todos)..where(
          (t) =>
              t.recurrenceId.equals(recurrenceId) &
              t.date.isBiggerOrEqualValue(fromDate),
        ))
        .get();
  }

  Future<List<Todo>> getPendingAutoDeferBefore(String today) {
    return (select(todos)
          ..where(
            (t) =>
                t.date.isSmallerThanValue(today) &
                t.autoDefer.equals(true) &
                t.status.equalsValue(TodoStatus.pending),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.sortIndex),
          ]))
        .get();
  }

  Future<int> nextSortIndex(String date) async {
    final maxSort =
        await (selectOnly(todos)
              ..addColumns([todos.sortIndex.max()])
              ..where(todos.date.equals(date)))
            .map((row) => row.read(todos.sortIndex.max()))
            .getSingle();
    return (maxSort ?? -1) + 1;
  }

  Future<void> moveAutoDeferredTodo(
    Todo todo, {
    required String date,
    required int sortIndex,
  }) {
    return (update(todos)..where((t) => t.id.equals(todo.id))).write(
      TodosCompanion(
        date: Value(date),
        sortIndex: Value(sortIndex),
        deferredFrom: Value(todo.date),
      ),
    );
  }

  Stream<List<Todo>> watchTimedPendingFrom(String fromDate) {
    return (select(todos)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(fromDate) &
                t.status.equalsValue(TodoStatus.pending) &
                t.scheduledTimeMinutes.isNotNull(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes),
          ]))
        .watch();
  }

  /// 반복 인스턴스 단건 삭제용 tombstone.
  /// 행을 남겨 (recurrenceId, date) 중복 방지가 재전개를 막도록 한다.
  Future<void> suppressRecurringTodo(Todo todo) {
    return (update(todos)..where((t) => t.id.equals(todo.id))).write(
      TodosCompanion(
        status: const Value(TodoStatus.deferred),
        completedAt: const Value(null),
        deferredFrom: Value(todo.date),
      ),
    );
  }

  /// [suppressRecurringTodo]의 실행취소 — tombstone을 걷고 다시 켠다.
  Future<void> unsuppressRecurringTodo(Todo todo) {
    return (update(todos)..where((t) => t.id.equals(todo.id))).write(
      TodosCompanion(
        status: Value(todo.status),
        completedAt: Value(todo.completedAt),
        deferredFrom: Value(todo.deferredFrom),
      ),
    );
  }

  /// 반복 인스턴스 존재 여부 (§4.2 중복 방지)
  Future<bool> existsInstance(String recurrenceId, String date) async {
    final row =
        await (select(todos)
              ..where(
                (t) =>
                    t.recurrenceId.equals(recurrenceId) & t.date.equals(date),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// 날짜 범위의 할 일 스트림 (주간 뷰 §6.2)
  Stream<List<Todo>> watchRange(String from, String to) {
    return (select(todos)
          ..where(
            (t) =>
                t.date.isBetweenValues(from, to) &
                t.status.equalsValue(TodoStatus.deferred).not(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes.isNull()),
            (t) => OrderingTerm.asc(t.scheduledTimeMinutes),
            (t) => OrderingTerm.asc(t.sortIndex),
          ]))
        .watch();
  }

  /// (doneCount, totalCount) — §5.1: totalCount = pending + done
  /// deferred는 조도 계산에서 제외 (v1에서는 발생하지 않음, §15)
  Future<(int, int)> countsForDate(String date) async {
    final rows = await getByDate(date);
    final counted = rows.where((t) => t.status != TodoStatus.deferred).toList();
    final done = counted.where((t) => t.status == TodoStatus.done).length;
    return (done, counted.length);
  }
}
