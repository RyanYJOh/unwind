import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'settings_dao.g.dart';

/// §4.5 settings DAO — 키/값 저장.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<UnwindDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchValue(String key) =>
      (select(settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> setValue(String key, String value) {
    return into(
      settings,
    ).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  // 기본값 헬퍼 (§4.5)
  Future<bool> getBool(String key, {required bool fallback}) async =>
      switch (await getValue(key)) {
        null => fallback,
        final v => v == 'true',
      };

  Future<int> getInt(String key, {required int fallback}) async =>
      int.tryParse(await getValue(key) ?? '') ?? fallback;
}
