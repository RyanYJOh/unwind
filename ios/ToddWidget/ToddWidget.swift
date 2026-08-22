import SwiftUI
import WidgetKit

// ============================================================================
// Unwind 홈 위젯 (PRD 개정 2026-08-15)
//
// - 데이터: Flutter 앱이 App Group 컨테이너의 widget_snapshot.json
//   (+ UserDefaults 폴백)에 쓰는 스냅샷. 키·의미는
//   lib/domain/services/widget_snapshot_service.dart 와 계약.
// - Todd: 앱 페인터로 사전 렌더한 스프라이트 PNG (재추출:
//   SPRITE_EXPORT=1 flutter test test/tools/widget_sprite_export_test.dart).
// - 모드 판정은 toddModeProvider(§4)의 미러 — 앱 쪽 규칙이 바뀌면 여기도
//   맞춰야 한다.
// - 기상시간이 지났는데 앱이 아직 안 열렸으면(dayKey 불일치) 개수를 숨긴다
//   — 롤오버는 앱에서만 실행되므로 확정 전 숫자를 보여주지 않는다.
// ============================================================================

// MARK: - 팔레트 (core/tokens/palette.dart 미러 — 값이 바뀌면 함께 갱신)

private enum Palette {
    static let ink = Color(red: 0x0D / 255, green: 0x15 / 255, blue: 0x20 / 255)
    static let inkDeep = Color(red: 0x07 / 255, green: 0x0D / 255, blue: 0x15 / 255)
    static let surfaceHigh = Color(red: 0x27 / 255, green: 0x39 / 255, blue: 0x4A / 255)
    static let pillDeep = Color(red: 0x10 / 255, green: 0x1B / 255, blue: 0x26 / 255)
    static let textPrimary = Color(red: 0xF2 / 255, green: 0xF7 / 255, blue: 0xFB / 255)
    static let textSecondary = Color(red: 0x9B / 255, green: 0xB0 / 255, blue: 0xC2 / 255)
    // 조명 색 기본값(앰버) — 스냅샷이 accent를 실어 오면 그쪽을 쓴다
    // (선택형 2026-08-22, palette.dart UnwindLightColor 미러)
    static let amberARGB = 0xFFFF_B224
    static let amberDeepARGB = 0xFFC5_7F12
    static let onAmberARGB = 0xFF1A_1206
}

extension Color {
    /// Flutter Color.toARGB32() → SwiftUI Color
    init(argb: Int) {
        self.init(
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255
        )
    }
}

// MARK: - 앱 스냅샷 (App Group)

private struct Snapshot {
    static let appGroupId = "group.com.unwindapp.unwind"

    var dayKey: String
    var remaining: Int
    var total: Int
    var lightsOut: Bool
    var brightness: Double
    var darkCircles: Bool
    var wakeHour: Int
    var bedtimeHour: Int
    var languageCode: String
    /// 조명 색 (선택형 2026-08-22) — ARGB. 앱 팔레트를 따라온다
    var accent: Int
    var accentDeep: Int
    var onAccent: Int

    /// Runner `WidgetSnapshotBridge`가 App Group 컨테이너에 원자적으로 쓰는 파일.
    /// UserDefaults는 위젯 프로세스가 빈 캐시를 붙잡는 경우가 있어 파일을 먼저 본다.
    static let snapshotFileName = "widget_snapshot.json"

    static func load() -> Snapshot? {
        if let fromFile = loadFromFile() { return fromFile }
        return loadFromDefaults()
    }

