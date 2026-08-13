import 'package:drift/drift.dart';

/// §4.1 todos — 할 일 = 등 하나
/// DATE 컬럼은 'yyyy-MM-dd' 로컬 문자열.
enum TodoStatus { pending, done, deferred }

@TableIndex(name: 'idx_todos_date_sort', columns: {#date, #sortIndex})
@TableIndex(
  name: 'idx_todos_recurrence_date',
  columns: {#recurrenceId, #date},
  unique: true,
) // 반복 인스턴스 중복 방지
class Todos extends Table {
  TextColumn get id => text()(); // uuid v4
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get memo => text().nullable()(); // 최대 2000자 — UI에서 제한
  TextColumn get date => text()();
  TextColumn get status => textEnum<TodoStatus>()();
  IntColumn get sortIndex => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get recurrenceId => text().nullable()();
  BoolColumn get autoDefer => boolean().withDefault(const Constant(false))();
  IntColumn get scheduledTimeMinutes => integer().nullable()();

  /// 미루기용 — v1에서는 기록만 하고 사용하지 않음 (§15)
  TextColumn get deferredFrom => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (scheduled_time_minutes IS NULL '
        'OR scheduled_time_minutes BETWEEN 0 AND 1439)',
  ];
}

/// §4.2 recurrences — 반복 규칙
enum RecurrenceRule { daily, weekdays, weekly, monthly }

class Recurrences extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get memo => text().nullable()();
  TextColumn get rule => textEnum<RecurrenceRule>()();
  IntColumn get weekdayMask => integer().nullable()(); // 월=1 … 일=64
  IntColumn get dayOfMonth => integer().nullable()(); // 1~31
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()(); // null이면 무기한
  IntColumn get scheduledTimeMinutes => integer().nullable()();
  BoolColumn get isActive => boolean()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (scheduled_time_minutes IS NULL '
        'OR scheduled_time_minutes BETWEEN 0 AND 1439)',
  ];
}

/// §4.3 days — 하루의 기록
class Days extends Table {
  TextColumn get date => text()();

  /// 그날 도달한 최대 진행률 (§5.2 단조 감소 규칙의 영속화)
  RealColumn get peakProgress => real()();

  /// 전등 줄을 당긴 시각
  DateTimeColumn get lightsOutAt => dateTime().nullable()();

  /// 하루 종료 시점의 최종 조도 (주간 스트립·청구서용)
  RealColumn get finalT => real().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}

/// §4.4 weekly_bills — 주간 청구서 (M3에서 사용)
class WeeklyBills extends Table {
  TextColumn get weekStart => text()(); // 월요일
  RealColumn get kwh => real()();
  IntColumn get amount => integer()(); // 원 단위, 10원 반올림
  IntColumn get sleepMinutes => integer()();
  DateTimeColumn get generatedAt => dateTime()();
  BoolColumn get isRead => boolean()();
  TextColumn get payload => text()(); // 일별 상세 JSON

  @override
  Set<Column> get primaryKey => {weekStart};
}

/// §4.5 settings — 키/값
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 설정 키 상수 (§4.5)
abstract final class SettingKeys {
  static const nightReminderEnabled = 'nightReminderEnabled';
  static const nightReminderTime = 'nightReminderTime'; // 기본 22:00
  static const billNotificationEnabled = 'billNotificationEnabled';
  static const soundEnabled = 'soundEnabled'; // 기본 true
  static const hapticsEnabled = 'hapticsEnabled'; // 기본 true
  static const onboardingCompleted = 'onboardingCompleted';
  static const dayStartHour = 'dayStartHour'; // 기본 6
  static const languageCode = 'languageCode'; // 기본 'en'
  // weekViewOpen은 2026-08-13에 제거됐다 — 주간 뷰가 오버레이 토글에서
  // 라우트로 바뀌면서 열림 상태를 영속할 이유가 사라졌다.
}
