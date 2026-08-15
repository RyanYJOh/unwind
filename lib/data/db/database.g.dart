// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TodosTable extends Todos with TableInfo<$TodosTable, Todo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TodoStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TodoStatus>($TodosTable.$converterstatus);
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceIdMeta = const VerificationMeta(
    'recurrenceId',
  );
  @override
  late final GeneratedColumn<String> recurrenceId = GeneratedColumn<String>(
    'recurrence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoDeferMeta = const VerificationMeta(
    'autoDefer',
  );
  @override
  late final GeneratedColumn<bool> autoDefer = GeneratedColumn<bool>(
    'auto_defer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_defer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scheduledTimeMinutesMeta =
      const VerificationMeta('scheduledTimeMinutes');
  @override
  late final GeneratedColumn<int> scheduledTimeMinutes = GeneratedColumn<int>(
    'scheduled_time_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deferredFromMeta = const VerificationMeta(
    'deferredFrom',
  );
  @override
  late final GeneratedColumn<String> deferredFrom = GeneratedColumn<String>(
    'deferred_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    memo,
    date,
    status,
    sortIndex,
    createdAt,
    completedAt,
    recurrenceId,
    autoDefer,
    scheduledTimeMinutes,
    deferredFrom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Todo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_id')) {
      context.handle(
        _recurrenceIdMeta,
        recurrenceId.isAcceptableOrUnknown(
          data['recurrence_id']!,
          _recurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('auto_defer')) {
      context.handle(
        _autoDeferMeta,
        autoDefer.isAcceptableOrUnknown(data['auto_defer']!, _autoDeferMeta),
      );
    }
    if (data.containsKey('scheduled_time_minutes')) {
      context.handle(
        _scheduledTimeMinutesMeta,
        scheduledTimeMinutes.isAcceptableOrUnknown(
          data['scheduled_time_minutes']!,
          _scheduledTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('deferred_from')) {
      context.handle(
        _deferredFromMeta,
        deferredFrom.isAcceptableOrUnknown(
          data['deferred_from']!,
          _deferredFromMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Todo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Todo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      status: $TodosTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      recurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_id'],
      ),
      autoDefer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_defer'],
      )!,
      scheduledTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_time_minutes'],
      ),
      deferredFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deferred_from'],
      ),
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TodoStatus, String, String> $converterstatus =
      const EnumNameConverter<TodoStatus>(TodoStatus.values);
}

class Todo extends DataClass implements Insertable<Todo> {
  final String id;
  final String title;
  final String? memo;
  final String date;
  final TodoStatus status;
  final int sortIndex;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? recurrenceId;
  final bool autoDefer;
  final int? scheduledTimeMinutes;

  /// 미루기용 — v1에서는 기록만 하고 사용하지 않음 (§15)
  final String? deferredFrom;
  const Todo({
    required this.id,
    required this.title,
    this.memo,
    required this.date,
    required this.status,
    required this.sortIndex,
    required this.createdAt,
    this.completedAt,
    this.recurrenceId,
    required this.autoDefer,
    this.scheduledTimeMinutes,
    this.deferredFrom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['date'] = Variable<String>(date);
    {
      map['status'] = Variable<String>(
        $TodosTable.$converterstatus.toSql(status),
      );
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || recurrenceId != null) {
      map['recurrence_id'] = Variable<String>(recurrenceId);
    }
    map['auto_defer'] = Variable<bool>(autoDefer);
    if (!nullToAbsent || scheduledTimeMinutes != null) {
      map['scheduled_time_minutes'] = Variable<int>(scheduledTimeMinutes);
    }
    if (!nullToAbsent || deferredFrom != null) {
      map['deferred_from'] = Variable<String>(deferredFrom);
    }
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      title: Value(title),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      date: Value(date),
      status: Value(status),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      recurrenceId: recurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceId),
      autoDefer: Value(autoDefer),
      scheduledTimeMinutes: scheduledTimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledTimeMinutes),
      deferredFrom: deferredFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(deferredFrom),
    );
  }

  factory Todo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Todo(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      memo: serializer.fromJson<String?>(json['memo']),
      date: serializer.fromJson<String>(json['date']),
      status: $TodosTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      recurrenceId: serializer.fromJson<String?>(json['recurrenceId']),
      autoDefer: serializer.fromJson<bool>(json['autoDefer']),
      scheduledTimeMinutes: serializer.fromJson<int?>(
        json['scheduledTimeMinutes'],
      ),
      deferredFrom: serializer.fromJson<String?>(json['deferredFrom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'memo': serializer.toJson<String?>(memo),
      'date': serializer.toJson<String>(date),
      'status': serializer.toJson<String>(
        $TodosTable.$converterstatus.toJson(status),
      ),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'recurrenceId': serializer.toJson<String?>(recurrenceId),
      'autoDefer': serializer.toJson<bool>(autoDefer),
      'scheduledTimeMinutes': serializer.toJson<int?>(scheduledTimeMinutes),
      'deferredFrom': serializer.toJson<String?>(deferredFrom),
    };
  }

  Todo copyWith({
    String? id,
    String? title,
    Value<String?> memo = const Value.absent(),
    String? date,
    TodoStatus? status,
    int? sortIndex,
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> recurrenceId = const Value.absent(),
    bool? autoDefer,
    Value<int?> scheduledTimeMinutes = const Value.absent(),
    Value<String?> deferredFrom = const Value.absent(),
  }) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    memo: memo.present ? memo.value : this.memo,
    date: date ?? this.date,
    status: status ?? this.status,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    recurrenceId: recurrenceId.present ? recurrenceId.value : this.recurrenceId,
    autoDefer: autoDefer ?? this.autoDefer,
    scheduledTimeMinutes: scheduledTimeMinutes.present
        ? scheduledTimeMinutes.value
        : this.scheduledTimeMinutes,
    deferredFrom: deferredFrom.present ? deferredFrom.value : this.deferredFrom,
  );
  Todo copyWithCompanion(TodosCompanion data) {
    return Todo(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      memo: data.memo.present ? data.memo.value : this.memo,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      recurrenceId: data.recurrenceId.present
          ? data.recurrenceId.value
          : this.recurrenceId,
      autoDefer: data.autoDefer.present ? data.autoDefer.value : this.autoDefer,
      scheduledTimeMinutes: data.scheduledTimeMinutes.present
          ? data.scheduledTimeMinutes.value
          : this.scheduledTimeMinutes,
      deferredFrom: data.deferredFrom.present
          ? data.deferredFrom.value
          : this.deferredFrom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Todo(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('recurrenceId: $recurrenceId, ')
          ..write('autoDefer: $autoDefer, ')
          ..write('scheduledTimeMinutes: $scheduledTimeMinutes, ')
          ..write('deferredFrom: $deferredFrom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    memo,
    date,
    status,
    sortIndex,
    createdAt,
    completedAt,
    recurrenceId,
    autoDefer,
    scheduledTimeMinutes,
    deferredFrom,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.id == this.id &&
          other.title == this.title &&
          other.memo == this.memo &&
          other.date == this.date &&
          other.status == this.status &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.recurrenceId == this.recurrenceId &&
          other.autoDefer == this.autoDefer &&
          other.scheduledTimeMinutes == this.scheduledTimeMinutes &&
          other.deferredFrom == this.deferredFrom);
}

class TodosCompanion extends UpdateCompanion<Todo> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> memo;
  final Value<String> date;
  final Value<TodoStatus> status;
  final Value<int> sortIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<String?> recurrenceId;
  final Value<bool> autoDefer;
  final Value<int?> scheduledTimeMinutes;
  final Value<String?> deferredFrom;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.recurrenceId = const Value.absent(),
    this.autoDefer = const Value.absent(),
    this.scheduledTimeMinutes = const Value.absent(),
    this.deferredFrom = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    required String title,
    this.memo = const Value.absent(),
    required String date,
    required TodoStatus status,
    required int sortIndex,
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.recurrenceId = const Value.absent(),
    this.autoDefer = const Value.absent(),
    this.scheduledTimeMinutes = const Value.absent(),
    this.deferredFrom = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       date = Value(date),
       status = Value(status),
       sortIndex = Value(sortIndex),
       createdAt = Value(createdAt);
  static Insertable<Todo> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? memo,
    Expression<String>? date,
    Expression<String>? status,
    Expression<int>? sortIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<String>? recurrenceId,
    Expression<bool>? autoDefer,
    Expression<int>? scheduledTimeMinutes,
    Expression<String>? deferredFrom,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (memo != null) 'memo': memo,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (recurrenceId != null) 'recurrence_id': recurrenceId,
      if (autoDefer != null) 'auto_defer': autoDefer,
      if (scheduledTimeMinutes != null)
        'scheduled_time_minutes': scheduledTimeMinutes,
      if (deferredFrom != null) 'deferred_from': deferredFrom,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? memo,
    Value<String>? date,
    Value<TodoStatus>? status,
    Value<int>? sortIndex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<String?>? recurrenceId,
    Value<bool>? autoDefer,
    Value<int?>? scheduledTimeMinutes,
    Value<String?>? deferredFrom,
    Value<int>? rowid,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      date: date ?? this.date,
      status: status ?? this.status,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      autoDefer: autoDefer ?? this.autoDefer,
      scheduledTimeMinutes: scheduledTimeMinutes ?? this.scheduledTimeMinutes,
      deferredFrom: deferredFrom ?? this.deferredFrom,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TodosTable.$converterstatus.toSql(status.value),
      );
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (recurrenceId.present) {
      map['recurrence_id'] = Variable<String>(recurrenceId.value);
    }
    if (autoDefer.present) {
      map['auto_defer'] = Variable<bool>(autoDefer.value);
    }
    if (scheduledTimeMinutes.present) {
      map['scheduled_time_minutes'] = Variable<int>(scheduledTimeMinutes.value);
    }
    if (deferredFrom.present) {
      map['deferred_from'] = Variable<String>(deferredFrom.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('recurrenceId: $recurrenceId, ')
          ..write('autoDefer: $autoDefer, ')
          ..write('scheduledTimeMinutes: $scheduledTimeMinutes, ')
          ..write('deferredFrom: $deferredFrom, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurrencesTable extends Recurrences
    with TableInfo<$RecurrencesTable, Recurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceRule, String> rule =
      GeneratedColumn<String>(
        'rule',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RecurrenceRule>($RecurrencesTable.$converterrule);
  static const VerificationMeta _weekdayMaskMeta = const VerificationMeta(
    'weekdayMask',
  );
  @override
  late final GeneratedColumn<int> weekdayMask = GeneratedColumn<int>(
    'weekday_mask',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledTimeMinutesMeta =
      const VerificationMeta('scheduledTimeMinutes');
  @override
  late final GeneratedColumn<int> scheduledTimeMinutes = GeneratedColumn<int>(
    'scheduled_time_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    memo,
    rule,
    weekdayMask,
    dayOfMonth,
    startDate,
    endDate,
    scheduledTimeMinutes,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recurrence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('weekday_mask')) {
      context.handle(
        _weekdayMaskMeta,
        weekdayMask.isAcceptableOrUnknown(
          data['weekday_mask']!,
          _weekdayMaskMeta,
        ),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('scheduled_time_minutes')) {
      context.handle(
        _scheduledTimeMinutesMeta,
        scheduledTimeMinutes.isAcceptableOrUnknown(
          data['scheduled_time_minutes']!,
          _scheduledTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Recurrence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recurrence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      rule: $RecurrencesTable.$converterrule.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rule'],
        )!,
      ),
      weekdayMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday_mask'],
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      scheduledTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_time_minutes'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $RecurrencesTable createAlias(String alias) {
    return $RecurrencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecurrenceRule, String, String> $converterrule =
      const EnumNameConverter<RecurrenceRule>(RecurrenceRule.values);
}

class Recurrence extends DataClass implements Insertable<Recurrence> {
  final String id;
  final String title;
  final String? memo;
  final RecurrenceRule rule;
  final int? weekdayMask;
  final int? dayOfMonth;
  final String startDate;
  final String? endDate;
  final int? scheduledTimeMinutes;
  final bool isActive;
  const Recurrence({
    required this.id,
    required this.title,
    this.memo,
    required this.rule,
    this.weekdayMask,
    this.dayOfMonth,
    required this.startDate,
    this.endDate,
    this.scheduledTimeMinutes,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    {
      map['rule'] = Variable<String>(
        $RecurrencesTable.$converterrule.toSql(rule),
      );
    }
    if (!nullToAbsent || weekdayMask != null) {
      map['weekday_mask'] = Variable<int>(weekdayMask);
    }
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    map['start_date'] = Variable<String>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    if (!nullToAbsent || scheduledTimeMinutes != null) {
      map['scheduled_time_minutes'] = Variable<int>(scheduledTimeMinutes);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  RecurrencesCompanion toCompanion(bool nullToAbsent) {
    return RecurrencesCompanion(
      id: Value(id),
      title: Value(title),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      rule: Value(rule),
      weekdayMask: weekdayMask == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdayMask),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      scheduledTimeMinutes: scheduledTimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledTimeMinutes),
      isActive: Value(isActive),
    );
  }

  factory Recurrence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recurrence(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      memo: serializer.fromJson<String?>(json['memo']),
      rule: $RecurrencesTable.$converterrule.fromJson(
        serializer.fromJson<String>(json['rule']),
      ),
      weekdayMask: serializer.fromJson<int?>(json['weekdayMask']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      scheduledTimeMinutes: serializer.fromJson<int?>(
        json['scheduledTimeMinutes'],
      ),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'memo': serializer.toJson<String?>(memo),
      'rule': serializer.toJson<String>(
        $RecurrencesTable.$converterrule.toJson(rule),
      ),
      'weekdayMask': serializer.toJson<int?>(weekdayMask),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String?>(endDate),
      'scheduledTimeMinutes': serializer.toJson<int?>(scheduledTimeMinutes),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Recurrence copyWith({
    String? id,
    String? title,
    Value<String?> memo = const Value.absent(),
    RecurrenceRule? rule,
    Value<int?> weekdayMask = const Value.absent(),
    Value<int?> dayOfMonth = const Value.absent(),
    String? startDate,
    Value<String?> endDate = const Value.absent(),
    Value<int?> scheduledTimeMinutes = const Value.absent(),
    bool? isActive,
  }) => Recurrence(
    id: id ?? this.id,
    title: title ?? this.title,
    memo: memo.present ? memo.value : this.memo,
    rule: rule ?? this.rule,
    weekdayMask: weekdayMask.present ? weekdayMask.value : this.weekdayMask,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    scheduledTimeMinutes: scheduledTimeMinutes.present
        ? scheduledTimeMinutes.value
        : this.scheduledTimeMinutes,
    isActive: isActive ?? this.isActive,
  );
  Recurrence copyWithCompanion(RecurrencesCompanion data) {
    return Recurrence(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      memo: data.memo.present ? data.memo.value : this.memo,
      rule: data.rule.present ? data.rule.value : this.rule,
      weekdayMask: data.weekdayMask.present
          ? data.weekdayMask.value
          : this.weekdayMask,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      scheduledTimeMinutes: data.scheduledTimeMinutes.present
          ? data.scheduledTimeMinutes.value
          : this.scheduledTimeMinutes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recurrence(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('rule: $rule, ')
          ..write('weekdayMask: $weekdayMask, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('scheduledTimeMinutes: $scheduledTimeMinutes, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    memo,
    rule,
    weekdayMask,
    dayOfMonth,
    startDate,
    endDate,
    scheduledTimeMinutes,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recurrence &&
          other.id == this.id &&
          other.title == this.title &&
          other.memo == this.memo &&
          other.rule == this.rule &&
          other.weekdayMask == this.weekdayMask &&
          other.dayOfMonth == this.dayOfMonth &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.scheduledTimeMinutes == this.scheduledTimeMinutes &&
          other.isActive == this.isActive);
}

class RecurrencesCompanion extends UpdateCompanion<Recurrence> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> memo;
  final Value<RecurrenceRule> rule;
  final Value<int?> weekdayMask;
  final Value<int?> dayOfMonth;
  final Value<String> startDate;
  final Value<String?> endDate;
  final Value<int?> scheduledTimeMinutes;
  final Value<bool> isActive;
  final Value<int> rowid;
  const RecurrencesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.rule = const Value.absent(),
    this.weekdayMask = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.scheduledTimeMinutes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurrencesCompanion.insert({
    required String id,
    required String title,
    this.memo = const Value.absent(),
    required RecurrenceRule rule,
    this.weekdayMask = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    required String startDate,
    this.endDate = const Value.absent(),
    this.scheduledTimeMinutes = const Value.absent(),
    required bool isActive,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       rule = Value(rule),
       startDate = Value(startDate),
       isActive = Value(isActive);
  static Insertable<Recurrence> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? memo,
    Expression<String>? rule,
    Expression<int>? weekdayMask,
    Expression<int>? dayOfMonth,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? scheduledTimeMinutes,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (memo != null) 'memo': memo,
      if (rule != null) 'rule': rule,
      if (weekdayMask != null) 'weekday_mask': weekdayMask,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (scheduledTimeMinutes != null)
        'scheduled_time_minutes': scheduledTimeMinutes,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurrencesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? memo,
    Value<RecurrenceRule>? rule,
    Value<int?>? weekdayMask,
    Value<int?>? dayOfMonth,
    Value<String>? startDate,
    Value<String?>? endDate,
    Value<int?>? scheduledTimeMinutes,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return RecurrencesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      rule: rule ?? this.rule,
      weekdayMask: weekdayMask ?? this.weekdayMask,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      scheduledTimeMinutes: scheduledTimeMinutes ?? this.scheduledTimeMinutes,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (rule.present) {
      map['rule'] = Variable<String>(
        $RecurrencesTable.$converterrule.toSql(rule.value),
      );
    }
    if (weekdayMask.present) {
      map['weekday_mask'] = Variable<int>(weekdayMask.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (scheduledTimeMinutes.present) {
      map['scheduled_time_minutes'] = Variable<int>(scheduledTimeMinutes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurrencesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('rule: $rule, ')
          ..write('weekdayMask: $weekdayMask, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('scheduledTimeMinutes: $scheduledTimeMinutes, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DaysTable extends Days with TableInfo<$DaysTable, Day> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peakProgressMeta = const VerificationMeta(
    'peakProgress',
  );
  @override
  late final GeneratedColumn<double> peakProgress = GeneratedColumn<double>(
    'peak_progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lightsOutAtMeta = const VerificationMeta(
    'lightsOutAt',
  );
  @override
  late final GeneratedColumn<DateTime> lightsOutAt = GeneratedColumn<DateTime>(
    'lights_out_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalTMeta = const VerificationMeta('finalT');
  @override
  late final GeneratedColumn<double> finalT = GeneratedColumn<double>(
    'final_t',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restlessMeta = const VerificationMeta(
    'restless',
  );
  @override
  late final GeneratedColumn<bool> restless = GeneratedColumn<bool>(
    'restless',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("restless" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    peakProgress,
    lightsOutAt,
    finalT,
    restless,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'days';
  @override
  VerificationContext validateIntegrity(
    Insertable<Day> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('peak_progress')) {
      context.handle(
        _peakProgressMeta,
        peakProgress.isAcceptableOrUnknown(
          data['peak_progress']!,
          _peakProgressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peakProgressMeta);
    }
    if (data.containsKey('lights_out_at')) {
      context.handle(
        _lightsOutAtMeta,
        lightsOutAt.isAcceptableOrUnknown(
          data['lights_out_at']!,
          _lightsOutAtMeta,
        ),
      );
    }
    if (data.containsKey('final_t')) {
      context.handle(
        _finalTMeta,
        finalT.isAcceptableOrUnknown(data['final_t']!, _finalTMeta),
      );
    }
    if (data.containsKey('restless')) {
      context.handle(
        _restlessMeta,
        restless.isAcceptableOrUnknown(data['restless']!, _restlessMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  Day map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Day(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      peakProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}peak_progress'],
      )!,
      lightsOutAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lights_out_at'],
      ),
      finalT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}final_t'],
      ),
      restless: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}restless'],
      )!,
    );
  }

  @override
  $DaysTable createAlias(String alias) {
    return $DaysTable(attachedDatabase, alias);
  }
}

class Day extends DataClass implements Insertable<Day> {
  final String date;

  /// 그날 도달한 최대 진행률 (§5.2 단조 감소 규칙의 영속화)
  final double peakProgress;

  /// 전등 줄을 당긴 시각
  final DateTime? lightsOutAt;

  /// 하루 종료 시점의 최종 조도 (주간 스트립·청구서용)
  final double? finalT;

  /// 불을 남긴 채 넘어간 밤 (세계관 2026-08-15): 미완 항목이 남아
  /// Lumi가 제대로 못 잔 날. 다음날 다크서클의 근거가 된다.
  /// 롤오버 봉인 시에만 기록한다 — autoDefer가 항목을 옮기기 전의 진실.
  final bool restless;
  const Day({
    required this.date,
    required this.peakProgress,
    this.lightsOutAt,
    this.finalT,
    required this.restless,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['peak_progress'] = Variable<double>(peakProgress);
    if (!nullToAbsent || lightsOutAt != null) {
      map['lights_out_at'] = Variable<DateTime>(lightsOutAt);
    }
    if (!nullToAbsent || finalT != null) {
      map['final_t'] = Variable<double>(finalT);
    }
    map['restless'] = Variable<bool>(restless);
    return map;
  }

  DaysCompanion toCompanion(bool nullToAbsent) {
    return DaysCompanion(
      date: Value(date),
      peakProgress: Value(peakProgress),
      lightsOutAt: lightsOutAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lightsOutAt),
      finalT: finalT == null && nullToAbsent
          ? const Value.absent()
          : Value(finalT),
      restless: Value(restless),
    );
  }

  factory Day.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Day(
      date: serializer.fromJson<String>(json['date']),
      peakProgress: serializer.fromJson<double>(json['peakProgress']),
      lightsOutAt: serializer.fromJson<DateTime?>(json['lightsOutAt']),
      finalT: serializer.fromJson<double?>(json['finalT']),
      restless: serializer.fromJson<bool>(json['restless']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'peakProgress': serializer.toJson<double>(peakProgress),
      'lightsOutAt': serializer.toJson<DateTime?>(lightsOutAt),
      'finalT': serializer.toJson<double?>(finalT),
      'restless': serializer.toJson<bool>(restless),
    };
  }

  Day copyWith({
    String? date,
    double? peakProgress,
    Value<DateTime?> lightsOutAt = const Value.absent(),
    Value<double?> finalT = const Value.absent(),
    bool? restless,
  }) => Day(
    date: date ?? this.date,
    peakProgress: peakProgress ?? this.peakProgress,
    lightsOutAt: lightsOutAt.present ? lightsOutAt.value : this.lightsOutAt,
    finalT: finalT.present ? finalT.value : this.finalT,
    restless: restless ?? this.restless,
  );
  Day copyWithCompanion(DaysCompanion data) {
    return Day(
      date: data.date.present ? data.date.value : this.date,
      peakProgress: data.peakProgress.present
          ? data.peakProgress.value
          : this.peakProgress,
      lightsOutAt: data.lightsOutAt.present
          ? data.lightsOutAt.value
          : this.lightsOutAt,
      finalT: data.finalT.present ? data.finalT.value : this.finalT,
      restless: data.restless.present ? data.restless.value : this.restless,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Day(')
          ..write('date: $date, ')
          ..write('peakProgress: $peakProgress, ')
          ..write('lightsOutAt: $lightsOutAt, ')
          ..write('finalT: $finalT, ')
          ..write('restless: $restless')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(date, peakProgress, lightsOutAt, finalT, restless);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Day &&
          other.date == this.date &&
          other.peakProgress == this.peakProgress &&
          other.lightsOutAt == this.lightsOutAt &&
          other.finalT == this.finalT &&
          other.restless == this.restless);
}

class DaysCompanion extends UpdateCompanion<Day> {
  final Value<String> date;
  final Value<double> peakProgress;
  final Value<DateTime?> lightsOutAt;
  final Value<double?> finalT;
  final Value<bool> restless;
  final Value<int> rowid;
  const DaysCompanion({
    this.date = const Value.absent(),
    this.peakProgress = const Value.absent(),
    this.lightsOutAt = const Value.absent(),
    this.finalT = const Value.absent(),
    this.restless = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DaysCompanion.insert({
    required String date,
    required double peakProgress,
    this.lightsOutAt = const Value.absent(),
    this.finalT = const Value.absent(),
    this.restless = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       peakProgress = Value(peakProgress);
  static Insertable<Day> custom({
    Expression<String>? date,
    Expression<double>? peakProgress,
    Expression<DateTime>? lightsOutAt,
    Expression<double>? finalT,
    Expression<bool>? restless,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (peakProgress != null) 'peak_progress': peakProgress,
      if (lightsOutAt != null) 'lights_out_at': lightsOutAt,
      if (finalT != null) 'final_t': finalT,
      if (restless != null) 'restless': restless,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DaysCompanion copyWith({
    Value<String>? date,
    Value<double>? peakProgress,
    Value<DateTime?>? lightsOutAt,
    Value<double?>? finalT,
    Value<bool>? restless,
    Value<int>? rowid,
  }) {
    return DaysCompanion(
      date: date ?? this.date,
      peakProgress: peakProgress ?? this.peakProgress,
      lightsOutAt: lightsOutAt ?? this.lightsOutAt,
      finalT: finalT ?? this.finalT,
      restless: restless ?? this.restless,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (peakProgress.present) {
      map['peak_progress'] = Variable<double>(peakProgress.value);
    }
    if (lightsOutAt.present) {
      map['lights_out_at'] = Variable<DateTime>(lightsOutAt.value);
    }
    if (finalT.present) {
      map['final_t'] = Variable<double>(finalT.value);
    }
    if (restless.present) {
      map['restless'] = Variable<bool>(restless.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaysCompanion(')
          ..write('date: $date, ')
          ..write('peakProgress: $peakProgress, ')
          ..write('lightsOutAt: $lightsOutAt, ')
          ..write('finalT: $finalT, ')
          ..write('restless: $restless, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyBillsTable extends WeeklyBills
    with TableInfo<$WeeklyBillsTable, WeeklyBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyBillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<String> weekStart = GeneratedColumn<String>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kwhMeta = const VerificationMeta('kwh');
  @override
  late final GeneratedColumn<double> kwh = GeneratedColumn<double>(
    'kwh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sleepMinutesMeta = const VerificationMeta(
    'sleepMinutes',
  );
  @override
  late final GeneratedColumn<int> sleepMinutes = GeneratedColumn<int>(
    'sleep_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    weekStart,
    kwh,
    amount,
    sleepMinutes,
    generatedAt,
    isRead,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('kwh')) {
      context.handle(
        _kwhMeta,
        kwh.isAcceptableOrUnknown(data['kwh']!, _kwhMeta),
      );
    } else if (isInserting) {
      context.missing(_kwhMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('sleep_minutes')) {
      context.handle(
        _sleepMinutesMeta,
        sleepMinutes.isAcceptableOrUnknown(
          data['sleep_minutes']!,
          _sleepMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sleepMinutesMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    } else if (isInserting) {
      context.missing(_isReadMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {weekStart};
  @override
  WeeklyBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyBill(
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}week_start'],
      )!,
      kwh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kwh'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      sleepMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sleep_minutes'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $WeeklyBillsTable createAlias(String alias) {
    return $WeeklyBillsTable(attachedDatabase, alias);
  }
}

class WeeklyBill extends DataClass implements Insertable<WeeklyBill> {
  final String weekStart;
  final double kwh;
  final int amount;
  final int sleepMinutes;
  final DateTime generatedAt;
  final bool isRead;
  final String payload;
  const WeeklyBill({
    required this.weekStart,
    required this.kwh,
    required this.amount,
    required this.sleepMinutes,
    required this.generatedAt,
    required this.isRead,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['week_start'] = Variable<String>(weekStart);
    map['kwh'] = Variable<double>(kwh);
    map['amount'] = Variable<int>(amount);
    map['sleep_minutes'] = Variable<int>(sleepMinutes);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['is_read'] = Variable<bool>(isRead);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  WeeklyBillsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyBillsCompanion(
      weekStart: Value(weekStart),
      kwh: Value(kwh),
      amount: Value(amount),
      sleepMinutes: Value(sleepMinutes),
      generatedAt: Value(generatedAt),
      isRead: Value(isRead),
      payload: Value(payload),
    );
  }

  factory WeeklyBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyBill(
      weekStart: serializer.fromJson<String>(json['weekStart']),
      kwh: serializer.fromJson<double>(json['kwh']),
      amount: serializer.fromJson<int>(json['amount']),
      sleepMinutes: serializer.fromJson<int>(json['sleepMinutes']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'weekStart': serializer.toJson<String>(weekStart),
      'kwh': serializer.toJson<double>(kwh),
      'amount': serializer.toJson<int>(amount),
      'sleepMinutes': serializer.toJson<int>(sleepMinutes),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'isRead': serializer.toJson<bool>(isRead),
      'payload': serializer.toJson<String>(payload),
    };
  }

  WeeklyBill copyWith({
    String? weekStart,
    double? kwh,
    int? amount,
    int? sleepMinutes,
    DateTime? generatedAt,
    bool? isRead,
    String? payload,
  }) => WeeklyBill(
    weekStart: weekStart ?? this.weekStart,
    kwh: kwh ?? this.kwh,
    amount: amount ?? this.amount,
    sleepMinutes: sleepMinutes ?? this.sleepMinutes,
    generatedAt: generatedAt ?? this.generatedAt,
    isRead: isRead ?? this.isRead,
    payload: payload ?? this.payload,
  );
  WeeklyBill copyWithCompanion(WeeklyBillsCompanion data) {
    return WeeklyBill(
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      kwh: data.kwh.present ? data.kwh.value : this.kwh,
      amount: data.amount.present ? data.amount.value : this.amount,
      sleepMinutes: data.sleepMinutes.present
          ? data.sleepMinutes.value
          : this.sleepMinutes,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyBill(')
          ..write('weekStart: $weekStart, ')
          ..write('kwh: $kwh, ')
          ..write('amount: $amount, ')
          ..write('sleepMinutes: $sleepMinutes, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('isRead: $isRead, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    weekStart,
    kwh,
    amount,
    sleepMinutes,
    generatedAt,
    isRead,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyBill &&
          other.weekStart == this.weekStart &&
          other.kwh == this.kwh &&
          other.amount == this.amount &&
          other.sleepMinutes == this.sleepMinutes &&
          other.generatedAt == this.generatedAt &&
          other.isRead == this.isRead &&
          other.payload == this.payload);
}

class WeeklyBillsCompanion extends UpdateCompanion<WeeklyBill> {
  final Value<String> weekStart;
  final Value<double> kwh;
  final Value<int> amount;
  final Value<int> sleepMinutes;
  final Value<DateTime> generatedAt;
  final Value<bool> isRead;
  final Value<String> payload;
  final Value<int> rowid;
  const WeeklyBillsCompanion({
    this.weekStart = const Value.absent(),
    this.kwh = const Value.absent(),
    this.amount = const Value.absent(),
    this.sleepMinutes = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyBillsCompanion.insert({
    required String weekStart,
    required double kwh,
    required int amount,
    required int sleepMinutes,
    required DateTime generatedAt,
    required bool isRead,
    required String payload,
    this.rowid = const Value.absent(),
  }) : weekStart = Value(weekStart),
       kwh = Value(kwh),
       amount = Value(amount),
       sleepMinutes = Value(sleepMinutes),
       generatedAt = Value(generatedAt),
       isRead = Value(isRead),
       payload = Value(payload);
  static Insertable<WeeklyBill> custom({
    Expression<String>? weekStart,
    Expression<double>? kwh,
    Expression<int>? amount,
    Expression<int>? sleepMinutes,
    Expression<DateTime>? generatedAt,
    Expression<bool>? isRead,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (weekStart != null) 'week_start': weekStart,
      if (kwh != null) 'kwh': kwh,
      if (amount != null) 'amount': amount,
      if (sleepMinutes != null) 'sleep_minutes': sleepMinutes,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (isRead != null) 'is_read': isRead,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyBillsCompanion copyWith({
    Value<String>? weekStart,
    Value<double>? kwh,
    Value<int>? amount,
    Value<int>? sleepMinutes,
    Value<DateTime>? generatedAt,
    Value<bool>? isRead,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return WeeklyBillsCompanion(
      weekStart: weekStart ?? this.weekStart,
      kwh: kwh ?? this.kwh,
      amount: amount ?? this.amount,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      generatedAt: generatedAt ?? this.generatedAt,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (weekStart.present) {
      map['week_start'] = Variable<String>(weekStart.value);
    }
    if (kwh.present) {
      map['kwh'] = Variable<double>(kwh.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (sleepMinutes.present) {
      map['sleep_minutes'] = Variable<int>(sleepMinutes.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyBillsCompanion(')
          ..write('weekStart: $weekStart, ')
          ..write('kwh: $kwh, ')
          ..write('amount: $amount, ')
          ..write('sleepMinutes: $sleepMinutes, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('isRead: $isRead, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$UnwindDatabase extends GeneratedDatabase {
  _$UnwindDatabase(QueryExecutor e) : super(e);
  $UnwindDatabaseManager get managers => $UnwindDatabaseManager(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $RecurrencesTable recurrences = $RecurrencesTable(this);
  late final $DaysTable days = $DaysTable(this);
  late final $WeeklyBillsTable weeklyBills = $WeeklyBillsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxTodosDateSort = Index(
    'idx_todos_date_sort',
    'CREATE INDEX idx_todos_date_sort ON todos (date, sort_index)',
  );
  late final Index idxTodosRecurrenceDate = Index(
    'idx_todos_recurrence_date',
    'CREATE UNIQUE INDEX idx_todos_recurrence_date ON todos (recurrence_id, date)',
  );
  late final TodoDao todoDao = TodoDao(this as UnwindDatabase);
  late final DayDao dayDao = DayDao(this as UnwindDatabase);
  late final RecurrenceDao recurrenceDao = RecurrenceDao(
    this as UnwindDatabase,
  );
  late final BillDao billDao = BillDao(this as UnwindDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as UnwindDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    todos,
    recurrences,
    days,
    weeklyBills,
    settings,
    idxTodosDateSort,
    idxTodosRecurrenceDate,
  ];
}

typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      required String id,
      required String title,
      Value<String?> memo,
      required String date,
      required TodoStatus status,
      required int sortIndex,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
      Value<String?> recurrenceId,
      Value<bool> autoDefer,
      Value<int?> scheduledTimeMinutes,
      Value<String?> deferredFrom,
      Value<int> rowid,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> memo,
      Value<String> date,
      Value<TodoStatus> status,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<String?> recurrenceId,
      Value<bool> autoDefer,
      Value<int?> scheduledTimeMinutes,
      Value<String?> deferredFrom,
      Value<int> rowid,
    });

class $$TodosTableFilterComposer
    extends Composer<_$UnwindDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TodoStatus, TodoStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoDefer => $composableBuilder(
    column: $table.autoDefer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledTimeMinutes => $composableBuilder(
    column: $table.scheduledTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deferredFrom => $composableBuilder(
    column: $table.deferredFrom,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodosTableOrderingComposer
    extends Composer<_$UnwindDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoDefer => $composableBuilder(
    column: $table.autoDefer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledTimeMinutes => $composableBuilder(
    column: $table.scheduledTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deferredFrom => $composableBuilder(
    column: $table.deferredFrom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosTableAnnotationComposer
    extends Composer<_$UnwindDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TodoStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoDefer =>
      $composableBuilder(column: $table.autoDefer, builder: (column) => column);

  GeneratedColumn<int> get scheduledTimeMinutes => $composableBuilder(
    column: $table.scheduledTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deferredFrom => $composableBuilder(
    column: $table.deferredFrom,
    builder: (column) => column,
  );
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$UnwindDatabase,
          $TodosTable,
          Todo,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (Todo, BaseReferences<_$UnwindDatabase, $TodosTable, Todo>),
          Todo,
          PrefetchHooks Function()
        > {
  $$TodosTableTableManager(_$UnwindDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<TodoStatus> status = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> recurrenceId = const Value.absent(),
                Value<bool> autoDefer = const Value.absent(),
                Value<int?> scheduledTimeMinutes = const Value.absent(),
                Value<String?> deferredFrom = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                title: title,
                memo: memo,
                date: date,
                status: status,
                sortIndex: sortIndex,
                createdAt: createdAt,
                completedAt: completedAt,
                recurrenceId: recurrenceId,
                autoDefer: autoDefer,
                scheduledTimeMinutes: scheduledTimeMinutes,
                deferredFrom: deferredFrom,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> memo = const Value.absent(),
                required String date,
                required TodoStatus status,
                required int sortIndex,
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> recurrenceId = const Value.absent(),
                Value<bool> autoDefer = const Value.absent(),
                Value<int?> scheduledTimeMinutes = const Value.absent(),
                Value<String?> deferredFrom = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                title: title,
                memo: memo,
                date: date,
                status: status,
                sortIndex: sortIndex,
                createdAt: createdAt,
                completedAt: completedAt,
                recurrenceId: recurrenceId,
                autoDefer: autoDefer,
                scheduledTimeMinutes: scheduledTimeMinutes,
                deferredFrom: deferredFrom,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$UnwindDatabase,
      $TodosTable,
      Todo,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (Todo, BaseReferences<_$UnwindDatabase, $TodosTable, Todo>),
      Todo,
      PrefetchHooks Function()
    >;
typedef $$RecurrencesTableCreateCompanionBuilder =
    RecurrencesCompanion Function({
      required String id,
      required String title,
      Value<String?> memo,
      required RecurrenceRule rule,
      Value<int?> weekdayMask,
      Value<int?> dayOfMonth,
      required String startDate,
      Value<String?> endDate,
      Value<int?> scheduledTimeMinutes,
      required bool isActive,
      Value<int> rowid,
    });
typedef $$RecurrencesTableUpdateCompanionBuilder =
    RecurrencesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> memo,
      Value<RecurrenceRule> rule,
      Value<int?> weekdayMask,
      Value<int?> dayOfMonth,
      Value<String> startDate,
      Value<String?> endDate,
      Value<int?> scheduledTimeMinutes,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$RecurrencesTableFilterComposer
    extends Composer<_$UnwindDatabase, $RecurrencesTable> {
  $$RecurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecurrenceRule, RecurrenceRule, String>
  get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get weekdayMask => $composableBuilder(
    column: $table.weekdayMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledTimeMinutes => $composableBuilder(
    column: $table.scheduledTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurrencesTableOrderingComposer
    extends Composer<_$UnwindDatabase, $RecurrencesTable> {
  $$RecurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdayMask => $composableBuilder(
    column: $table.weekdayMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledTimeMinutes => $composableBuilder(
    column: $table.scheduledTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurrencesTableAnnotationComposer
    extends Composer<_$UnwindDatabase, $RecurrencesTable> {
  $$RecurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecurrenceRule, String> get rule =>
      $composableBuilder(column: $table.rule, builder: (column) => column);

  GeneratedColumn<int> get weekdayMask => $composableBuilder(
    column: $table.weekdayMask,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get scheduledTimeMinutes => $composableBuilder(
    column: $table.scheduledTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$RecurrencesTableTableManager
    extends
        RootTableManager<
          _$UnwindDatabase,
          $RecurrencesTable,
          Recurrence,
          $$RecurrencesTableFilterComposer,
          $$RecurrencesTableOrderingComposer,
          $$RecurrencesTableAnnotationComposer,
          $$RecurrencesTableCreateCompanionBuilder,
          $$RecurrencesTableUpdateCompanionBuilder,
          (
            Recurrence,
            BaseReferences<_$UnwindDatabase, $RecurrencesTable, Recurrence>,
          ),
          Recurrence,
          PrefetchHooks Function()
        > {
  $$RecurrencesTableTableManager(_$UnwindDatabase db, $RecurrencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurrencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurrencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<RecurrenceRule> rule = const Value.absent(),
                Value<int?> weekdayMask = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<int?> scheduledTimeMinutes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurrencesCompanion(
                id: id,
                title: title,
                memo: memo,
                rule: rule,
                weekdayMask: weekdayMask,
                dayOfMonth: dayOfMonth,
                startDate: startDate,
                endDate: endDate,
                scheduledTimeMinutes: scheduledTimeMinutes,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> memo = const Value.absent(),
                required RecurrenceRule rule,
                Value<int?> weekdayMask = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                required String startDate,
                Value<String?> endDate = const Value.absent(),
                Value<int?> scheduledTimeMinutes = const Value.absent(),
                required bool isActive,
                Value<int> rowid = const Value.absent(),
              }) => RecurrencesCompanion.insert(
                id: id,
                title: title,
                memo: memo,
                rule: rule,
                weekdayMask: weekdayMask,
                dayOfMonth: dayOfMonth,
                startDate: startDate,
                endDate: endDate,
                scheduledTimeMinutes: scheduledTimeMinutes,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$UnwindDatabase,
      $RecurrencesTable,
      Recurrence,
      $$RecurrencesTableFilterComposer,
      $$RecurrencesTableOrderingComposer,
      $$RecurrencesTableAnnotationComposer,
      $$RecurrencesTableCreateCompanionBuilder,
      $$RecurrencesTableUpdateCompanionBuilder,
      (
        Recurrence,
        BaseReferences<_$UnwindDatabase, $RecurrencesTable, Recurrence>,
      ),
      Recurrence,
      PrefetchHooks Function()
    >;
typedef $$DaysTableCreateCompanionBuilder =
    DaysCompanion Function({
      required String date,
      required double peakProgress,
      Value<DateTime?> lightsOutAt,
      Value<double?> finalT,
      Value<bool> restless,
      Value<int> rowid,
    });
typedef $$DaysTableUpdateCompanionBuilder =
    DaysCompanion Function({
      Value<String> date,
      Value<double> peakProgress,
      Value<DateTime?> lightsOutAt,
      Value<double?> finalT,
      Value<bool> restless,
      Value<int> rowid,
    });

class $$DaysTableFilterComposer extends Composer<_$UnwindDatabase, $DaysTable> {
  $$DaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get peakProgress => $composableBuilder(
    column: $table.peakProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lightsOutAt => $composableBuilder(
    column: $table.lightsOutAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get finalT => $composableBuilder(
    column: $table.finalT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get restless => $composableBuilder(
    column: $table.restless,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaysTableOrderingComposer
    extends Composer<_$UnwindDatabase, $DaysTable> {
  $$DaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get peakProgress => $composableBuilder(
    column: $table.peakProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lightsOutAt => $composableBuilder(
    column: $table.lightsOutAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get finalT => $composableBuilder(
    column: $table.finalT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get restless => $composableBuilder(
    column: $table.restless,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaysTableAnnotationComposer
    extends Composer<_$UnwindDatabase, $DaysTable> {
  $$DaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get peakProgress => $composableBuilder(
    column: $table.peakProgress,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lightsOutAt => $composableBuilder(
    column: $table.lightsOutAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get finalT =>
      $composableBuilder(column: $table.finalT, builder: (column) => column);

  GeneratedColumn<bool> get restless =>
      $composableBuilder(column: $table.restless, builder: (column) => column);
}

class $$DaysTableTableManager
    extends
        RootTableManager<
          _$UnwindDatabase,
          $DaysTable,
          Day,
          $$DaysTableFilterComposer,
          $$DaysTableOrderingComposer,
          $$DaysTableAnnotationComposer,
          $$DaysTableCreateCompanionBuilder,
          $$DaysTableUpdateCompanionBuilder,
          (Day, BaseReferences<_$UnwindDatabase, $DaysTable, Day>),
          Day,
          PrefetchHooks Function()
        > {
  $$DaysTableTableManager(_$UnwindDatabase db, $DaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<double> peakProgress = const Value.absent(),
                Value<DateTime?> lightsOutAt = const Value.absent(),
                Value<double?> finalT = const Value.absent(),
                Value<bool> restless = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion(
                date: date,
                peakProgress: peakProgress,
                lightsOutAt: lightsOutAt,
                finalT: finalT,
                restless: restless,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required double peakProgress,
                Value<DateTime?> lightsOutAt = const Value.absent(),
                Value<double?> finalT = const Value.absent(),
                Value<bool> restless = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion.insert(
                date: date,
                peakProgress: peakProgress,
                lightsOutAt: lightsOutAt,
                finalT: finalT,
                restless: restless,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaysTableProcessedTableManager =
    ProcessedTableManager<
      _$UnwindDatabase,
      $DaysTable,
      Day,
      $$DaysTableFilterComposer,
      $$DaysTableOrderingComposer,
      $$DaysTableAnnotationComposer,
      $$DaysTableCreateCompanionBuilder,
      $$DaysTableUpdateCompanionBuilder,
      (Day, BaseReferences<_$UnwindDatabase, $DaysTable, Day>),
      Day,
      PrefetchHooks Function()
    >;
typedef $$WeeklyBillsTableCreateCompanionBuilder =
    WeeklyBillsCompanion Function({
      required String weekStart,
      required double kwh,
      required int amount,
      required int sleepMinutes,
      required DateTime generatedAt,
      required bool isRead,
      required String payload,
      Value<int> rowid,
    });
typedef $$WeeklyBillsTableUpdateCompanionBuilder =
    WeeklyBillsCompanion Function({
      Value<String> weekStart,
      Value<double> kwh,
      Value<int> amount,
      Value<int> sleepMinutes,
      Value<DateTime> generatedAt,
      Value<bool> isRead,
      Value<String> payload,
      Value<int> rowid,
    });

class $$WeeklyBillsTableFilterComposer
    extends Composer<_$UnwindDatabase, $WeeklyBillsTable> {
  $$WeeklyBillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kwh => $composableBuilder(
    column: $table.kwh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sleepMinutes => $composableBuilder(
    column: $table.sleepMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyBillsTableOrderingComposer
    extends Composer<_$UnwindDatabase, $WeeklyBillsTable> {
  $$WeeklyBillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kwh => $composableBuilder(
    column: $table.kwh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sleepMinutes => $composableBuilder(
    column: $table.sleepMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyBillsTableAnnotationComposer
    extends Composer<_$UnwindDatabase, $WeeklyBillsTable> {
  $$WeeklyBillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<double> get kwh =>
      $composableBuilder(column: $table.kwh, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get sleepMinutes => $composableBuilder(
    column: $table.sleepMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$WeeklyBillsTableTableManager
    extends
        RootTableManager<
          _$UnwindDatabase,
          $WeeklyBillsTable,
          WeeklyBill,
          $$WeeklyBillsTableFilterComposer,
          $$WeeklyBillsTableOrderingComposer,
          $$WeeklyBillsTableAnnotationComposer,
          $$WeeklyBillsTableCreateCompanionBuilder,
          $$WeeklyBillsTableUpdateCompanionBuilder,
          (
            WeeklyBill,
            BaseReferences<_$UnwindDatabase, $WeeklyBillsTable, WeeklyBill>,
          ),
          WeeklyBill,
          PrefetchHooks Function()
        > {
  $$WeeklyBillsTableTableManager(_$UnwindDatabase db, $WeeklyBillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyBillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyBillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyBillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> weekStart = const Value.absent(),
                Value<double> kwh = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> sleepMinutes = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyBillsCompanion(
                weekStart: weekStart,
                kwh: kwh,
                amount: amount,
                sleepMinutes: sleepMinutes,
                generatedAt: generatedAt,
                isRead: isRead,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String weekStart,
                required double kwh,
                required int amount,
                required int sleepMinutes,
                required DateTime generatedAt,
                required bool isRead,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => WeeklyBillsCompanion.insert(
                weekStart: weekStart,
                kwh: kwh,
                amount: amount,
                sleepMinutes: sleepMinutes,
                generatedAt: generatedAt,
                isRead: isRead,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyBillsTableProcessedTableManager =
    ProcessedTableManager<
      _$UnwindDatabase,
      $WeeklyBillsTable,
      WeeklyBill,
      $$WeeklyBillsTableFilterComposer,
      $$WeeklyBillsTableOrderingComposer,
      $$WeeklyBillsTableAnnotationComposer,
      $$WeeklyBillsTableCreateCompanionBuilder,
      $$WeeklyBillsTableUpdateCompanionBuilder,
      (
        WeeklyBill,
        BaseReferences<_$UnwindDatabase, $WeeklyBillsTable, WeeklyBill>,
      ),
      WeeklyBill,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$UnwindDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$UnwindDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$UnwindDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$UnwindDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$UnwindDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$UnwindDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$UnwindDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$UnwindDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $UnwindDatabaseManager {
  final _$UnwindDatabase _db;
  $UnwindDatabaseManager(this._db);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$RecurrencesTableTableManager get recurrences =>
      $$RecurrencesTableTableManager(_db, _db.recurrences);
  $$DaysTableTableManager get days => $$DaysTableTableManager(_db, _db.days);
  $$WeeklyBillsTableTableManager get weeklyBills =>
      $$WeeklyBillsTableTableManager(_db, _db.weeklyBills);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
