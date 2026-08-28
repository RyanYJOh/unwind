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
    /// 위젯 배경 (선택형 2026-08-28) — WidgetBackground.name. 모르는 값은 deepNight
    var background: String
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
            background: obj["background"] as? String ?? "deepNight",
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
            background: d.string(forKey: "background") ?? "deepNight",
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
    /// 위젯 배경 (선택형 2026-08-28) — SceneBackground의 장면 id
    var background: String = "deepNight"
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
        state.background = s.background
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

    /// 방의 배경 (선택형 2026-08-28) — 장면 + 우상단 코너 글로우(남은 빛).
    /// 장면은 SceneBackground가 그리고, 글로우는 모든 장면 위에 공통으로
    /// 얹힌다 — 어떤 배경에서도 "남은 빛" 게이지가 최상위 광원이다.
    private var background: some View {
        ZStack {
            SceneBackground(id: entry.state.background, night: night)
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


// MARK: - 위젯 배경 장면 (선택형 2026-08-28, 발주자 지시 — 8안 전부)
//
// Flutter 쪽 미러: lib/features/settings/widget_background_preview.dart —
// **장면을 고치면 두 곳을 함께 고칠 것.** 좌표는 158×158 기준으로 적고
// 기기 크기(141~170pt)에 비례 스케일한다.
//
// 설계 규칙 (조사 2026-08-28, prd-amendments):
// - 우상단은 코너 글로우의 자리 — 배경의 최대 밝기는 글로우 아래.
// - 좌하단은 어둠(§5.1), 하단 중앙(Todd 뒤)은 중간톤 이하.
// - iOS 18 Tinted 모드는 색을 luminanceToAlpha로 뭉갠다 — 구조는 전부
//   명도 대비로 잡는다. §11 블러 금지 — 발광은 다층 radial로 흉내낸다.

private struct SceneBackground: View {
    let id: String
    let night: Bool

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 158
            let sy = geo.size.height / 158
            ZStack {
                switch id {
                case "fireflies": fireflies(sx, sy)
                case "rainWindow": rainWindow(sx, sy)
                case "bigMoon": bigMoon(sx, sy)
                case "starrySea": starrySea(sx, sy)
                case "firstSnow": firstSnow(sx, sy)
                case "aurora": aurora(sx, sy)
                case "pastelDream": pastelDream(sx, sy)
                case "blanketFort": blanketFort(sx, sy)
                default: deepNight(sx, sy)
                }
            }
        }
    }

    // ── 공용 조각 ──────────────────────────────────────────────

    private func vGradient(_ stops: [(Double, Color)]) -> LinearGradient {
        LinearGradient(
            stops: stops.map { Gradient.Stop(color: $0.1, location: $0.0) },
            startPoint: .top, endPoint: .bottom
        )
    }

    /// 4점 스파클 (NitW·산리오 문법) — 어떤 크기에서도 읽힌다
    private func sparkle(_ x: Double, _ y: Double, _ r: Double,
                         _ sx: Double, _ sy: Double,
                         color: Color = Color(argb: 0xFFFFF6E8),
                         opacity: Double = 0.85) -> some View {
        let w = 0.22
        var p = Path()
        p.move(to: CGPoint(x: x, y: y - r))
        p.addQuadCurve(to: CGPoint(x: x + r, y: y),
                       control: CGPoint(x: x + r * w, y: y - r * w))
        p.addQuadCurve(to: CGPoint(x: x, y: y + r),
                       control: CGPoint(x: x + r * w, y: y + r * w))
        p.addQuadCurve(to: CGPoint(x: x - r, y: y),
                       control: CGPoint(x: x - r * w, y: y + r * w))
        p.addQuadCurve(to: CGPoint(x: x, y: y - r),
                       control: CGPoint(x: x - r * w, y: y - r * w))
        p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: sx, y: sy))
            .fill(color).opacity(opacity)
    }

    /// 가짜 블룸 — 동심원 알파 하강 (§11 블러 금지 준수)
    private func glowDot(_ x: Double, _ y: Double, _ r: Double,
                         _ sx: Double, _ sy: Double,
                         seed: Color, core: Color, strength: Double) -> some View {
        ZStack {
            Circle().fill(
                RadialGradient(
                    colors: [seed.opacity(0.9 * strength),
                             seed.opacity(0.18 * strength), .clear],
                    center: .center, startRadius: 0, endRadius: r * sx
                )
            )
            .frame(width: r * 2 * sx, height: r * 2 * sy)
            Circle().fill(core.opacity(strength))
                .frame(width: max(1.6, r * 0.34) * sx,
                       height: max(1.6, r * 0.34) * sy)
        }
        .position(x: x * sx, y: y * sy)
    }

    private func poly(_ pts: [(Double, Double)], _ sx: Double, _ sy: Double,
                      close: Bool = true) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: CGPoint(x: f.0, y: f.1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        if close { p.closeSubpath() }
        return p.applying(CGAffineTransform(scaleX: sx, y: sy))
    }

    // ── 장면들 ─────────────────────────────────────────────────

    /// 깊은 밤 — 기본 (기존 배경 그대로: ink 그라데이션 + 밤 별 3개)
    private func deepNight(_ sx: Double, _ sy: Double) -> some View {
        ZStack {
            LinearGradient(colors: [Palette.ink, Palette.inkDeep],
                           startPoint: .top, endPoint: .bottom)
            if night {
                Circle().fill(Palette.textSecondary.opacity(0.55))
                    .frame(width: 3, height: 3)
                    .position(x: 22 * sx, y: 19 * sy)
                Circle().fill(Palette.textSecondary.opacity(0.35))
                    .frame(width: 2, height: 2)
                    .position(x: 47 * sx, y: 35 * sy)
                Circle().fill(Palette.textSecondary.opacity(0.40))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: 13 * sx, y: 54 * sy)
            }
        }
    }

    /// 반딧불이 — 여름밤 숲, 따뜻한 점 = 남은 불빛의 시각 언어
    private func fireflies(_ sx: Double, _ sy: Double) -> some View {
        let seed = Color(argb: 0xFFFFD98A)
        let core = Color(argb: 0xFFFFF6E0)
        return ZStack {
            vGradient([(0, Color(argb: 0xFF0E1F1A)), (1, Color(argb: 0xFF070F0D))])
            // 좌하단 숲 기운 (어둠은 유지 — 미묘한 초록 들림만)
            RadialGradient(colors: [Color(argb: 0xFF16302A), .clear],
                           center: UnitPoint(x: 0.18, y: 0.88),
                           startRadius: 0, endRadius: 110 * sx)
                .opacity(0.7)
            // 침엽수 실루엣
            poly([(0, 158), (0, 110), (7, 96), (13, 110), (18, 100), (25, 116),
                  (31, 104), (39, 122), (45, 112), (52, 126), (52, 158)], sx, sy)
                .fill(Color(argb: 0xFF050A09))
            glowDot(22, 46, 9, sx, sy, seed: seed, core: core, strength: 0.9)
            glowDot(36, 62, 11, sx, sy, seed: seed, core: core, strength: 0.85)
            glowDot(14, 68, 8, sx, sy, seed: seed, core: core, strength: 0.7)
            glowDot(46, 34, 8, sx, sy, seed: seed, core: core, strength: 0.75)
            glowDot(43, 101, 7, sx, sy, seed: seed, core: core, strength: 0.6)
            glowDot(76, 42, 6, sx, sy, seed: seed, core: core, strength: 0.5)
        }
    }

    /// 창가의 비 — 차가운 바깥, 따뜻한 안 (Coffee Talk 구조)
    private func rainWindow(_ sx: Double, _ sy: Double) -> some View {
        let streak = Color(argb: 0xFF9FB6D4)
        return ZStack {
            vGradient([(0, Color(argb: 0xFF22314E)), (0.55, Color(argb: 0xFF18243A)),
                       (1, Color(argb: 0xFF0C1422))])
            // 빗줄기 — 13° 기울인 캡슐, 세로 알파 램프
            ForEach(Array([(14.0, 18.0, 26.0), (33.0, 8.0, 34.0), (52.0, 26.0, 28.0),
                           (70.0, 6.0, 30.0), (24.0, 60.0, 24.0), (46.0, 72.0, 26.0)]
                .enumerated()), id: \.offset) { _, r in
                Capsule()
                    .fill(LinearGradient(
                        colors: [streak.opacity(0), streak.opacity(0.5), streak.opacity(0)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 1.3 * sx, height: r.2 * sy)
                    .rotationEffect(.degrees(13))
                    .position(x: r.0 * sx, y: (r.1 + r.2 / 2) * sy)
                    .opacity(0.6)
            }
            // 유리에 맺힌 물방울 — 밝은 림 + 스페큘러 점
            ForEach(Array([(26.0, 46.0, 4.2), (58.0, 30.0, 3.2),
                           (41.0, 88.0, 3.6), (14.0, 72.0, 2.6)]
                .enumerated()), id: \.offset) { _, d in
                ZStack {
                    Ellipse().fill(RadialGradient(
                        colors: [Color(argb: 0xFFB9CCE4).opacity(0.85),
                                 Color(argb: 0xFF4A6284).opacity(0.25)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0, endRadius: d.2 * 1.3 * sx))
                        .frame(width: d.2 * 2 * sx, height: d.2 * 2.5 * sy)
                    Circle().fill(Color(argb: 0xFFDCE8F6).opacity(0.9))
                        .frame(width: 1.8 * sx, height: 1.8 * sy)
                        .offset(x: -d.2 * 0.38 * sx, y: -d.2 * 0.5 * sy)
                }
                .position(x: d.0 * sx, y: d.1 * sy)
            }
            // 창틀 — 왼쪽 세로 + 가로 살 (실내에서 보는 시점의 근거)
            HStack { Rectangle().fill(Color(argb: 0xFF080D16)).frame(width: 5 * sx); Spacer() }
            VStack {
                Spacer().frame(height: 60 * sy)
                Rectangle().fill(Color(argb: 0xFF080D16).opacity(0.5)).frame(height: 4 * sy)
                Spacer()
            }
        }
    }

    /// 큰 달 — 하나의 큰 것이 백 개의 작은 것을 이긴다 (지브리 문법)
    private func bigMoon(_ sx: Double, _ sy: Double) -> some View {
        let moon = Color(argb: 0xFFE8DFC4)
        return ZStack {
            vGradient([(0, Color(argb: 0xFF0B1026)), (0.55, Color(argb: 0xFF182642)),
                       (0.84, Color(argb: 0xFF3A3D5E)), (0.93, Color(argb: 0xFF6E5A66)),
                       (1, Color(argb: 0xFF120F1C))])
            // 달무리 2겹 + 본체 (좌상단 — 우상단 글로우와 무게 균형)
            Circle().fill(RadialGradient(colors: [moon.opacity(0.20), .clear],
                                         center: .center, startRadius: 0,
                                         endRadius: 40 * sx))
                .frame(width: 80 * sx, height: 80 * sy)
                .position(x: 44 * sx, y: 42 * sy)
            Circle().fill(moon)
                .frame(width: 34 * sx, height: 34 * sy)
                .position(x: 44 * sx, y: 42 * sy)
            // 달 바다 — 8% 대비의 얼룩 (더 진하면 치즈가 된다)
            Circle().fill(Color(argb: 0xFFD8CDAE).opacity(0.55))
                .frame(width: 9 * sx, height: 9 * sy).position(x: 38 * sx, y: 37 * sy)
            Circle().fill(Color(argb: 0xFFD8CDAE).opacity(0.45))
                .frame(width: 6.4 * sx, height: 6.4 * sy).position(x: 50 * sx, y: 47 * sy)
            Circle().fill(Color(argb: 0xFFD8CDAE).opacity(0.4))
                .frame(width: 4.8 * sx, height: 4.8 * sy).position(x: 44 * sx, y: 52 * sy)
            sparkle(84, 26, 3.4, sx, sy)
            sparkle(20, 84, 2.8, sx, sy, opacity: 0.7)
            sparkle(70, 66, 2.2, sx, sy, opacity: 0.55)
            // 언덕 실루엣
            poly([(0, 158), (0, 130), (22, 121), (42, 128), (66, 117), (94, 127),
                  (128, 114), (158, 125), (158, 158)], sx, sy)
                .fill(Color(argb: 0xFF0A0812))
        }
    }

    /// 밤바다 — 가로 띠 셋 + 글로우의 반사 (가장 싸고 가장 우아한 안)
    private func starrySea(_ sx: Double, _ sy: Double) -> some View {
        ZStack {
            vGradient([(0, Color(argb: 0xFF131B32)), (0.7, Color(argb: 0xFF22314C)),
                       (1, Color(argb: 0xFF4E4A5C))])
            VStack(spacing: 0) {
                Spacer().frame(height: 88 * sy)
                Rectangle().fill(vGradient([(0, Color(argb: 0xFF33465E)),
                                            (1, Color(argb: 0xFF16222F))]))
            }
            // 수평선의 따뜻한 실선 — 이 한 줄이 하늘을 하늘로 만든다
            VStack {
                Spacer().frame(height: 86 * sy)
                Rectangle().fill(Color(argb: 0xFF8A7A72).opacity(0.55))
                    .frame(height: max(1, 1.6 * sy))
                Spacer()
            }
            // 글로우의 물 반사 — 배경이 조명에 반응하는 것처럼 보이는 이유.
            // 조명 색을 따라가도록 accent가 아닌 고정 앰버 대신 틴트를 물려받게
            // 하려면 스냅샷 accent가 필요하지만, 배경은 DisplayState를 모른다 —
            // 반사는 위에 얹히는 코너 글로우가 이미 색을 나른다. 여기선 중립
            // 웜톤 한 겹만 깐다 (조명 색이 바뀌어도 깨지지 않는 값).
            // 반사 — 폭이 다른 띠 3겹으로 좌우 가장자리를 흩는다
            // (한 장짜리 사각 띠는 나무 기둥처럼 읽힌다)
            ForEach(Array([(26.0, 0.10), (17.0, 0.11), (9.0, 0.12)]
                .enumerated()), id: \.offset) { _, band in
                VStack(spacing: 0) {
                    Spacer().frame(height: 88 * sy)
                    HStack {
                        Spacer().frame(width: (109 - band.0 / 2) * sx)
                        Rectangle().fill(vGradient([
                            (0, Color(argb: 0xFFFFB224).opacity(band.1)),
                            (1, Color(argb: 0xFFFFB224).opacity(0)),
                        ])).frame(width: band.0 * sx)
                        Spacer()
                    }
                }
            }
            ForEach(Array([(103.0, 96.0, 12.0, 0.22), (100.0, 108.0, 18.0, 0.16),
                           (105.0, 120.0, 10.0, 0.12)].enumerated()),
                    id: \.offset) { _, b in
                Capsule().fill(Color(argb: 0xFFFFB224).opacity(b.3))
                    .frame(width: b.2 * sx, height: 2 * sy)
                    .position(x: (b.0 + b.2 / 2) * sx, y: (b.1 + 1) * sy)
            }
            sparkle(24, 30, 3.0, sx, sy)
            sparkle(58, 18, 2.4, sx, sy, opacity: 0.7)
            sparkle(38, 56, 2.0, sx, sy, opacity: 0.5)
            sparkle(78, 40, 1.8, sx, sy, opacity: 0.45)
        }
    }

    /// 첫눈 — 침엽수 2겹과 세 크기의 눈, 창문 하나 (158pt 생존력 1위)
    private func firstSnow(_ sx: Double, _ sy: Double) -> some View {
        ZStack {
            vGradient([(0, Color(argb: 0xFF1B2740)), (0.6, Color(argb: 0xFF121B2C)),
                       (1, Color(argb: 0xFF0A101A))])
            poly([(0, 158), (0, 118), (10, 100), (19, 118), (25, 106), (35, 126),
                  (43, 110), (54, 132), (61, 118), (71, 138), (71, 158)], sx, sy)
                .fill(Color(argb: 0xFF0C131E))
            poly([(28, 158), (28, 126), (37, 110), (45, 126), (51, 115), (60, 133),
                  (67, 119), (77, 139), (77, 158)], sx, sy)
                .fill(Color(argb: 0xFF080D16))
            ForEach(Array([(22.0, 26.0, 2.2, 0.9), (47.0, 14.0, 1.6, 0.75),
                           (66.0, 34.0, 2.0, 0.8), (14.0, 54.0, 1.5, 0.65),
                           (38.0, 46.0, 1.2, 0.55), (58.0, 62.0, 1.8, 0.7),
                           (30.0, 78.0, 1.4, 0.5), (72.0, 18.0, 1.3, 0.6),
                           (80.0, 70.0, 1.5, 0.45), (10.0, 94.0, 1.7, 0.4)]
                .enumerated()), id: \.offset) { _, f in
                Circle().fill(Color(argb: 0xFFE8F0FA).opacity(f.3))
                    .frame(width: f.2 * 2 * sx, height: f.2 * 2 * sy)
                    .position(x: f.0 * sx, y: f.1 * sy)
            }
            // 숲 속 창문 하나 — "누군가 집에 있다"는 신호
            ZStack {
                Circle().fill(Color(argb: 0xFFFFC96B).opacity(0.13))
                    .frame(width: 12 * sx, height: 12 * sy)
                Circle().fill(Color(argb: 0xFFFFC96B).opacity(0.85))
                    .frame(width: 5.2 * sx, height: 5.2 * sy)
            }
            .position(x: 47 * sx, y: 132 * sy)
        }
    }

    /// 오로라 — 초록 아래·보라 위 (물리를 어기면 가짜로 보인다)
    private func aurora(_ sx: Double, _ sy: Double) -> some View {
        func curtain(_ pts: [(Double, Double)], _ c1: Color, _ c2: Color,
                     top: Double, mid: Double) -> some View {
            var p = Path()
            p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for i in stride(from: 1, to: pts.count - 1, by: 2) {
                p.addQuadCurve(to: CGPoint(x: pts[i + 1].0, y: pts[i + 1].1),
                               control: CGPoint(x: pts[i].0, y: pts[i].1))
            }
            p.closeSubpath()
            let scaled = p.applying(CGAffineTransform(scaleX: sx, y: sy))
            let cx = scaled.boundingRect.midX
            // 커튼을 두 번 — 넓게 흩은 겹 + 본체. 가장자리가 잎사귀처럼
            // 딱딱해지는 것을 막는다 (§11 블러 금지 — 겹침으로 흉내)
            return ZStack {
                ForEach(Array([(1.45, 0.35), (1.0, 1.0)].enumerated()),
                        id: \.offset) { _, pass in
                    scaled.applying(
                        CGAffineTransform(translationX: cx * (1 - pass.0), y: 0)
                            .scaledBy(x: pass.0, y: 1)
                    )
                    .fill(LinearGradient(stops: [
                        .init(color: c1.opacity(top * pass.1), location: 0),
                        .init(color: c2.opacity(mid * pass.1), location: 0.45),
                        .init(color: c2.opacity(0), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                }
            }
        }
        let violet = Color(argb: 0xFF9A5FD0)
        let teal = Color(argb: 0xFF4FD9A8)
        return ZStack {
            vGradient([(0, Color(argb: 0xFF0A1024)), (1, Color(argb: 0xFF060A16))])
            curtain([(8, 0), (22, 26), (24, 78), (30, 98), (18, 122),
                     (4, 90), (2, 58), (2, 30), (8, 0)], violet, teal,
                    top: 0.55, mid: 0.45)
            curtain([(44, 0), (60, 30), (58, 84), (63, 104), (53, 124),
                     (38, 88), (36, 56), (38, 28), (44, 0)], violet, teal,
                    top: 0.38, mid: 0.30)
            curtain([(78, 0), (89, 22), (88, 64), (93, 82), (85, 96),
                     (72, 66), (71, 40), (73, 20), (78, 0)], violet, teal,
                    top: 0.27, mid: 0.21)
            sparkle(112, 24, 2.6, sx, sy)
            sparkle(132, 58, 2.2, sx, sy, opacity: 0.7)
            sparkle(96, 74, 1.8, sx, sy, opacity: 0.5)
            sparkle(26, 110, 1.8, sx, sy, opacity: 0.4)
        }
    }

    /// 몽글몽글 — 자두빛 검정 위 파스텔 (산리오 밤 문법)
    private func pastelDream(_ sx: Double, _ sy: Double) -> some View {
        let cream = Color(argb: 0xFFFFF3C4)
        let gold = Color(argb: 0xFFF7D774)
        // 초승달 = 큰 원 − 물린 원 (iOS 17 Path.subtracting)
        var big = Path()
        big.addEllipse(in: CGRect(x: 26, y: 22, width: 40, height: 40))
        var bite = Path()
        bite.addEllipse(in: CGRect(x: 38, y: 16, width: 40, height: 40))
        let crescent = big.subtracting(bite)
            .applying(CGAffineTransform(scaleX: sx, y: sy))
        return ZStack {
            vGradient([(0, Color(argb: 0xFF251A38)), (0.6, Color(argb: 0xFF1C1329)),
                       (1, Color(argb: 0xFF120C1B))])
            // 스캘럽 구름 — 둥근 혹들, 채도는 낮게
            ForEach(Array([(0.0, 78.0, 84.0, 26.0, 0.55),
                           (92.0, 104.0, 66.0, 22.0, 0.5)].enumerated()),
                    id: \.offset) { _, c in
                ZStack {
                    Capsule().fill(Color(argb: 0xFF392B52))
                        .frame(width: c.2 * sx, height: c.3 * sy)
                    Circle().fill(Color(argb: 0xFF392B52))
                        .frame(width: c.3 * 1.3 * sx, height: c.3 * 1.3 * sy)
                        .offset(x: -c.2 * 0.2 * sx, y: -c.3 * 0.3 * sy)
                    Circle().fill(Color(argb: 0xFF392B52))
                        .frame(width: c.3 * 1.0 * sx, height: c.3 * 1.0 * sy)
                        .offset(x: c.2 * 0.22 * sx, y: -c.3 * 0.22 * sy)
                }
                .position(x: (c.0 + c.2 / 2) * sx, y: (c.1 + c.3 / 2) * sy)
                .opacity(c.4)
            }
            // 달무리 — 평면 원은 원판 자국이 남는다. radial로 흩어 준다
            Circle().fill(RadialGradient(
                colors: [cream.opacity(0.12), cream.opacity(0)],
                center: .center, startRadius: 0, endRadius: 34 * sx))
                .frame(width: 68 * sx, height: 68 * sy)
                .position(x: 46 * sx, y: 34 * sy)
            crescent.fill(cream)
            sparkle(80, 20, 3.6, sx, sy, color: gold)
            sparkle(22, 58, 2.8, sx, sy, color: gold, opacity: 0.8)
            sparkle(96, 52, 2.2, sx, sy, color: gold, opacity: 0.6)
            sparkle(66, 74, 1.8, sx, sy, color: gold, opacity: 0.45)
        }
    }

    /// 이불 속 — 글로우가 배경이 아니라 손전등 그 자체가 되는 안.
    /// 주름은 우상단(광원)을 향해 모인다.
    private func blanketFort(_ sx: Double, _ sy: Double) -> some View {
        func fold(_ pts: [(Double, Double)], _ o: Double) -> some View {
            poly(pts, sx, sy).fill(LinearGradient(
                colors: [Color(argb: 0xFF3A2534).opacity(0.85 * o),
                         Color(argb: 0xFF3A2534).opacity(0)],
                startPoint: .top, endPoint: .bottom))
        }
        return ZStack {
            vGradient([(0, Color(argb: 0xFF2A1B26)), (0.5, Color(argb: 0xFF180F18)),
                       (1, Color(argb: 0xFF0C070C))])
            fold([(79, 0), (12, 158), (0, 158), (0, 0)], 0.5)
            fold([(79, 0), (40, 158), (26, 158), (70, 0)], 0.38)
            fold([(79, 0), (123, 158), (110, 158), (72, 0)], 0.3)
            // 천장 스캘럽 — 이불의 밑단이 늘어진 모양
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 158, y: 0))
                p.addLine(to: CGPoint(x: 158, y: 18))
                var x = 158.0
                while x > 0 {
                    p.addQuadCurve(to: CGPoint(x: x - 18, y: 18),
                                   control: CGPoint(x: x - 9, y: 27))
                    x -= 18
                }
                p.closeSubpath()
            }
            .applying(CGAffineTransform(scaleX: sx, y: sy))
            .fill(Color(argb: 0xFF3A2534).opacity(0.55))
            Rectangle().fill(Color(argb: 0xFF241722))
                .frame(height: 11 * sy)
                .position(x: 79 * sx, y: 5.5 * sy)
        }
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
