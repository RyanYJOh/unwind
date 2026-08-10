import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/dates.dart';

class TodoReminder {
  final String todoId;
  final String title;
  final DateTime dueAt;

  const TodoReminder({
    required this.todoId,
    required this.title,
    required this.dueAt,
  });
}

DateTime todoDueAt({
  required String dateKey,
  required int scheduledTimeMinutes,
  required int dayStartHour,
}) {
  final logicalDate = parseDayKey(dateKey);
  final calendarDate = scheduledTimeMinutes < dayStartHour * 60
      ? logicalDate.add(const Duration(days: 1))
      : logicalDate;
  return DateTime(
    calendarDate.year,
    calendarDate.month,
    calendarDate.day,
    scheduledTimeMinutes ~/ 60,
    scheduledTimeMinutes % 60,
  );
}

DateTime todoReminderAt({
  required String dateKey,
  required int scheduledTimeMinutes,
  required int dayStartHour,
}) => todoDueAt(
  dateKey: dateKey,
  scheduledTimeMinutes: scheduledTimeMinutes,
  dayStartHour: dayStartHour,
).subtract(const Duration(minutes: 10));

bool shouldScheduleTodoReminder({
  required DateTime dueAt,
  required DateTime now,
}) => dueAt.subtract(const Duration(minutes: 10)).isAfter(now);

/// §10 로컬 알림 — 서버 없음, 로컬만.
///
/// 규칙:
/// - 할 일이 없는 날에는 밤 리마인더를 보내지 않는다
/// - 이미 전등 줄을 당긴 날에는 보내지 않는다
/// - 재촉하거나 탓하지 않는다 (`아직도 3개나 남았어요` 금지)
/// - 권한은 온보딩 종료 후에 요청한다 (첫 실행 즉시 요청 금지, M4에서 연결)
class NotificationService {
  static const _nightReminderId = 1;
  static const _billId = 2;
  static const _todoIdFloor = 1000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 알림 탭 라우팅용 콜백 — payload: 'home' | 'bill'
  final void Function(String payload)? onTap;

  bool _initialized = false;

  NotificationService({this.onTap});

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // 기본 로케이션 유지
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            // 권한은 온보딩 후 별도 요청 (§10)
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          onTap?.call(response.payload ?? 'home');
        },
      );
      _initialized = true;
    } catch (_) {
      // 테스트 등 플랫폼 채널이 없는 환경 — 알림 없이 동작
    }
  }

  /// 온보딩 종료 후 호출 (§10 — 첫 실행 즉시 요청 금지)
  Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final androidGranted = await android?.requestNotificationsPermission();
      return iosGranted ?? androidGranted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 밤 리마인더 (§10): 오늘 lightsOutAt이 없고 pending이 1개 이상일 때만.
  /// 조건은 호출자가 판단해 매일 갱신한다 — 조건이 깨지면 [cancelNightReminder].
  /// [body]는 호출 시점의 앱 언어로 로컬라이즈해 전달한다.
  Future<void> scheduleNightReminder({
    required int hour,
    required int minute,
    required String body,
  }) async {
    await init();
    if (!_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!at.isAfter(now)) return; // 오늘 시각이 이미 지났으면 보내지 않는다

    await _plugin.zonedSchedule(
      id: _nightReminderId,
      title: null,
      body: body, // §10 문구 — 재촉·비난 없음
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'home',
    );
  }

  Future<void> cancelNightReminder() async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: _nightReminderId);
  }

  /// 청구서 도착 (§10): 매주 월요일 09:00 반복
  Future<void> scheduleBillNotification({
    bool enabled = true,
    required String body,
  }) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: _billId);
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    while (at.weekday != DateTime.monday || !at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _billId,
      title: null,
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // 매주 반복
      payload: 'bill',
    );
  }

  static int todoNotificationId(String todoId) {
    var hash = 0x811c9dc5;
    for (final unit in todoId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x3fffffff;
    }
    return _todoIdFloor + hash;
  }

  Future<void> cancelTodoReminder(String todoId) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: todoNotificationId(todoId));
  }

  /// 가장 가까운 회차만 유지해 iOS의 보류 알림 개수 제한을 넘지 않는다.
  Future<void> syncTodoReminders({
    required Iterable<TodoReminder> reminders,
    required String body,
    DateTime? now,
  }) async {
    await init();
    if (!_initialized) return;

    final localNow = now ?? DateTime.now();
    final eligible =
        reminders
            .where(
              (reminder) => shouldScheduleTodoReminder(
                dueAt: reminder.dueAt,
                now: localNow,
              ),
            )
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final selected = eligible.take(48).toList();
    final desiredIds = {
      for (final reminder in selected) todoNotificationId(reminder.todoId),
    };

    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _todoIdFloor && !desiredIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    for (final reminder in selected) {
      final at = reminder.dueAt.subtract(const Duration(minutes: 10));
      final scheduled = tz.TZDateTime(
        tz.local,
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      );
      await _plugin.zonedSchedule(
        id: todoNotificationId(reminder.todoId),
        title: reminder.title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(presentSound: false),
          android: AndroidNotificationDetails(
            'todo_reminders',
            'Task reminders',
            channelDescription: 'Gentle reminders before a task time',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'home',
      );
    }
  }
}
