// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_dao.dart';

// ignore_for_file: type=lint
mixin _$RecurrenceDaoMixin on DatabaseAccessor<UnwindDatabase> {
  $RecurrencesTable get recurrences => attachedDatabase.recurrences;
  $TodosTable get todos => attachedDatabase.todos;
  RecurrenceDaoManager get managers => RecurrenceDaoManager(this);
}

class RecurrenceDaoManager {
  final _$RecurrenceDaoMixin _db;
  RecurrenceDaoManager(this._db);
  $$RecurrencesTableTableManager get recurrences =>
      $$RecurrencesTableTableManager(_db.attachedDatabase, _db.recurrences);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db.attachedDatabase, _db.todos);
}
