import Flutter
import Foundation
import WidgetKit

/// Flutter `WidgetSnapshotService` ↔ App Group. home_widget의
/// `saveWidgetData`는 UserDefaults를 디스크에 플러시하지 않은 채
/// 타임라인을 리로드해서, 첫 설치 위젯이 빈 스냅샷("Good morning!")에
/// 고정된다. 여기서 파일+suite를 원자적으로 쓰고 나서 리로드한다.
enum WidgetSnapshotBridge {
  static let channelName = "unwind/widget_snapshot"
  static let fileName = "widget_snapshot.json"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      // 실기기에서만 나는 App Group 실패를 눈으로 잡기 위한 진단 (dev).
      // 컨테이너 경로가 nil이면 엔타이틀먼트·프로비저닝 문제로 확정된다.
      if call.method == "diagnose" {
        let args = call.arguments as? [String: Any]
        let appGroupId = args?["appGroupId"] as? String ?? ""
        result(diagnose(appGroupId: appGroupId))
        return
      }
      guard call.method == "persist" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let appGroupId = args["appGroupId"] as? String,
            let kind = args["kind"] as? String
      else {
        result(
          FlutterError(
            code: "bad-args",
            message: "persist requires appGroupId and kind",
            details: nil
          )
        )
        return
      }

      do {
        try persist(args, appGroupId: appGroupId)
      } catch {
        result(
          FlutterError(
            code: "persist-failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      if #available(iOS 14.0, *) {
        // ofKind 하나면 충분하다 — reloadAllTimelines까지 겹쳐 쏘면
        // WidgetKit이 진행 중인 타임라인 생성에 뒤 리로드를 합쳐 버리는
        // (coalescing) 경쟁 창만 넓어진다 (간헐 미반영, 2026-08-22).
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
      }
      result(true)
    }
  }

  private static func persist(_ args: [String: Any], appGroupId: String) throws {
    let payload: [String: Any] = [
      "dayKey": args["dayKey"] as? String ?? "",
      "remaining": NSNumber(value: intVal(args["remaining"])),
      "total": NSNumber(value: intVal(args["total"])),
      "lightsOut": NSNumber(value: boolVal(args["lightsOut"])),
      "brightness": NSNumber(value: doubleVal(args["brightness"], fallback: 1)),
      "darkCircles": NSNumber(value: boolVal(args["darkCircles"])),
      "wakeHour": NSNumber(value: intVal(args["wakeHour"], fallback: 5)),
      "bedtimeHour": NSNumber(value: intVal(args["bedtimeHour"], fallback: 22)),
      "languageCode": args["languageCode"] as? String ?? "en",
    ]
    guard let dayKey = payload["dayKey"] as? String, !dayKey.isEmpty else {
      throw SnapshotError.emptyDayKey
    }

    guard let defaults = UserDefaults(suiteName: appGroupId) else {
      throw SnapshotError.noSuite
    }
    for (key, value) in payload {
      defaults.setValue(value, forKey: key)
    }
    defaults.synchronize()

    guard
      let root = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId
      )
    else {
      throw SnapshotError.noContainer
    }
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    // 잠긴 기기에서도 위젯이 읽어야 한다. 기본 보호 등급이면 타임라인 생성이
    // 잠금 중에 돌 때 읽기가 실패하고, .atEnd 정책 탓에 그 빈 결과가 24시간
    // 고정된다 (시뮬레이터엔 데이터 보호가 없어 재현되지 않는다).
    try data.write(
      to: root.appendingPathComponent(fileName),
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    )
  }

  /// App Group이 실제로 붙었는지, 스냅샷이 남아 있는지 그대로 보고한다.
  private static func diagnose(appGroupId: String) -> [String: Any] {
    var out: [String: Any] = ["appGroupId": appGroupId]
    let root = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    )
    out["containerPath"] = root?.path ?? ""
    out["containerOk"] = root != nil
    out["suiteOk"] = UserDefaults(suiteName: appGroupId) != nil
    out["defaultsDayKey"] = UserDefaults(suiteName: appGroupId)?
      .string(forKey: "dayKey") ?? ""
    if let root {
      let url = root.appendingPathComponent(fileName)
      out["fileExists"] = FileManager.default.fileExists(atPath: url.path)
      out["fileBody"] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
      out["fileProtection"] =
        (attrs?[.protectionKey] as? FileProtectionType)?.rawValue ?? ""
    } else {
      out["fileExists"] = false
      out["fileBody"] = ""
      out["fileProtection"] = ""
    }
    return out
  }

  private static func intVal(_ value: Any?, fallback: Int = 0) -> Int {
    if let n = value as? NSNumber { return n.intValue }
    if let i = value as? Int { return i }
    return fallback
  }

  private static func boolVal(_ value: Any?) -> Bool {
    if let n = value as? NSNumber { return n.boolValue }
    if let b = value as? Bool { return b }
    return false
  }

  private static func doubleVal(_ value: Any?, fallback: Double) -> Double {
    if let n = value as? NSNumber { return n.doubleValue }
    if let d = value as? Double { return d }
    return fallback
  }

  private enum SnapshotError: LocalizedError {
    case emptyDayKey, noSuite, noContainer
    var errorDescription: String? {
      switch self {
      case .emptyDayKey: return "dayKey missing"
      case .noSuite: return "UserDefaults suite unavailable"
      case .noContainer: return "App Group container unavailable"
      }
    }
  }
}
