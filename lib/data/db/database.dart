import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/bill_dao.dart';
import 'daos/day_dao.dart';
import 'daos/recurrence_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/todo_dao.dart';
import 'tables/tables.dart';

part 'database.g.dart';

/// §3.2 단일 진실 공급원 — 모든 쓰기는 로컬 DB에 반영되고 UI는 스트림 구독.
@DriftDatabase(
  tables: [Todos, Recurrences, Days, WeeklyBills, Settings],
  daos: [TodoDao, DayDao, RecurrenceDao, BillDao, SettingsDao],
)
class UnwindDatabase extends _$UnwindDatabase {
  UnwindDatabase()
    : super(
        driftDatabase(
          name: 'unwind',
          // 웹은 개발 미리보기 전용 (§1.4 — 제품은 iOS 온리).
          // web/sqlite3.wasm + web/drift_worker.js 필요.
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  /// 테스트용 인메모리 등 임의 executor 주입
  UnwindDatabase.withExecutor(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(todos, todos.autoDefer);
        await m.addColumn(todos, todos.scheduledTimeMinutes);
        await m.addColumn(recurrences, recurrences.scheduledTimeMinutes);
      }
      if (from < 3) {
        // 세계관 2026-08-15: 불을 남긴 밤 기록 (다음날 다크서클)
        await m.addColumn(days, days.restless);
        // 소급 추론: 이미 봉인된 밤 중 불을 남긴 밤을 restless로 채운다 —
        // 어젯밤 못 잔 사용자가 업데이트 직후에도 다크서클을 만난다.
        // 0.15 = BrightnessEngine.emptyRoomT (빈 방은 잘 잔 밤이라 제외),
        // finalT 1.0 = 소등/전부 완료, lights_out_at 존재 = 줄을 당김.
        await customStatement(
          'UPDATE days SET restless = 1 '
          'WHERE final_t IS NOT NULL AND final_t < 1.0 '
          'AND final_t != 0.15 AND lights_out_at IS NULL',
        );
      }
    },
  );
}
