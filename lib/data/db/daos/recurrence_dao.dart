import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'recurrence_dao.g.dart';

/// §4.2 recurrences DAO
@DriftAccessor(tables: [Recurrences, Todos])
class RecurrenceDao extends DatabaseAccessor<UnwindDatabase>
    with _$RecurrenceDaoMixin {
  RecurrenceDao(super.db);

  static const _uuid = Uuid();

  Future<List<Recurrence>> getActive() =>
      (select(recurrences)..where((r) => r.isActive.equals(true))).get();

  Future<Recurrence> create({
    required String title,
    String? memo,
    required RecurrenceRule rule,
    int? weekdayMask,
    int? dayOfMonth,
    required String startDate,
    String? endDate,
  }) async {
    final id = _uuid.v4();
    await into(recurrences).insert(RecurrencesCompanion.insert(
      id: id,
      title: title,
      memo: Value(memo),
      rule: rule,
      weekdayMask: Value(weekdayMask),
      dayOfMonth: Value(dayOfMonth),
      startDate: startDate,
      endDate: Value(endDate),
      isActive: true,
    ));
    return (select(recurrences)..where((r) => r.id.equals(id))).getSingle();
  }

  /// 규칙 수정 (§4.2): 미래의 미완료 인스턴스만 갱신.
  /// 과거 및 완료된 인스턴스는 건드리지 않는다.
  Future<void> updateRule(
    String id, {
    String? title,
    String? memo,
    required String fromDate, // 논리적 오늘
  }) async {
    await (update(recurrences)..where((r) => r.id.equals(id))).write(
      RecurrencesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        memo: Value(memo),
      ),
    );
    if (title != null) {
      await (update(todos)
            ..where((t) =>
                t.recurrenceId.equals(id) &
                t.date.isBiggerOrEqualValue(fromDate) &
                t.status.equalsValue(TodoStatus.pending)))
          .write(TodosCompanion(title: Value(title), memo: Value(memo)));
    }
  }

  /// 비활성화: 미래의 미완료 인스턴스 삭제, 과거·완료는 유지
  Future<void> deactivate(String id, {required String fromDate}) async {
    await (update(recurrences)..where((r) => r.id.equals(id)))
        .write(const RecurrencesCompanion(isActive: Value(false)));
    await (delete(todos)
          ..where((t) =>
              t.recurrenceId.equals(id) &
              t.date.isBiggerOrEqualValue(fromDate) &
              t.status.equalsValue(TodoStatus.pending)))
        .go();
  }
}