    private static func loadFromFile() -> Snapshot? {
        guard
            let root = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
            )
        else { return nil }
        let url = root.appendingPathComponent(snapshotFileName)
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dayKey = obj["dayKey"] as? String, !dayKey.isEmpty
        else { return nil }
        return Snapshot(
            dayKey: dayKey,
            remaining: jsonInt(obj, "remaining"),
            total: jsonInt(obj, "total"),
            lightsOut: jsonBool(obj, "lightsOut"),
            brightness: jsonDouble(obj, "brightness", fallback: 1.0),
            darkCircles: jsonBool(obj, "darkCircles"),
            wakeHour: jsonInt(obj, "wakeHour", fallback: 5),
            bedtimeHour: jsonInt(obj, "bedtimeHour", fallback: 22),
            languageCode: obj["languageCode"] as? String ?? "en",
            accent: jsonInt(obj, "accent", fallback: Palette.amberARGB),
            accentDeep: jsonInt(obj, "accentDeep", fallback: Palette.amberDeepARGB),
            onAccent: jsonInt(obj, "onAccent", fallback: Palette.onAmberARGB)
        )
    }

    private static func loadFromDefaults() -> Snapshot? {
        guard let d = UserDefaults(suiteName: appGroupId) else { return nil }
        // 앱 프로세스가 방금 쓴 App Group 값을 위젯 프로세스 캐시가
        // 가리지 않게 디스크에서 다시 읽는다.
        d.synchronize()
        guard let dayKey = d.string(forKey: "dayKey") else { return nil }
        return Snapshot(
            dayKey: dayKey,
            remaining: d.intValue("remaining"),
            total: d.intValue("total"),
            lightsOut: d.bool(forKey: "lightsOut"),
            brightness: d.doubleValue("brightness", fallback: 1.0),
            darkCircles: d.bool(forKey: "darkCircles"),
            wakeHour: d.intValue("wakeHour", fallback: 5),
            bedtimeHour: d.intValue("bedtimeHour", fallback: 22),
            languageCode: d.string(forKey: "languageCode") ?? "en",
            accent: d.intValue("accent", fallback: Palette.amberARGB),
            accentDeep: d.intValue("accentDeep", fallback: Palette.amberDeepARGB),
            onAccent: d.intValue("onAccent", fallback: Palette.onAmberARGB)
        )
    }

    private static func jsonInt(_ obj: [String: Any], _ key: String, fallback: Int = 0) -> Int {
        if let n = obj[key] as? NSNumber { return n.intValue }
        if let s = obj[key] as? String, let v = Int(s) { return v }
        return fallback
    }

    private static func jsonBool(_ obj: [String: Any], _ key: String) -> Bool {
        if let n = obj[key] as? NSNumber { return n.boolValue }
        if let b = obj[key] as? Bool { return b }
        return false
    }

    private static func jsonDouble(
        _ obj: [String: Any], _ key: String, fallback: Double
    ) -> Double {
        if let n = obj[key] as? NSNumber { return n.doubleValue }
        if let s = obj[key] as? String, let v = Double(s) { return v }
        return fallback
    }
}

// MARK: - 장면 판정 (toddModeProvider §4 미러)

private enum Scene {
    case asleep(satisfied: Bool) // satisfied = 다 끄고 잔 밤 / false = 조용한 밤
    case day(slot: Int) // 0 = stretch … 9 = rest (daySlotNames 순서)
    case nightSquint
    case nightDoze
    case morning(slot: Int) // 새 하루, 앱 미실행 — 개수 미확정
}

private struct DisplayState {
    var scene: Scene
    var darkCircles: Bool
    /// nil = 개수를 보여주지 않는 상태 (아침 인사·빈 방·잠)
    var remaining: Int?
    /// 방에 남은 빛 0…1 — 코너 글로우 세기 (§5.1: 응답은 선형)
    var glow: Double
    var lang: String
    /// 조명 색 (선택형 2026-08-22) — 알약·글로우가 따라간다
    var accent: Color = Color(argb: Palette.amberARGB)
    var accentDeep: Color = Color(argb: Palette.amberDeepARGB)
    var onAccent: Color = Color(argb: Palette.onAmberARGB)
}

