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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(todos, todos.autoDefer);
        await m.addColumn(todos, todos.scheduledTimeMinutes);
        await m.addColumn(recurrences, recurrences.scheduledTimeMinutes);
      }
    },
  );
}
