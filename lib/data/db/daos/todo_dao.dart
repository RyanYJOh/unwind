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

  /// 특정 날짜의 할 일 스트림 — sortIndex 고정 정렬 (§6.1: 완료해도 순서 유지)
  Stream<List<Todo>> watchByDate(String date) {
    return (select(todos)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<List<Todo>> getByDate(String date) {
    return (select(todos)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
  }

  /// 새 항목 추가 — sortIndex는 그 날의 맨 뒤
  Future<Todo> insertTodo({
    required String title,
    String? memo,
    required String date,
    String? recurrenceId,
  }) async {
    final maxSort = await (selectOnly(todos)
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
    );
    await into(todos).insert(entry);
    return (select(todos)..where((t) => t.id.equals(entry.id.value)))
        .getSingle();
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

  Future<void> updateContent(String id, {String? title, String? memo}) {
    return (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        memo: Value(memo),
      ),
    );
  }

  Future<void> deleteTodo(String id) {
    return (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  /// (doneCount, totalCount) — §5.1: totalCount = pending + done
  /// deferred는 조도 계산에서 제외 (v1에서는 발생하지 않음, §15)
  Future<(int, int)> countsForDate(String date) async {
    final rows = await getByDate(date);
    final counted =
        rows.where((t) => t.status != TodoStatus.deferred).toList();
    final done =
        counted.where((t) => t.status == TodoStatus.done).length;
    return (done, counted.length);
  }
}
