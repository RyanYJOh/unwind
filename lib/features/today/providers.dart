import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/haptics.dart';
import '../../core/sound/sound_player.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/repositories/todo_repository.dart';
import '../../domain/models/lumi_state.dart';
import '../../domain/services/brightness_engine.dart';
import '../../domain/services/day_rollover_service.dart';
import '../../domain/services/notification_service.dart';
import '../../domain/services/recurrence_expander.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/settings_controller.dart';

/// DB — 앱 전역 단일 인스턴스 (§3.2 단일 진실 공급원)
final databaseProvider = Provider<UnwindDatabase>((ref) {
  final db = UnwindDatabase();
  ref.onDispose(db.close);
  return db;
});

final todoRepositoryProvider = Provider<TodoRepository>(
  (ref) => TodoRepository(ref.watch(databaseProvider)),
);

final billRepositoryProvider = Provider<BillRepository>(
  (ref) => BillRepository(ref.watch(databaseProvider)),
);

/// §6.5 미확인 청구서 — 홈 상단 배지
final unreadBillsProvider = StreamProvider<List<WeeklyBill>>(
  (ref) => ref.watch(billRepositoryProvider).watchUnread(),
);

final hapticsProvider = Provider<UnwindHaptics>((ref) {
  final h = UnwindHaptics();
  // §6.7 햅틱 on/off 연동
  ref.listen(settingsControllerProvider, (prev, next) {
    h.enabled = next.value?.hapticsEnabled ?? true;
  }, fireImmediately: true);
  return h;
});

final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final p = SoundPlayer();
  p.init();
  // §6.7 사운드 on/off 연동
  ref.listen(settingsControllerProvider, (prev, next) {
    p.enabled = next.value?.soundEnabled ?? true;
  }, fireImmediately: true);
  ref.onDispose(p.dispose);
  return p;
});

/// Lumi 기상시간 = 하루의 경계 (세계관 통합 2026-08-15), 기본 05시.
/// Lumi가 일어나는 순간 새 하루가 시작된다 — 롤오버·반복 전개·청구서
/// 생성이 전부 이 시각에 일어난다.
final wakeHourProvider = Provider<int>(
  (ref) => ref.watch(settingsControllerProvider).value?.wakeHour ?? 5,
);

/// Lumi 취침시간 (세계관 2026-08-15), 기본 22시.
/// 이 시각부터 Lumi는 자야 한다 — 불(미완 항목)이 남아 있으면 못 자고,
/// 취침 알림도 이 시각에 발송한다.
final bedtimeHourProvider = Provider<int>(
  (ref) => ref.watch(settingsControllerProvider).value?.bedtimeHour ?? 22,
);

final recurrenceExpanderProvider = Provider<RecurrenceExpander>(
  (ref) => RecurrenceExpander(ref.watch(databaseProvider)),
);

/// 논리적 오늘의 dayKey. 롤오버 서비스가 갱신한다.
final todayKeyProvider = NotifierProvider<TodayKeyNotifier, String>(
  TodayKeyNotifier.new,
);

class TodayKeyNotifier extends Notifier<String> {
  DayRolloverService? _service;

  @override
  String build() {
    final dayStart = ref.watch(wakeHourProvider);
    final expander = ref.watch(recurrenceExpanderProvider);
    final service = DayRolloverService(
      db: ref.watch(databaseProvider),
      dayStartHour: dayStart,
      onRollover: (newKey) {
        state = newKey;
        expander.expand(newKey); // §4.2 롤오버 시 전개
        ref.read(billRepositoryProvider).ensureLastWeekBill(newKey); // §6.5
      },
    );
    _service?.dispose();
    _service = service;
    // §4.2 앱 시작 시 전개 + §6.5 지난주 청구서 생성
    service.start().then((_) async {
      await expander.expand(service.todayKey);
      await ref
          .read(billRepositoryProvider)
          .ensureLastWeekBill(service.todayKey);
    });
    ref.onDispose(service.dispose);
    return service.todayKey;
  }
}

