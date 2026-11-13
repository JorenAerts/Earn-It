import Foundation
import SwiftData

/// One row per wake-up day. Streaks and stats are derived from these.
@Model
public final class DayLog {
    @Attribute(.unique) public var day: Date
    public var firstEndedAt: Date?
    public var missionCompletedAt: Date?
    public var reArmCount: Int
    public var failSafeTriggered: Bool

    public init(day: Date, firstEndedAt: Date? = nil, missionCompletedAt: Date? = nil,
                reArmCount: Int = 0, failSafeTriggered: Bool = false) {
        self.day = day
        self.firstEndedAt = firstEndedAt
        self.missionCompletedAt = missionCompletedAt
        self.reArmCount = reArmCount
        self.failSafeTriggered = failSafeTriggered
    }

    public convenience init(session: SessionState) {
        self.init(day: session.day, firstEndedAt: session.firstEndedAt,
                  missionCompletedAt: session.missionCompletedAt,
                  reArmCount: session.reArmCount, failSafeTriggered: session.failSafeTriggered)
    }
}

public enum StreakCalculator {
    /// Consecutive completed days ending today (or yesterday, if today isn't done yet).
    public static func currentStreak(completedDays: [Date], today: Date, calendar: Calendar = .current) -> Int {
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
