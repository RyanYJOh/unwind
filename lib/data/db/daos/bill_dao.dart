import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'bill_dao.g.dart';

/// §4.4 weekly_bills DAO
@DriftAccessor(tables: [WeeklyBills])
class BillDao extends DatabaseAccessor<UnwindDatabase> with _$BillDaoMixin {
  BillDao(super.db);

  Future<WeeklyBill?> getBill(String weekStart) =>
      (select(weeklyBills)..where((b) => b.weekStart.equals(weekStart)))
          .getSingleOrNull();

  /// [before] 이전의 가장 최근 청구서 (지난주 대비 문구용)
  Future<WeeklyBill?> getLatestBefore(String before) => (select(weeklyBills)
        ..where((b) => b.weekStart.isSmallerThanValue(before))
        ..orderBy([(b) => OrderingTerm.desc(b.weekStart)])
        ..limit(1))
      .getSingleOrNull();

  /// 미확인 청구서 스트림 — 홈 상단 배지 (§6.5)
  Stream<List<WeeklyBill>> watchUnread() =>
      (select(weeklyBills)..where((b) => b.isRead.equals(false))).watch();

  Future<void> insertBill(WeeklyBillsCompanion bill) =>
      into(weeklyBills).insert(bill);

  Future<void> markRead(String weekStart) =>
      (update(weeklyBills)..where((b) => b.weekStart.equals(weekStart)))
          .write(const WeeklyBillsCompanion(isRead: Value(true)));
}