/// 오늘의 할 일 스트림 — sortIndex 고정 정렬.
/// (야간 리마인더 등 "실제 오늘"에 묶인 서비스가 쓴다 — 열람 날짜와 무관)
final todayTodosProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchTodos(ref.watch(todayKeyProvider));
});

/// 오늘의 days 행 (peakProgress / lightsOutAt)
final todayDayProvider = StreamProvider<Day?>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchDay(ref.watch(todayKeyProvider));
});

final timedPendingTodosProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchTimedPendingFrom(ref.watch(todayKeyProvider));
});

// ── 열람 날짜 (개편 2026-08-09) ──────────────────────────────
// 하단 최근 7일에서 날짜를 고르면 오늘 화면이 그 날짜의 방을 보여준다.

/// 사용자가 고른 날짜. null = 오늘을 따라간다 (롤오버 시 자동 이동)
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, String?>(
  SelectedDateNotifier.new,
);

class SelectedDateNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? dateKey) => state = dateKey;
}

/// 화면이 실제로 보여주는 날짜
final viewedDayKeyProvider = Provider<String>(
  (ref) => ref.watch(selectedDateProvider) ?? ref.watch(todayKeyProvider),
);

/// 열람 날짜의 할 일 스트림 — 화면(리스트·조도·Lumi)이 쓴다
final viewedTodosProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchTodos(ref.watch(viewedDayKeyProvider));
});

/// 열람 날짜의 days 행
final viewedDayProvider = StreamProvider<Day?>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchDay(ref.watch(viewedDayKeyProvider));
});

/// §3.2 조도 상태는 앱 전역에서 단 하나의 값 — 열람 날짜의 목표 t.
/// (표시용 보간·펄스·호흡은 화면 레이어에서 이 목표를 따라간다)
final brightnessProvider = Provider<double>((ref) {
  final todos = ref.watch(viewedTodosProvider).value;
  final day = ref.watch(viewedDayProvider).value;
  final isPast = ref.watch(viewedDayKeyProvider) != ref.watch(todayKeyProvider);

  if (day?.lightsOutAt != null) return 1.0; // §5.3 당긴 후 고정
  // 지난 날은 롤오버 때 기록된 최종 조도가 그날의 진실이다
  if (isPast && day?.finalT != null) return day!.finalT!.clamp(0.0, 1.0);
  if (todos == null) return BrightnessEngine.emptyRoomT; // 로딩 중
  final counted = todos.where((t) => t.status != TodoStatus.deferred).length;
  if (counted == 0) return BrightnessEngine.emptyRoomT; // §5.3 빈 방
  return (day?.peakProgress ?? 0.0).clamp(0.0, 1.0);
});

/// 전등 줄 활성 조건 (§6.4): 오늘을 보고 있을 때만 + 항목 있음 + 안 당김
final pullCordEnabledProvider = Provider<bool>((ref) {
  final todos = ref.watch(viewedTodosProvider).value ?? const [];
  final day = ref.watch(viewedDayProvider).value;
  final isToday =
      ref.watch(viewedDayKeyProvider) == ref.watch(todayKeyProvider);
  return isToday && todos.isNotEmpty && day?.lightsOutAt == null;
});

/// Lumi 취침 여부 — 열람 날짜 기준 (§6.1 FAB 동작 분기에도 사용)
final isAsleepProvider = Provider<bool>(
  (ref) => ref.watch(viewedDayProvider).value?.lightsOutAt != null,
);

// ── Lumi 하루 (개편 2026-08-08 · 세계관 통합 2026-08-15) ────
// 밤의 시작은 상수(19시)가 아니라 Lumi의 취침시간(bedtimeHourProvider)이다.

/// 1분 시계 — 일과 슬롯·낮밤 전환 감지용
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

class LumiModeState {
  final LumiMode mode;
  final LumiDayActivity? activity;
  final double dazzle;

  const LumiModeState({required this.mode, this.activity, this.dazzle = 0.0});
}