/// Dart logicalTodayKey와 동일: 기상시간만큼 되돌린 시각의 로컬 날짜
private func logicalDayKey(_ date: Date, wakeHour: Int) -> String {
    let shifted = date.addingTimeInterval(-Double(wakeHour) * 3600)
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: shifted)
}

private extension UserDefaults {
    /// Flutter method channel은 숫자를 NSNumber로 넣는다. `as? Int`/`as? Double`은
    /// NSNumber에서 실패해 0·기본값으로 떨어지므로 NSNumber를 먼저 본다.
    func intValue(_ key: String, fallback: Int = 0) -> Int {
        if let n = object(forKey: key) as? NSNumber { return n.intValue }
        if let s = string(forKey: key), let v = Int(s) { return v }
        if object(forKey: key) == nil { return fallback }
        return integer(forKey: key)
    }

    func doubleValue(_ key: String, fallback: Double) -> Double {
        if let n = object(forKey: key) as? NSNumber { return n.doubleValue }
        if let s = string(forKey: key), let v = Double(s) { return v }
        return object(forKey: key) as? Double ?? fallback
    }
}

private func computeState(at date: Date, snapshot: Snapshot?) -> DisplayState {
    var state = computeScene(at: date, snapshot: snapshot)
    if let s = snapshot {
        state.accent = Color(argb: s.accent)
        state.accentDeep = Color(argb: s.accentDeep)
        state.onAccent = Color(argb: s.onAccent)
    }
    return state
}

private func computeScene(at date: Date, snapshot: Snapshot?) -> DisplayState {
    guard let s = snapshot else {
        // 앱을 아직 한 번도 안 열었다 (위젯 갤러리 직후 등) — 낮의 인사
        return DisplayState(
            scene: .morning(slot: 1), darkCircles: false, remaining: nil,
            glow: 0.18, lang: Locale.current.identifier.hasPrefix("ko") ? "ko" : "en"
        )
    }

    let hour = Calendar.current.component(.hour, from: date)
    let sinceWake = (hour - s.wakeHour + 24) % 24
    let dayLength = (s.bedtimeHour - s.wakeHour + 24) % 24
    let isDaytime = dayLength == 0 || sinceWake < dayLength
    // Dart toddModeProvider와 동일 (개정 2026-08-15): 기상~취침을 활동
    // 개수로 균등 분할 — 2시간 고정 슬롯으로는 10개가 하루에 다 담기지 않는다.
    let effDayLength = dayLength == 0 ? 24 : dayLength
    let daySlot = min(sinceWake * daySlotNames.count / effDayLength, daySlotNames.count - 1)

    // 새 하루인데 앱이 아직 롤오버를 안 돌렸다 → 개수 미확정.
    // 어제 불을 남긴 채 넘어왔으면(미완+미소등) 다크서클은 추론 가능하다.
    if logicalDayKey(date, wakeHour: s.wakeHour) != s.dayKey {
        let restless = s.remaining > 0 && !s.lightsOut
        if isDaytime {
            return DisplayState(
                scene: .morning(slot: daySlot), darkCircles: restless,
                remaining: nil, glow: 0.18, lang: s.languageCode
            )
        }
        return DisplayState(
            scene: .asleep(satisfied: false), darkCircles: restless,
            remaining: nil, glow: 0.0, lang: s.languageCode
        )
    }

    let allDone = s.total > 0 && s.remaining == 0
    if s.lightsOut || allDone || (!isDaytime && s.total == 0) {
        return DisplayState(
            scene: .asleep(satisfied: s.lightsOut || allDone),
            darkCircles: s.darkCircles,
            remaining: nil, glow: 0.0, lang: s.languageCode
        )
    }
    if isDaytime {
        return DisplayState(
            scene: .day(slot: daySlot), darkCircles: s.darkCircles,
            remaining: s.total == 0 ? nil : s.remaining,
            glow: s.total == 0 ? 0.12 : (1 - s.brightness).clamped01,
            lang: s.languageCode
        )
    }
    let dazzle = (1 - s.brightness).clamped01
    return DisplayState(
        scene: dazzle >= 0.45 ? .nightSquint : .nightDoze,
        darkCircles: s.darkCircles,
        remaining: s.remaining,
        glow: dazzle,
        lang: s.languageCode
    )
}

