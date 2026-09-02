import AppTrackingTransparency
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    WidgetSnapshotBridge.register(with: engineBridge.applicationRegistrar.messenger())
    registerSystemSettingsChannel(messenger: engineBridge.applicationRegistrar.messenger())
    registerTrackingChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// 설정 앱의 이 앱 알림 화면을 연다 (2026-08-27) — 시간 지정 알림 권한이
  /// OS에서 거부 고착됐을 때 안내 토스트의 "설정 열기" CTA가 부른다.
  /// 새 Swift 파일은 pbxproj 등록이 필요해 AppDelegate에 인라인으로 둔다.
  private func registerSystemSettingsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "unwind/system_settings", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // iOS 16+: 알림 설정으로 바로. 15.4+: 같은 화면의 구 상수.
      // 그 외(최소 배포 15.0): 앱 설정 루트(알림 행이 바로 보인다).
      let urlString: String
      if #available(iOS 16.0, *) {
        urlString = UIApplication.openNotificationSettingsURLString
      } else if #available(iOS 15.4, *) {
        urlString = UIApplicationOpenNotificationSettingsURLString
      } else {
        urlString = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
        result(false)
        return
      }
      UIApplication.shared.open(url)
      result(true)
    }
  }

  /// ATT — 앱 추적 동의 (2026-09-02, App Store 리젝 대응).
  /// 첫 실행 때 프롬프트를 띄운다. OS가 한 번만 보여 주므로 앱은 매
  /// 콜드 스타트마다 불러도 되고, 결정된 뒤에는 즉시 현재 상태만 돌아온다.
  /// 새 Swift 파일은 pbxproj 등록이 필요해 여기 인라인으로 둔다
  /// (AppTrackingTransparency.framework는 Swift 모듈 자동 링크가 붙인다).
  private func registerTrackingChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "unwind/tracking", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        result(AppDelegate.trackingStatusName())
      case "request":
        // iOS는 앱이 **active일 때만** 프롬프트를 띄운다 — 콜드 스타트
        // 첫 프레임은 아직 inactive일 수 있어, 활성화되는 순간으로 미룬다.
        // 안 미루면 다이얼로그 없이 notDetermined가 그대로 돌아온다.
        AppDelegate.whenActive {
          ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { result(AppDelegate.trackingStatusName()) }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 현재 ATT 상태를 Dart가 아는 문자열로 (TrackingStatus와 계약).
  private static func trackingStatusName() -> String {
    switch ATTrackingManager.trackingAuthorizationStatus {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  /// 앱이 active면 즉시, 아니면 다음 didBecomeActive에 한 번 실행한다.
  private static func whenActive(_ work: @escaping () -> Void) {
    if UIApplication.shared.applicationState == .active {
      work()
      return
    }
    var token: NSObjectProtocol?
    token = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in
      if let token { NotificationCenter.default.removeObserver(token) }
      work()
    }
  }
}
