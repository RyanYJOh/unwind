import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ATT(App Tracking Transparency) 동의 상태.
/// 문자열 값이 `AppDelegate.trackingStatusName()`과의 계약이다.
enum TrackingStatus {
  notDetermined,
  authorized,
  denied,
  restricted,

  /// iOS가 아니거나 채널이 없는 환경 (테스트·Android) — 물어볼 게 없다.
  unsupported;

  static TrackingStatus fromName(String? name) => switch (name) {
    'authorized' => TrackingStatus.authorized,
    'denied' => TrackingStatus.denied,
    'restricted' => TrackingStatus.restricted,
    'notDetermined' => TrackingStatus.notDetermined,
    _ => TrackingStatus.unsupported,
  };
}

/// ATT 동의 (신설 2026-09-02 — App Store 리젝 대응).
///
/// 앱이 Mixpanel(§8.8)로 사용 데이터를 모으므로 iOS는 추적 동의 프롬프트를
/// 요구한다. **첫 실행 때 바로** 띄운다 — 온보딩 안이 아니라 프로세스가
/// 켜지는 순간이다. OS가 프롬프트를 생애 한 번만 보여 주므로 콜드 스타트마다
/// 불러도 안전하고, 이미 답한 유저에겐 조용히 현재 상태만 돌아온다.
///
/// 네이티브는 `ios/Runner/AppDelegate.swift`의 `unwind/tracking` 채널이며,
/// 앱이 active가 될 때까지 요청을 미룬다 (inactive면 다이얼로그가 안 뜬다).
abstract final class TrackingConsent {
  @visibleForTesting
  static const channel = MethodChannel('unwind/tracking');

  static Future<TrackingStatus>? _pending;

  /// 프로세스당 한 번. 두 번째부터는 첫 호출의 결과를 그대로 돌려준다 —
  /// 프롬프트가 떠 있는 동안 다시 부르면 네이티브 콜백이 겹칠 수 있다.
  static Future<TrackingStatus> requestOnLaunch() =>
      _pending ??= _invoke('request');

  /// 현재 상태만 조회 (프롬프트 없음).
  static Future<TrackingStatus> status() => _invoke('status');

  static Future<TrackingStatus> _invoke(String method) async {
    try {
      return TrackingStatus.fromName(
        await channel.invokeMethod<String>(method),
      );
    } on MissingPluginException {
      return TrackingStatus.unsupported; // iOS 아님 · 테스트 환경
    } catch (e) {
      debugPrint('[att] $method failed: $e');
      return TrackingStatus.unsupported;
    }
  }

  @visibleForTesting
  static void resetForTest() => _pending = null;
}
