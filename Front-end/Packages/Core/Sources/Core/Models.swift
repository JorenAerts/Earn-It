import Foundation

// MARK: - Missions

public enum MissionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case math
    case shake

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .math: "Math problems"
        case .shake: "Shake the phone"
        }
    }

    /// Shown in the alarm title: "Earn It - Math Problem".
    public var alarmTitle: String {
        switch self {
        case .math: "Math Problem"
        case .shake: "Shake It"
        }
    }

    /// Unit label for `MissionConfig.target`.
    public var targetLabel: String {
        switch self {
        case .math: "problems"
        case .shake: "shakes"
        }
    }

    public var defaultTarget: Int {
        switch self {
        case .math: 3
        case .shake: 30
        }
    }
}

public enum MissionDifficulty: String, Codable, CaseIterable, Sendable, Identifiable {
    case easy, medium, hard
    public var id: String { rawValue }
}

public struct MissionConfig: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: MissionKind
    public var difficulty: MissionDifficulty
    /// Math: problems correct in a row. Shake: number of shakes.
    public var target: Int

    public init(id: UUID = UUID(), kind: MissionKind, difficulty: MissionDifficulty = .medium, target: Int? = nil) {
        self.id = id
        self.kind = kind
        self.difficulty = difficulty
        self.target = target ?? kind.defaultTarget
    }
}

// MARK: - Alarm plan

/// The single POC alarm. Stored as JSON so App Intents (and later extensions) can read it cheaply.
public struct AlarmPlan: Codable, Hashable, Sendable {
    public var id: UUID
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
        hour: Int = 7,
        minute: Int = 0,
        weekdays: Set<Int> = Set(1...7),
        missions: [MissionConfig] = [MissionConfig(kind: .math)],
        reArmMinutes: Int = 2,
        maxReArms: Int = 15,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.missions = missions
        self.reArmMinutes = reArmMinutes
        self.maxReArms = maxReArms
        self.isEnabled = isEnabled
    }

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

    public init(day: Date, firstEndedAt: Date? = nil, missionCompletedAt: Date? = nil,
                reArmCount: Int = 0, failSafeTriggered: Bool = false, followUpIDs: [UUID] = []) {
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