private extension Double {
    var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
}

// MARK: - 스프라이트·문구

// Dart ToddDayActivity enum 순서와 반드시 일치할 것 (개정 2026-08-15: +3종)
private let daySlotNames = [
    "stretch", "coffee", "read", "doodle", "walk",
    "hum", "snack", "dance", "bubbles", "rest",
]

private extension DisplayState {
    var spriteName: String {
        let base: String
        switch scene {
        case .asleep: base = "todd_asleep"
        case .day(let slot), .morning(let slot): base = "todd_day_\(daySlotNames[slot])"
        case .nightSquint: base = "todd_night_squint"
        case .nightDoze: base = "todd_night_doze"
        }
        return darkCircles ? "\(base)_dc" : base
    }

    var ko: Bool { lang == "ko" }

    /// 알약 문구 — 개수가 있으면 (숫자, 라벨), 없으면 상태 한 마디
    var pillNumber: String? { remaining.map(String.init) }

    var pillLabel: String {
        if remaining != nil { return ko ? "남음" : "left" }
        switch scene {
        case .asleep(let satisfied):
            if satisfied { return ko ? "다 껐어!" : "Light's off" }
            return ko ? "새근새근" : "Fast asleep"
        case .morning: return ko ? "좋은 아침!" : "Good morning!"
        case .day: return ko ? "할 일이 없네" : "Nothing today"
        case .nightSquint, .nightDoze: return ko ? "남음" : "left"
        }
    }
}

// MARK: - 타임라인

private struct ToddEntry: TimelineEntry {
    let date: Date
    let state: DisplayState
}

