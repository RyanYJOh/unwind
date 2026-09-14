import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/repositories/todo_repository.dart';

/// 홈 편집 모드의 순서 변경 (2026-09-14)
void main() {
  late UnwindDatabase db;

  setUp(() => db = UnwindDatabase.withExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  const day = '2026-09-14';

  Future<List<String>> titles() async => [
    for (final t in await db.todoDao.getByDate(day)) t.title,
  ];

  test('시간 없는 항목만 새 순서가 되고, 시간 지정 항목은 앞자리를 지킨다', () async {
    final a = await db.todoDao.insertTodo(title: 'A', date: day);
    await db.todoDao.insertTodo(
      title: 'T',
      date: day,
      scheduledTimeMinutes: 600,
    );
    final b = await db.todoDao.insertTodo(title: 'B', date: day);
    final c = await db.todoDao.insertTodo(title: 'C', date: day);

    await TodoRepository(db).reorder([c, a, b]);
    expect(await titles(), ['T', 'C', 'A', 'B']);

    // 다시 옮겨도 시간 지정 항목의 자리는 그대로다
    await TodoRepository(db).reorder([b, c, a]);
    expect(await titles(), ['T', 'B', 'C', 'A']);
  });

  test('sortIndex가 겹쳐 있어도 요청한 순서로 편다', () async {
    final a = await db.todoDao.insertTodo(title: 'A', date: day);
    final b = await db.todoDao.insertTodo(title: 'B', date: day);
    await (db.update(db.todos)).write(const TodosCompanion(sortIndex: Value(0)));

    await TodoRepository(db).reorder([b, a]);
    expect(await titles(), ['B', 'A']);
    await TodoRepository(db).reorder([a, b]);
    expect(await titles(), ['A', 'B']);
  });
}
