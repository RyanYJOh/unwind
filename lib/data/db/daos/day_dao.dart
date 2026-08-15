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
  Stream<List<Day>> watchRange(String from, String to) =>
      (select(days)
            ..where((d) => d.date.isBetweenValues(from, to))
            ..orderBy([(d) => OrderingTerm.asc(d.date)]))
          .watch();

  Future<List<Day>> getRange(String from, String to) =>
      (select(days)
            ..where((d) => d.date.isBetweenValues(from, to))
            ..orderBy([(d) => OrderingTerm.asc(d.date)]))
          .get();

  Future<void> upsertPeak(String date, double peakProgress) {
    return into(days).insertOnConflictUpdate(
      DaysCompanion.insert(date: date, peakProgress: peakProgress),
    );
  }

  /// 전등 줄을 당김 (§6.4): lightsOutAt 기록 + finalT = 1.0 + peak = 1.0
  Future<void> markLightsOut(String date, DateTime at) {
    return into(days).insertOnConflictUpdate(
      DaysCompanion.insert(
        date: date,
        peakProgress: 1.0,
        lightsOutAt: Value(at),
        finalT: const Value(1.0),
      ),
    );
  }

  /// 유령 깨우기 (개정 2026-08-07): 취침 기록 삭제 + peak 재설정.
  /// §5.3의 "당긴 후 t=1.0 고정"은 스위치 undo로 해제 가능하도록 개정됨.
  Future<void> clearLightsOut(String date, double peakProgress) {
    return into(days).insertOnConflictUpdate(
      DaysCompanion.insert(
        date: date,
        peakProgress: peakProgress,
        lightsOutAt: const Value(null),
        finalT: const Value(null),
      ),
    );
  }

  /// 롤오버 시 하루 종료 조도 기록 (§4.3) — 이미 finalT가 있으면 유지.
  /// [restless]: 불을 남긴 채 넘어간 밤 (세계관 2026-08-15) — 미완 항목이
  /// 남아 Lumi가 제대로 못 잔 날. 다음날 다크서클의 근거.
  Future<void> sealDay(
    String date,
    double finalT, {
    bool restless = false,
  }) async {
    final existing = await getDay(date);
    if (existing == null) {
      await into(days).insertOnConflictUpdate(
        DaysCompanion.insert(
          date: date,
          peakProgress: finalT,
          finalT: Value(finalT),
          restless: Value(restless),
        ),
      );
    } else if (existing.finalT == null) {
      await (update(days)..where((d) => d.date.equals(date))).write(
        DaysCompanion(finalT: Value(finalT), restless: Value(restless)),
      );
    }
  }
}
