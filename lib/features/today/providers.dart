import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/haptics.dart';
import '../../core/sound/sound_player.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/repositories/todo_repository.dart';
import '../../domain/services/brightness_engine.dart';
import '../../domain/services/day_rollover_service.dart';
import '../../domain/services/notification_service.dart';
import '../../domain/services/recurrence_expander.dart';
import '../settings/settings_controller.dart';

/// DB — 앱 전역 단일 인스턴스 (§3.2 단일 진실 공급원)
final databaseProvider = Provider<UnwindDatabase>((ref) {
  final db = UnwindDatabase();
  ref.onDispose(db.close);
  return db;
});

final todoRepositoryProvider = Provider<TodoRepository>(
    (ref) => TodoRepository(ref.watch(databaseProvider)));

final billRepositoryProvider = Provider<BillRepository>(
    (ref) => BillRepository(ref.watch(databaseProvider)));

/// §6.5 미확인 청구서 — 홈 상단 배지
final unreadBillsProvider = StreamProvider<List<WeeklyBill>>(
    (ref) => ref.watch(billRepositoryProvider).watchUnread());

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

/// §4.5 dayStartHour — 설정 연동 (§6.7), 기본 6
final dayStartHourProvider = Provider<int>((ref) =>
    ref.watch(settingsControllerProvider).value?.dayStartHour ?? 6);

final recurrenceExpanderProvider = Provider<RecurrenceExpander>(
    (ref) => RecurrenceExpander(ref.watch(databaseProvider)));

/// 논리적 오늘의 dayKey. 롤오버 서비스가 갱신한다.
final todayKeyProvider = NotifierProvider<TodayKeyNotifier, String>(
    TodayKeyNotifier.new);

class TodayKeyNotifier extends Notifier<String> {
  DayRolloverService? _service;

  @override
  String build() {
    final dayStart = ref.watch(dayStartHourProvider);
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

/// 오늘의 할 일 스트림 — sortIndex 고정 정렬
final todayTodosProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchTodos(ref.watch(todayKeyProvider));
});

/// 오늘의 days 행 (peakProgress / lightsOutAt)
final todayDayProvider = StreamProvider<Day?>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchDay(ref.watch(todayKeyProvider));
});

/// §3.2 조도 상태는 앱 전역에서 단 하나의 값 — 목표 t.
/// (표시용 보간·펄스·호흡은 화면 레이어에서 이 목표를 따라간다)
final brightnessProvider = Provider<double>((ref) {
  final todos = ref.watch(todayTodosProvider).value;
  final day = ref.watch(todayDayProvider).value;

  if (day?.lightsOutAt != null) return 1.0; // §5.3 당긴 후 고정
  if (todos == null) return BrightnessEngine.emptyRoomT; // 로딩 중
  final counted =
      todos.where((t) => t.status != TodoStatus.deferred).length;
  if (counted == 0) return BrightnessEngine.emptyRoomT; // §5.3 빈 방
  return (day?.peakProgress ?? 0.0).clamp(0.0, 1.0);
});

/// 전등 줄 활성 조건 (§6.4): 항목 있음 + 아직 안 당김
final pullCordEnabledProvider = Provider<bool>((ref) {
  final todos = ref.watch(todayTodosProvider).value ?? const [];
  final day = ref.watch(todayDayProvider).value;
  return todos.isNotEmpty && day?.lightsOutAt == null;
});

/// Lumi 취침 여부 (§6.1 FAB 동작 분기에도 사용)
final isAsleepProvider = Provider<bool>((ref) =>
    ref.watch(todayDayProvider).value?.lightsOutAt != null);

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

final weekTodosProvider = StreamProvider<List<Todo>>((ref) {
  final db = ref.watch(databaseProvider);
  final todayKey = ref.watch(todayKeyProvider);
  return db.todoDao.watchRange(
      weekMondayKey(todayKey), weekSundayKey(todayKey));
});

final weekDayRowsProvider = StreamProvider<List<Day>>((ref) {
  final db = ref.watch(databaseProvider);
  final todayKey = ref.watch(todayKeyProvider);
  return db.dayDao.watchRange(
      weekMondayKey(todayKey), weekSundayKey(todayKey));
});

/// 주간 스트립 한 칸의 표시 정보 (§6.2 — 조도만으로 표현, 개수·퍼센트 금지)
class WindowInfo {
  final String dateKey;
  final bool isToday;
  final bool isPast;

  /// 지난 날: finalT (없으면 null → 캄캄), 오늘: 실시간 t는 화면에서 주입
  final double? finalT;

  /// 다가올 날: 미리 적어둔 항목이 있으면 희미한 예열
  final bool hasPreheat;

  const WindowInfo({
    required this.dateKey,
    required this.isToday,
    required this.isPast,
    this.finalT,
    this.hasPreheat = false,
  });
}

final weekWindowsProvider = Provider<List<WindowInfo>>((ref) {
  final todayKey = ref.watch(todayKeyProvider);
  final dayRows = ref.watch(weekDayRowsProvider).value ?? const <Day>[];
  final todos = ref.watch(weekTodosProvider).value ?? const <Todo>[];

  final byDate = {for (final d in dayRows) d.date: d};
  final datesWithTodos = {for (final t in todos) t.date};
  final monday = parseDayKey(weekMondayKey(todayKey));
  final today = parseDayKey(todayKey);

  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = addDays(monday, i);
        final key = dayKey(day);
        final isPast = day.isBefore(today);
        return WindowInfo(
          dateKey: key,
          isToday: key == todayKey,
          isPast: isPast,
          finalT: byDate[key]?.finalT,
          hasPreheat: !isPast && key != todayKey &&
              datesWithTodos.contains(key),
        );
      }(),
  ];
});


// ── 알림 (§10) ──────────────────────────────────────────────

/// 알림 탭 payload — 화면 레이어가 listen해서 라우팅한다 ('home' | 'bill')
final notificationTapProvider =
    NotifierProvider<NotificationTapNotifier, String?>(
        NotificationTapNotifier.new);

class NotificationTapNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String payload) => state = payload;
  void clear() => state = null;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    onTap: (payload) =>
        ref.read(notificationTapProvider.notifier).set(payload),
  );
  service.init().then((_) {
    final enabled = ref
            .read(settingsControllerProvider)
            .value
            ?.billNotificationEnabled ??
        true;
    service.scheduleBillNotification(enabled: enabled);
  });
  // §6.7 청구서 알림 on/off 연동
  ref.listen(settingsControllerProvider, (prev, next) {
    final enabled = next.value?.billNotificationEnabled;
    if (enabled != null && enabled != prev?.value?.billNotificationEnabled) {
      service.scheduleBillNotification(enabled: enabled);
    }
  });
  return service;
});

/// 밤 리마인더 갱신 (§10): 조건이 성립할 때만 오늘 22:00 예약.
/// TodayScreen이 watch하는 것으로 활성화된다.
final nightReminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final todos = ref.watch(todayTodosProvider).value;
  final day = ref.watch(todayDayProvider).value;
  if (todos == null) return;

  final pending =
      todos.where((t) => t.status == TodoStatus.pending).length;
  final pulled = day?.lightsOutAt != null;
  final settings =
      ref.watch(settingsControllerProvider).value ?? const UnwindSettings();

  if (settings.nightReminderEnabled && pending > 0 && !pulled) {
    final (h, m) = settings.reminderHourMinute; // 기본 22:00 (§4.5)
    service.scheduleNightReminder(hour: h, minute: m);
  } else {
    service.cancelNightReminder(); // 할 일 없음 / 이미 당김 / 꺼짐 → 보내지 않는다
  }
});
