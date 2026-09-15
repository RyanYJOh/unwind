import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal 앱 ID — 대시보드 Settings > Keys & IDs. 공개 값이라 코드에 둔다.
/// 비어 있으면 원격 푸시를 켜지 않는다 (앱의 로컬 알림은 그대로 동작).
const kOneSignalAppId = '';

/// 원격 푸시 — OneSignal 래퍼 (신설 2026-09-15).
///
/// 화면·서비스가 `onesignal_flutter`를 직접 import하지 않는다 (§8.8 Mixpanel과
/// 같은 규칙). 앱의 알림 4종(§8)은 여전히 로컬 알림이고, 이쪽은 서버에서
/// 보내는 캠페인 푸시만 받는다.
///
/// **권한은 여기서 묻지 않는다** — 첫 실행 즉시 요청 금지(§10). 권한 요청은
/// 지금처럼 NotificationService가 온보딩 인사·시간 지정 저장에서 하고,
/// 허용되면 [syncPermission]으로 OneSignal에 APNs 토큰 등록을 알린다.
abstract final class ToddPush {
  static Future<void>? _ready;

  /// iOS만 구성돼 있다 (Android FCM 미설정).
  static bool get _enabled =>
      kOneSignalAppId.isNotEmpty &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  /// 콜드 스타트에 한 번. main()에서 fire-and-forget.
  static Future<void> init() => _ready ??= _init();

  static Future<void> _init() async {
    if (!_enabled) return;
    try {
      if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      await OneSignal.initialize(kOneSignalAppId);
      // 이 SDK가 들어오기 전에 이미 권한을 허용한 유저 — 다이얼로그 없이
      // 토큰 등록만 한다. 아직 안 물어본 유저에겐 아무것도 하지 않는다.
      final permission = await OneSignal.Notifications.permissionNative();
      if (permission != OSNotificationPermission.notDetermined &&
          permission != OSNotificationPermission.denied) {
        await OneSignal.Notifications.requestPermission(false);
      }
    } catch (e) {
      debugPrint('[push] init failed: $e'); // 테스트 등 채널이 없는 환경
    }
  }

  /// 로컬 알림 권한이 허용된 직후 부른다. OS가 이미 답을 받은 뒤라
  /// 다이얼로그는 다시 뜨지 않고, OneSignal이 원격 푸시 구독을 켠다.
  static Future<void> syncPermission() async {
    if (!_enabled) return;
    try {
      await init();
      await OneSignal.Notifications.requestPermission(false);
    } catch (e) {
      debugPrint('[push] syncPermission failed: $e');
    }
  }
}
