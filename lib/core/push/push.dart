import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal 앱 ID — 대시보드 Settings > Keys & IDs. 공개 값이라 코드에 둔다.
const kOneSignalAppId = '3d455be2-3327-46eb-b35f-f251fbd6283d';

/// 푸시 구독 ID 변화를 받는 콜백 — SDK 타입을 래퍼 밖으로 흘리지 않는다.
typedef PushIdObserver = void Function(String? subscriptionId);

/// 원격 푸시 — OneSignal 래퍼 (신설 2026-09-15).
///
/// **OneSignal SDK 호출은 전부 여기서만 한다** (§8.8 Mixpanel과 같은 규칙).
/// 앱의 알림 4종(§8)은 여전히 로컬 알림이고, 이쪽은 대시보드에서 보내는
/// 캠페인 푸시만 받는다. iOS 전용 (Android 프로젝트 없음).
///
/// 권한 프롬프트는 OneSignal이 띄우지 않는다 — 첫 실행 즉시 요청 금지(§10).
/// NotificationService가 온보딩 인사·시간 지정 저장에서 묻고, 허용되면
/// [syncPermission]으로 OneSignal에 알린다 (이미 답한 뒤라 다이얼로그 없음).
abstract final class ToddPush {
  static Future<void>? _ready;
  static final _observers = <PushIdObserver, OnPushSubscriptionChangeObserver>{};

  static bool get _enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 콜드 스타트에 한 번, runApp 전에. main()에서 fire-and-forget.
  static Future<void> init() => _ready ??= _init();

  static Future<void> _init() async {
    if (!_enabled) return;
    try {
      if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      await OneSignal.initialize(kOneSignalAppId);
    } catch (e) {
      debugPrint('[push] init failed: $e'); // 테스트 등 채널이 없는 환경
    }
  }

  /// init 완료를 기다린 뒤 SDK 호출. 실패하면 [fallback] (던지지 않는다).
  static Future<T> _call<T>(Future<T> Function() op, T fallback) async {
    if (!_enabled) return fallback;
    try {
      await init();
      return await op();
    } catch (e) {
      debugPrint('[push] $e');
      return fallback;
    }
  }

  /// 시스템 권한 프롬프트 (이미 답했으면 설정 앱으로 안내).
  static Future<bool> requestPermission() =>
      _call(() => OneSignal.Notifications.requestPermission(true), false);

  /// 로컬 알림 권한이 허용된 직후. OS가 이미 답을 받은 뒤라 다이얼로그는
  /// 뜨지 않고, OneSignal이 원격 푸시 구독을 켠다.
  static Future<bool> syncPermission() =>
      _call(() => OneSignal.Notifications.requestPermission(false), false);

  /// 서버가 발급한 구독 ID. 등록 전엔 null이거나 `local-` 임시값이다.
  static String? get pushSubscriptionId =>
      _enabled ? OneSignal.User.pushSubscription.id : null;

  static void addPushSubscriptionObserver(PushIdObserver observer) {
    if (!_enabled) return;
    void wrapped(OSPushSubscriptionChangedState state) =>
        observer(state.current.id);
    _observers[observer] = wrapped;
    OneSignal.User.pushSubscription.addObserver(wrapped);
  }

  static void removePushSubscriptionObserver(PushIdObserver observer) {
    final wrapped = _observers.remove(observer);
    if (wrapped != null) {
      OneSignal.User.pushSubscription.removeObserver(wrapped);
    }
  }

  // ── 사용자·태그 — 아직 호출처 없음 (계정 없는 로컬 앱). 쓰게 되면 여기로.

  static Future<void> login(String externalId) =>
      _call(() => OneSignal.login(externalId), null);

  static Future<void> logout() => _call(OneSignal.logout, null);

  static Future<void> addTag(String key, String value) =>
      _call(() => OneSignal.User.addTagWithKey(key, value), null);

  static Future<void> addEmail(String email) =>
      _call(() => OneSignal.User.addEmail(email), null);

  static Future<void> addSms(String number) =>
      _call(() => OneSignal.User.addSms(number), null);

  static Future<void> setLogLevel(OSLogLevel level) =>
      _call(() => OneSignal.Debug.setLogLevel(level), null);
}
