import Foundation

// MARK: - Missions

public enum MissionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case math
    case shake
    case qr

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .math: "Math problems"
        case .shake: "Shake the phone"
        case .qr: "Scan a code"
        }
    }

    /// Shown in the alarm title: "Earn It - Math Problem".
    public var alarmTitle: String {
        switch self {
        case .math: "Math Problem"
        case .shake: "Shake It"
        case .qr: "Scan Code"
        }
    }

    /// Unit label for `MissionConfig.target`.
    public var targetLabel: String {
        switch self {
        case .math: "problems"
        case .shake: "shakes"
        case .qr: "code"
        }
    }

    public var defaultTarget: Int {
        switch self {
        case .math: 3
        case .shake: 30
        case .qr: 1
        }
    }

    /// Allowed `target` values in setup; nil = target not configurable.
    public var targetRange: ClosedRange<Int>? {
        switch self {
        case .math: 1...20
        case .shake: 5...200
        case .qr: nil
        }
    }

    public var targetStep: Int {
        switch self {
        case .math: 1
        case .shake: 5
        case .qr: 1
        }
    }

    public var usesDifficulty: Bool {
        switch self {
        case .math, .shake: true
        case .qr: false
        }
    }

    /// Needs something registered at setup (e.g. the QR code to scan).
    public var needsPayload: Bool { self == .qr }
}

public enum MissionDifficulty: String, Codable, CaseIterable, Sendable, Identifiable {
    case easy, medium, hard
    public var id: String { rawValue }
}

public struct MissionConfig: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: MissionKind
    public var difficulty: MissionDifficulty
    /// Math: problems correct in a row. Shake: shakes. QR: unused (1).
    public var target: Int
    /// Mission-specific registered value. QR: the code's payload string.
    public var payload: String?

    public init(id: UUID = UUID(), kind: MissionKind, difficulty: MissionDifficulty = .medium,
                target: Int? = nil, payload: String? = nil) {
        self.id = id
        self.kind = kind
        self.difficulty = difficulty
        self.target = target ?? kind.defaultTarget
        self.payload = payload
    }

    /// Fully configured and playable.
    public var isReady: Bool {
        !kind.needsPayload || !(payload?.isEmpty ?? true)
    }

    /// One-line description for lists: "3 problems · medium", "Code registered".
    public var summary: String {
        switch kind {
        case .qr: isReady ? "Code registered" : "No code registered"
        case .math, .shake: "\(target) \(kind.targetLabel) · \(difficulty.rawValue)"
        }
    }
}

// MARK: - Alarm sound

/// Bundled alarm tones (App/Sounds/EarnIt_<rawValue>.caf). The same file rings via AlarmKit
/// and keeps playing in-app during the mission.
public enum AlarmSound: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic, chime, siren, digital, pulse

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: "Classic Beep"
        case .chime: "Morning Chime"
        case .siren: "Rising Siren"
        case .digital: "Digital"
        case .pulse: "Deep Pulse"
        }
    }

    /// Resource name without extension.
    public var resourceName: String { "EarnIt_\(rawValue)" }
    public var fileName: String { resourceName + ".caf" }
}

/// Decodes a mission or nil when its kind no longer exists.
private struct LossyMission: Decodable {
    let config: MissionConfig?
    init(from decoder: any Decoder) throws {
        config = try? MissionConfig(from: decoder)
    }
}

// MARK: - Alarm plan

