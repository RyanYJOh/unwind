import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'day_dao.g.dart';

/// §4.3 days DAO — peakProgress 영속화, 전등 줄, finalT.
@DriftAccessor(tables: [Days])
class DayDao extends DatabaseAccessor<UnwindDatabase> with _$DayDaoMixin {
  DayDao(super.db);

  Future<Day?> getDay(String date) =>
      (select(days)..where((d) => d.date.equals(date))).getSingleOrNull();

  Stream<Day?> watchDay(String date) =>
      (select(days)..where((d) => d.date.equals(date))).watchSingleOrNull();

  /// 주간 스트립용 — 범위 스트림 (§6.2)
  Stream<List<Day>> watchRange(String from, String to) => (select(days)
        ..where((d) => d.date.isBetweenValues(from, to))
        ..orderBy([(d) => OrderingTerm.asc(d.date)]))
      .watch();

  Future<List<Day>> getRange(String from, String to) => (select(days)
        ..where((d) => d.date.isBetweenValues(from, to))
        ..orderBy([(d) => OrderingTerm.asc(d.date)]))
      .get();

  Future<void> upsertPeak(String date, double peakProgress) {
    return into(days).insertOnConflictUpdate(DaysCompanion.insert(
      date: date,
      peakProgress: peakProgress,
    ));
  }

  /// 전등 줄을 당김 (§6.4): lightsOutAt 기록 + finalT = 1.0 + peak = 1.0
  Future<void> markLightsOut(String date, DateTime at) {
    return into(days).insertOnConflictUpdate(DaysCompanion.insert(
      date: date,
      peakProgress: 1.0,
      lightsOutAt: Value(at),
      finalT: const Value(1.0),
    ));
  }

  /// 롤오버 시 하루 종료 조도 기록 (§4.3) — 이미 finalT가 있으면 유지
  Future<void> sealDay(String date, double finalT) async {
    final existing = await getDay(date);
    if (existing == null) {
      await into(days).insertOnConflictUpdate(DaysCompanion.insert(
        date: date,
        peakProgress: finalT,
        finalT: Value(finalT),
      ));
    } else if (existing.finalT == null) {
      await (update(days)..where((d) => d.date.equals(date)))
          .write(DaysCompanion(finalT: Value(finalT)));
    }
  }
}