/// Lumi 생활 모드 (개편 2026-08-08 · 취침/기상시간 반영 2026-08-15):
/// - 소등했거나, 전부 체크됐거나(시간 무관), 취침시간 이후의 빈 방 → 만족스러운 잠
/// - 낮(기상시간~취침시간) → 행복한 일과. 2시간 슬롯마다 활동이 바뀐다
/// - 취침시간 이후 + 미완 항목 → 못 자는 상태. 눈부심 = 방에 남은 빛(1 - t):
///   불이 많이 남았으면 눈부셔 못 자고, 몇 개 안 남았으면 꾸벅꾸벅 존다
final lumiModeProvider = Provider<LumiModeState>((ref) {
  final now = ref.watch(clockProvider).value ?? DateTime.now();
  final todos = ref.watch(viewedTodosProvider).value ?? const <Todo>[];
  final roomAsleep = ref.watch(isAsleepProvider);
  final t = ref.watch(brightnessProvider);
  final wake = ref.watch(wakeHourProvider);
  final bedtime = ref.watch(bedtimeHourProvider);
  final isViewingPast =
      ref.watch(viewedDayKeyProvider) != ref.watch(todayKeyProvider);

  final counted = todos.where((x) => x.status != TodoStatus.deferred).toList();
  final allDone =
      counted.isNotEmpty && counted.every((x) => x.status == TodoStatus.done);

  // 지난 날짜 열람 (개편 2026-08-09): 그날 밤의 최종 모습 스냅샷.
  // 불을 다 껐으면 만족스러운 잠, 남겼으면 그 빛에 못 잔 모습.
  if (isViewingPast) {
    if (roomAsleep || allDone || counted.isEmpty) {
      return const LumiModeState(mode: LumiMode.asleep);
    }
    return LumiModeState(
      mode: LumiMode.nightAwake,
      dazzle: (1 - t).clamp(0.0, 1.0),
    );
  }

  // 취침시간이 자정을 넘을 수 있으므로(예: 새벽 1시) 기상시간 기준의
  // 경과 시간으로 판정한다. 낮 = 기상 후 취침 전.
  final sinceWake = (now.hour - wake + 24) % 24;
  final dayLength = (bedtime - wake + 24) % 24;
  final isDaytime = dayLength == 0 || sinceWake < dayLength;

  if (roomAsleep || allDone || (!isDaytime && counted.isEmpty)) {
    return const LumiModeState(mode: LumiMode.asleep);
  }
  if (isDaytime) {
    const acts = LumiDayActivity.values; // 순서 = 2시간 슬롯 (기상시간부터)
    final slot = (sinceWake ~/ 2).clamp(0, acts.length - 1);
    return LumiModeState(mode: LumiMode.day, activity: acts[slot]);
  }
  return LumiModeState(
    mode: LumiMode.nightAwake,
    dazzle: (1 - t).clamp(0.0, 1.0),
  );
});

/// 다크서클 (세계관 2026-08-15): 전날 밤 불을 남긴 채 넘어왔다면
/// (= 어제의 days 행이 restless로 봉인됐다면) 오늘 하루 종일 Lumi 눈
/// 밑에 옅은 다크서클이 남는다. 열람 날짜 기준이라 과거의 방을 열어도
/// "그날의 Lumi"가 맞는 얼굴을 한다.
final _dayRowProvider = StreamProvider.family<Day?, String>(
  (ref, key) => ref.watch(todoRepositoryProvider).watchDay(key),
);

final darkCirclesProvider = Provider<bool>((ref) {
  final viewed = ref.watch(viewedDayKeyProvider);
  final prevKey = dayKey(addDays(parseDayKey(viewed), -1));
  return ref.watch(_dayRowProvider(prevKey)).value?.restless ?? false;
});

/// 입력 시트의 기본 날짜 (§6.1): 취침 후엔 내일
final composeDefaultDateProvider = Provider<String>((ref) {
  final todayKey = ref.watch(todayKeyProvider);
  if (!ref.watch(isAsleepProvider)) return todayKey;
  return dayKey(addDays(parseDayKey(todayKey), 1));
});

