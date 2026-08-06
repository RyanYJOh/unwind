import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 알림 탭 라우팅용 콜백 — payload: 'home' | 'bill'
  final void Function(String payload)? onTap;

  bool _initialized = false;

  NotificationService({this.onTap});

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // 로컬 오프셋 기반 타임존 선택 — DST 없는 KST 환경 기준.
    // TODO(unwind): 해외 타임존 정확도가 필요해지면 flutter_timezone 도입 검토.
    final offset = DateTime.now().timeZoneOffset;
    try {
      final name = offset.inHours == 9 ? 'Asia/Seoul' : 'UTC';
      tz.setLocalLocation(tz.getLocation(name));
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
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    try {
      final granted = await ios?.requestPermissions(
          alert: true, badge: true, sound: true);
      return granted ?? false;
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
    if (!_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
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
    if (!_initialized) return;
    await _plugin.cancel(id: _nightReminderId);
  }

  /// 청구서 도착 (§10): 매주 월요일 09:00 반복
  Future<void> scheduleBillNotification({
    bool enabled = true,
    required String body,
  }) async {
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
}