private struct ToddProvider: TimelineProvider {
    func placeholder(in context: Context) -> ToddEntry {
        ToddEntry(
            date: .now,
            state: DisplayState(
                scene: .day(slot: 1), darkCircles: false, remaining: 3,
                glow: 0.65, lang: Locale.current.identifier.hasPrefix("ko") ? "ko" : "en"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ToddEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(ToddEntry(date: .now, state: computeState(at: .now, snapshot: Snapshot.load())))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ToddEntry>) -> Void) {
        // 매시 정각 엔트리 24개 — 일과 슬롯(2h)·취침·기상 전환을 모두 덮는다.
        // 앱이 상태를 바꾸면 updateWidget이 타임라인을 통째로 다시 뽑는다.
        let snapshot = Snapshot.load()
        let now = Date()

        // 스냅샷을 못 읽었으면(첫 설치 직후, 또는 잠금 중이라 데이터 보호에
        // 막힌 경우) 24시간짜리 타임라인을 깔면 안 된다 — 그 빈 결과가
        // ".atEnd"로 하루 종일 고정돼 위젯이 "Good morning"에서 안 바뀐다.
        // 짧게 다시 물어보게 해서 스스로 회복하도록 한다.
        guard let snapshot else {
            completion(
                Timeline(
                    entries: [ToddEntry(date: now, state: computeState(at: now, snapshot: nil))],
                    policy: .after(now.addingTimeInterval(15 * 60))
                )
            )
            return
        }

        var entries = [ToddEntry(date: now, state: computeState(at: now, snapshot: snapshot))]
        let cal = Calendar.current
        if let nextHour = cal.nextDate(
            after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime
        ) {
            for i in 0..<24 {
                let date = nextHour.addingTimeInterval(Double(i) * 3600)
                entries.append(ToddEntry(date: date, state: computeState(at: date, snapshot: snapshot)))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 뷰 (디자인 시스템 v2: 고정 다크 + 앰버, §11 블러 금지 → 그라데이션)

private struct ToddWidgetView: View {
    let entry: ToddEntry

    private var night: Bool {
        switch entry.state.scene {
        case .asleep, .nightSquint, .nightDoze: return true
        case .day, .morning: return false
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            Image(entry.state.spriteName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            pill
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .containerBackground(for: .widget) { background }
    }

    /// 방의 배경 — ink 바닥 + 우상단 코너 글로우(남은 빛) + 밤하늘 별
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.ink, Palette.inkDeep],
                startPoint: .top, endPoint: .bottom
            )
            GeometryReader { geo in
                let w = geo.size.width
                // §5.1 좌하단은 언제나 어둠에 남는다 — 글로우는 우상단만
                RadialGradient(
                    colors: [
                        entry.state.accent.opacity(0.62 * entry.state.glow),
                        entry.state.accent.opacity(0.20 * entry.state.glow),
                        .clear,
                    ],
                    center: UnitPoint(x: 1.06, y: -0.08),
                    startRadius: 0,
                    endRadius: w * 1.15
                )
                // 별 — 밤에만, 글로우가 닿지 않는 왼쪽 하늘에
                if night {
                    Circle().fill(Palette.textSecondary.opacity(0.55))
                        .frame(width: 3, height: 3)
                        .position(x: w * 0.14, y: geo.size.height * 0.12)
                    Circle().fill(Palette.textSecondary.opacity(0.35))
                        .frame(width: 2, height: 2)
                        .position(x: w * 0.30, y: geo.size.height * 0.22)
                    Circle().fill(Palette.textSecondary.opacity(0.40))
                        .frame(width: 2.5, height: 2.5)
                        .position(x: w * 0.08, y: geo.size.height * 0.34)
                }
            }
        }
    }

    /// 듀오링고 문법의 3D 알약 — blur 0 오프셋 압출 (§5.2)
    private var pill: some View {
        let hasCount = entry.state.pillNumber != nil
        let top: Color = hasCount ? entry.state.accent : Palette.surfaceHigh
        let deep: Color = hasCount ? entry.state.accentDeep : Palette.pillDeep
        let fg: Color = hasCount ? entry.state.onAccent : Palette.textPrimary

        return HStack(spacing: 4) {
            if let n = entry.state.pillNumber {
                Text(n)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Text(entry.state.pillLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .padding(.top, 3)
            } else {
                Text(entry.state.pillLabel)
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
            }
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 13)
        .padding(.vertical, 5)
        .background(
            ZStack {
                Capsule().fill(deep).offset(y: 3)
                Capsule().fill(top)
            }
        )
        .padding(.bottom, 3) // 압출면 자리
    }
}

// MARK: - 위젯 정의

struct ToddWidget: Widget {
    // Flutter 쪽 WidgetSnapshotService.iOSWidgetName과 일치해야 한다
    let kind: String = "ToddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ToddProvider()) { entry in
            ToddWidgetView(entry: entry)
        }
        .configurationDisplayName("Todd")
        .description("오늘 남은 불빛과 Todd의 하루 · Todd's day and the lights still on")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

@main
struct ToddWidgetBundle: WidgetBundle {
    var body: some Widget {
        ToddWidget()
    }
}

// MARK: - 프리뷰

#Preview(as: .systemSmall) {
    ToddWidget()
} timeline: {
    ToddEntry(
        date: .now,
        state: DisplayState(scene: .day(slot: 1), darkCircles: false, remaining: 3, glow: 0.7, lang: "ko")
    )
    ToddEntry(
        date: .now,
        state: DisplayState(scene: .nightSquint, darkCircles: true, remaining: 2, glow: 0.8, lang: "ko")
    )
    ToddEntry(
        date: .now,
        state: DisplayState(scene: .asleep(satisfied: true), darkCircles: false, remaining: nil, glow: 0, lang: "ko")
    )
}