/// The single POC alarm. Stored as JSON so App Intents (and later extensions) can read it cheaply.
public struct AlarmPlan: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Optional name shown in the list ("Work days", "Gym").
    public var label: String
    public var sound: AlarmSound
    public var hour: Int
    public var minute: Int
    /// Calendar weekday numbers, 1 = Sunday … 7 = Saturday. Empty = one-off (next occurrence).
    public var weekdays: Set<Int>
    public var missions: [MissionConfig]
    public var reArmMinutes: Int
    /// Fail-safe: after this many follow-ups the alarm gives up (nobody gets stuck).
    public var maxReArms: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        label: String = "",
        sound: AlarmSound = .classic,
        hour: Int = 7,
        minute: Int = 0,
        weekdays: Set<Int> = Set(1...7),
        missions: [MissionConfig] = [MissionConfig(kind: .math)],
        reArmMinutes: Int = 2,
        maxReArms: Int = 15,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.label = label
        self.sound = sound
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.missions = missions
        self.reArmMinutes = reArmMinutes
        self.maxReArms = maxReArms
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, sound, hour, minute, weekdays, missions, reArmMinutes, maxReArms, isEnabled
    }

    /// Tolerant decoding: alarms saved by older versions lack `label` / `sound`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        sound = try c.decodeIfPresent(AlarmSound.self, forKey: .sound) ?? .classic
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        weekdays = try c.decode(Set<Int>.self, forKey: .weekdays)
        // Lossy: missions removed from the app (e.g. the old "steps" kind) are dropped
        // instead of making the whole alarm list undecodable.
        let decoded = try c.decode([LossyMission].self, forKey: .missions).compactMap(\.config)
        // Never leave an alarm without a mission (it could then be stopped for free).
        missions = decoded.isEmpty ? [MissionConfig(kind: .math)] : decoded
        reArmMinutes = try c.decode(Int.self, forKey: .reArmMinutes)
        maxReArms = try c.decode(Int.self, forKey: .maxReArms)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
    }

    /// "07:00"
    public var timeText: String { String(format: "%02d:%02d", hour, minute) }

    /// "Every day", "Weekdays", "Mon, Wed", "Once".
    public var repeatText: String {
        switch weekdays {
        case []: return "Once"
        case Set(1...7): return "Every day"
        case Set(2...6): return "Weekdays"
        case [1, 7]: return "Weekends"
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            // Monday-first order for display.
            return [2, 3, 4, 5, 6, 7, 1].filter(weekdays.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// Every mission is configured (e.g. a QR code is registered).
    public var isReady: Bool { !missions.isEmpty && missions.allSatisfy(\.isReady) }

    /// Alarm title: app name + the mission(s) to solve, e.g. "Earn It - Math Problem + Shake It".
    public var alarmTitle: String {
        let missions = missions.map(\.kind.alarmTitle)
        return missions.isEmpty ? "Earn It" : "Earn It - " + missions.joined(separator: " + ")
    }

    /// Next time this plan rings strictly after `date`.
    public func nextFireDate(after date: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if fire > date, weekdays.isEmpty || weekdays.contains(weekday) {
                return fire
            }
        }
        return nil
    }
}

// MARK: - Wake session

/// State of today's wake-up. Written by the app and by App Intents (same process, standard UserDefaults).
public struct SessionState: Codable, Hashable, Sendable {
    /// Start of the day this session belongs to.
    public var day: Date
    public var firstEndedAt: Date?
    public var missionCompletedAt: Date?
    public var reArmCount: Int
    public var failSafeTriggered: Bool
    /// Follow-up alarm IDs currently scheduled (cancelled on mission success).
    public var followUpIDs: [UUID]
    /// The alarm (plan) that started this ring cycle: its missions, sound and re-ring settings apply.
    public var planID: UUID?

    public init(day: Date, firstEndedAt: Date? = nil, missionCompletedAt: Date? = nil,
                reArmCount: Int = 0, failSafeTriggered: Bool = false, followUpIDs: [UUID] = [],
                planID: UUID? = nil) {
        self.planID = planID
        self.day = day
        self.firstEndedAt = firstEndedAt
        self.missionCompletedAt = missionCompletedAt
        self.reArmCount = reArmCount
        self.failSafeTriggered = failSafeTriggered
        self.followUpIDs = followUpIDs
    }

    public var missionDone: Bool { missionCompletedAt != nil }

    /// This ring cycle is over (mission done or fail-safe hit).
    public var isFinished: Bool { missionDone || failSafeTriggered }

    /// An alarm has gone off and the mission is still outstanding.
    public var awaitingMission: Bool { firstEndedAt != nil && !missionDone && !failSafeTriggered }
}
