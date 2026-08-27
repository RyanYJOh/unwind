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
}
