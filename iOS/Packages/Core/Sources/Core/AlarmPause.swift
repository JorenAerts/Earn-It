import Foundation

/// "Pause all alarms" (vacation mode). `until` = the start of the day alarms ring again;
/// nil = paused until the user resumes.
public struct AlarmPause: Codable, Hashable, Sendable {
    public var until: Date?

    public init(until: Date?) {
        self.until = until
    }
}

/// Pure rules for pausing alarms.
public enum PausePolicy {
    /// Ways to pause, shown in Settings › Pause all alarms.
    public enum Option: Hashable, Sendable, Identifiable {
        /// Skip the next `days` days (starting tomorrow; the rest of today is paused too).
        case days(Int)
        /// Alarms ring again from this day on.
        case untilDay(Date)
        case indefinitely

        public var id: String {
            switch self {
            case .days(let n): "days-\(n)"
            case .untilDay(let d): "until-\(d.timeIntervalSince1970)"
            case .indefinitely: "indefinitely"
            }
        }
    }

    public static func pause(_ option: Option, now: Date, calendar: Calendar = .current) -> AlarmPause {
        let today = calendar.startOfDay(for: now)
        switch option {
        case .days(let n):
            return AlarmPause(until: calendar.date(byAdding: .day, value: max(1, n) + 1, to: today))
        case .untilDay(let day):
            let start = calendar.startOfDay(for: day)
            let earliest = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return AlarmPause(until: max(start, earliest))
        case .indefinitely:
            return AlarmPause(until: nil)
        }
    }

    /// Is a pause in effect at `now`? An expired pause counts as not paused.
    public static func isPaused(_ pause: AlarmPause?, at now: Date) -> Bool {
        guard let pause else { return false }
        guard let until = pause.until else { return true }
        return now < until
    }

    /// The pause has run out and should be cleared (normal schedule restored).
    public static func isExpired(_ pause: AlarmPause?, at now: Date) -> Bool {
        guard let until = pause?.until else { return false }
        return now >= until
    }

    /// First ring of `plan` at or after the end of the pause (nil when paused indefinitely).
    public static func firstRing(of plan: AlarmPlan, after pause: AlarmPause, calendar: Calendar = .current) -> Date? {
        guard let until = pause.until else { return nil }
        return plan.nextFireDate(after: until.addingTimeInterval(-1), calendar: calendar)
    }

    /// Drops rings that fall inside the pause.
    public static func filter(_ rings: [Date], pause: AlarmPause?, now: Date) -> [Date] {
        guard isPaused(pause, at: now) else { return rings }
        guard let until = pause?.until else { return [] }
        return rings.filter { $0 >= until }
    }
}