// ── 주간 (§6.2) ─────────────────────────────────────────────

/// 이번 주 월요일의 dayKey — 범위는 이번 주 월~일로 통일한다 (§6.2)
String weekMondayKey(String todayKey) {
  final d = parseDayKey(todayKey);
  return dayKey(addDays(d, -(d.weekday - 1)));
}

String weekSundayKey(String todayKey) {
  final d = parseDayKey(todayKey);
  return dayKey(addDays(d, 7 - d.weekday));
}

/// 임의의 주(월요일 기준)의 할 일 — 주간 뷰가 과거·미래 주를 열 수 있다
/// (개편 2026-08-13).
final weekTodosForProvider = StreamProvider.family<List<Todo>, String>((
  ref,
  mondayKey,
) {
  final db = ref.watch(databaseProvider);
  return db.todoDao.watchRange(
    mondayKey,
    dayKey(addDays(parseDayKey(mondayKey), 6)),
  );
});

/// 주간 스트립 한 칸의 표시 정보 (§6.2 — 조도만으로 표현, 개수·퍼센트 금지)
class WindowInfo {
  final String dateKey;
  final bool isToday;
  final bool isPast;

  /// 아직 오지 않은 날 — 캄캄한 빈 창으로만 그린다 (얼굴 없음)
  final bool isFuture;

  /// 지난 날: finalT (없으면 null → 캄캄), 오늘: 실시간 t는 화면에서 주입
  final double? finalT;

  /// 다가올 날: 미리 적어둔 항목이 있으면 희미한 예열
  final bool hasPreheat;

  const WindowInfo({
    required this.dateKey,
    required this.isToday,
    required this.isPast,
    this.isFuture = false,
    this.finalT,
    this.hasPreheat = false,
  });
}

/// 스트립이 훑는 범위 — 이번 주 기준 앞뒤 각 [kStripWeeksBack]/[kStripWeeksAhead]주
/// (개편 2026-08-13: 일 단위 30일 → **주 단위 페이징**).
/// 미래 상한 1년은 발주자 결정 — 그보다 먼 빈 주를 넘기는 건 의미가 없다.
const kStripWeeksBack = 52;
const kStripWeeksAhead = 52;

/// 이번 주에서 [weekOffset]주 떨어진 주의 월요일 (0 = 이번 주, -1 = 지난 주)
String stripMondayKey(String todayKey, int weekOffset) =>
    dayKey(addDays(parseDayKey(weekMondayKey(todayKey)), weekOffset * 7));

final stripDayRowsProvider = StreamProvider<List<Day>>((ref) {
  final db = ref.watch(databaseProvider);
  final todayKey = ref.watch(todayKeyProvider);
  final from = stripMondayKey(todayKey, -kStripWeeksBack);
  final to = dayKey(
    addDays(parseDayKey(stripMondayKey(todayKey, kStripWeeksAhead)), 6),
  );
  return db.dayDao.watchRange(from, to);
});

/// 날짜별 days 행 — 스트립이 한 주씩 꺼내 쓴다
final stripDaysByKeyProvider = Provider<Map<String, Day>>((ref) {
  final rows = ref.watch(stripDayRowsProvider).value ?? const <Day>[];
  return {for (final d in rows) d.date: d};
});

/// 스트립이 지금 보고 있는 주 (0 = 이번 주). 좌하단 칩 라벨이 이걸 따라간다.
final stripWeekOffsetProvider = NotifierProvider<StripWeekOffsetNotifier, int>(
  StripWeekOffsetNotifier.new,
);

class StripWeekOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int offset) => state = offset;
}

