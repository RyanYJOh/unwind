// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_dao.dart';

// ignore_for_file: type=lint
mixin _$BillDaoMixin on DatabaseAccessor<UnwindDatabase> {
  $WeeklyBillsTable get weeklyBills => attachedDatabase.weeklyBills;
  BillDaoManager get managers => BillDaoManager(this);
}

class BillDaoManager {
  final _$BillDaoMixin _db;
  BillDaoManager(this._db);
  $$WeeklyBillsTableTableManager get weeklyBills =>
      $$WeeklyBillsTableTableManager(_db.attachedDatabase, _db.weeklyBills);
}
