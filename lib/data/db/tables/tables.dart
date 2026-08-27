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

  /// 불을 남긴 채 넘어간 밤 (세계관 2026-08-15): 미완 항목이 남아
  /// Todd가 제대로 못 잔 날. 다음날 다크서클의 근거가 된다.
  /// 롤오버 봉인 시에만 기록한다 — autoDefer가 항목을 옮기기 전의 진실.
  BoolColumn get restless => boolean().withDefault(const Constant(false))();

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
  static const billNotificationEnabled = 'billNotificationEnabled';
  static const morningGreetingEnabled = 'morningGreetingEnabled';
  static const todoReminderEnabled = 'todoReminderEnabled';
  static const hapticsEnabled = 'hapticsEnabled'; // 기본 true
  static const onboardingCompleted = 'onboardingCompleted';

  /// Todd 기상시간 = 하루의 경계 (세계관 통합 2026-08-15, 기본 5).
  /// 이 시각 전까지는 어제의 방이다.
  static const wakeHour = 'wakeHour';

  /// Todd 취침시간 (기본 22). 이 시각부터 Todd는 자고 싶어하고,
  /// 취침 알림(nightReminderEnabled)은 이 시각 30분 전에 발송한다.
  static const bedtimeHour = 'bedtimeHour';

  /// 유저 기상시간 (온보딩에서 받음). 없으면 Todd 기상 +1h 로 표시.
  static const userWakeHour = 'userWakeHour';

  /// 유저 취침시간 (온보딩에서 받음). 없으면 Todd 취침 +1h 로 표시.
  static const userBedtimeHour = 'userBedtimeHour';

  /// Todd가 부르는 사용자 이름 (온보딩 2026-08-15). 없을 수 있다.
  static const userName = 'userName';

  static const languageCode = 'languageCode'; // 기본 'en'

  /// 방 조명의 색 (선택형 2026-08-22) — UnwindLightColor.name, 기본 'amber'
  static const lightColor = 'lightColor';

  /// Todd Plus (수익화 2026-08-22). TODO(unwind): StoreKit 연동 시
  /// 영수증 검증으로 대체 — 지금은 페이월 CTA가 직접 켠다 (테스트용).
  static const premiumEnabled = 'premiumEnabled';

  /// 온보딩 직후 전등 줄 코치마크를 아직 기다림
  static const pullCordCoachAwaiting = 'pullCordCoachAwaiting';

  /// 전등 줄 코치마크를 이미 보여 줬음 (최초 1회)
  static const pullCordCoachShown = 'pullCordCoachShown';

  /// 위젯 설치 넛지 처리 완료 (2026-08-27) — 첫 To-do 저장 때 위젯이
  /// 없으면 5분 뒤 설치 안내 푸시를 예약하고 이 플래그를 세운다 (1회성).
  /// 위젯이 이미 있었으면 예약 없이 세운다. 조회 실패면 세우지 않아
  /// 다음 저장 때 재시도한다.
  static const widgetNudgeDone = 'widgetNudgeDone';
  // dayStartHour는 2026-08-15에 wakeHour로 통합됐다 (읽기 폴백만 유지).
  // nightReminderTime은 취침시간과 통합돼 제거됐다.
  // weekViewOpen은 2026-08-13에 제거됐다 — 주간 뷰가 오버레이 토글에서
  // 라우트로 바뀌면서 열림 상태를 영속할 이유가 사라졌다.
  static const legacyDayStartHour = 'dayStartHour';
}