/// 한 주(월~일)의 창문 7칸. 미래 날은 아직 오지 않은 밤이라 얼굴을 그리지 않는다.
List<WindowInfo> weekWindows({
  required String mondayKey,
  required String todayKey,
  required Map<String, Day> byDate,
}) {
  final monday = parseDayKey(mondayKey);
  final today = parseDayKey(todayKey);
  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = addDays(monday, i);
        final key = dayKey(day);
        final isToday = key == todayKey;
        return WindowInfo(
          dateKey: key,
          isToday: isToday,
          isPast: day.isBefore(today),
          isFuture: day.isAfter(today),
          finalT: byDate[key]?.finalT,
        );
      }(),
  ];
}

// ── 알림 (§10) ──────────────────────────────────────────────

/// 알림 탭 payload — 화면 레이어가 listen해서 라우팅한다 ('home' | 'bill')
final notificationTapProvider =
    NotifierProvider<NotificationTapNotifier, String?>(
      NotificationTapNotifier.new,
    );

class NotificationTapNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String payload) => state = payload;
  void clear() => state = null;
}

/// 예약 시점의 앱 언어로 알림 문구를 만든다 (§10)
AppLocalizations _l10nFor(Ref ref) => lookupAppLocalizations(
  Locale(ref.read(settingsControllerProvider).value?.languageCode ?? 'en'),
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    onTap: (payload) => ref.read(notificationTapProvider.notifier).set(payload),
  );
  service.init().then((_) {
    final enabled =
        ref.read(settingsControllerProvider).value?.billNotificationEnabled ??
        true;
    service.scheduleBillNotification(
      enabled: enabled,
      body: _l10nFor(ref).notifBillArrived,
    );
  });
  // §6.7 청구서 알림 on/off·언어 변경 연동
  ref.listen(settingsControllerProvider, (prev, next) {
    final enabled = next.value?.billNotificationEnabled;
    final changed =
        enabled != prev?.value?.billNotificationEnabled ||
        next.value?.languageCode != prev?.value?.languageCode;
    if (enabled != null && changed) {
      service.scheduleBillNotification(
        enabled: enabled,
        body: _l10nFor(ref).notifBillArrived,
      );
    }
  });
  return service;
});

/// 취침 알림 갱신 (§10 · 통합 2026-08-15): 조건이 성립할 때만
/// Lumi의 취침시간(기본 22:00)에 예약한다 — 별도 리마인더 시각은 없다.
/// TodayScreen이 watch하는 것으로 활성화된다.
final nightReminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final todos = ref.watch(todayTodosProvider).value;
  final day = ref.watch(todayDayProvider).value;
  if (todos == null) return;

  final pending = todos.where((t) => t.status == TodoStatus.pending).length;
  final pulled = day?.lightsOutAt != null;
  final settings =
      ref.watch(settingsControllerProvider).value ?? const UnwindSettings();

  if (settings.nightReminderEnabled && pending > 0 && !pulled) {
    service.scheduleNightReminder(
      hour: settings.bedtimeHour, // Lumi가 자야 하는 시각
      minute: 0,
      body: _l10nFor(ref).notifNightReminder,
    );
  } else {
    service.cancelNightReminder(); // 할 일 없음 / 이미 당김 / 꺼짐 → 보내지 않는다
  }
});

/// 시간 지정 Todo의 10분 전 알림을 DB 상태와 일치시킨다.
final todoReminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final todos = ref.watch(timedPendingTodosProvider).value;
  final today = ref.watch(todayKeyProvider);
  final todayDay = ref.watch(todayDayProvider).value;
  final dayStartHour = ref.watch(wakeHourProvider);
  ref.watch(settingsControllerProvider);
  if (todos == null) return;

  final lightsOut = todayDay?.lightsOutAt != null;
  final reminders = todos
      .where((todo) => !(lightsOut && todo.date == today))
      .map(
        (todo) => TodoReminder(
          todoId: todo.id,
          title: todo.title,
          dueAt: todoDueAt(
            dateKey: todo.date,
            scheduledTimeMinutes: todo.scheduledTimeMinutes!,
            dayStartHour: dayStartHour,
          ),
        ),
      );
  service.syncTodoReminders(
    reminders: reminders,
    body: _l10nFor(ref).todoReminderBody,
  );
});
