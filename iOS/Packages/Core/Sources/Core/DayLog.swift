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

extension DayLog {
    public var values: DayLogRule.Values {
        DayLogRule.Values(day: day, firstEndedAt: firstEndedAt, missionCompletedAt: missionCompletedAt,
                          reArmCount: reArmCount, failSafeTriggered: failSafeTriggered)
    }

    public convenience init(_ values: DayLogRule.Values) {
        self.init(day: values.day, firstEndedAt: values.firstEndedAt, missionCompletedAt: values.missionCompletedAt,
                  reArmCount: values.reArmCount, failSafeTriggered: values.failSafeTriggered)
    }

    public func apply(_ values: DayLogRule.Values) {
        firstEndedAt = values.firstEndedAt
        missionCompletedAt = values.missionCompletedAt
        reArmCount = values.reArmCount
        failSafeTriggered = values.failSafeTriggered
    }
}

/// What a finished ring cycle means for its day's log. One row per day, but a day can have
/// several cycles (a nap alarm after the morning): the first completed cycle is the day's record;
/// a fail-safe is logged too, and a later success the same day replaces it.
public enum DayLogRule {
    public struct Values: Equatable, Sendable {
        public var day: Date
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

        public init(session: SessionState) {
            self.init(day: session.day, firstEndedAt: session.firstEndedAt, missionCompletedAt: session.missionCompletedAt,
                      reArmCount: session.reArmCount, failSafeTriggered: session.failSafeTriggered && !session.missionDone)
        }

        public var completed: Bool { missionCompletedAt != nil }
    }

    /// The row to store for `cycle`'s day, or nil to leave `existing` as it is.
    public static func merge(existing: Values?, cycle: SessionState) -> Values? {
        guard cycle.isFinished else { return nil }
        let new = Values(session: cycle)
        guard let existing else { return new }
        if existing.completed { return nil }          // the first completed cycle stays the day's record
        if new.completed { return new }               // success after an earlier fail-safe
        return nil                                     // fail-safe again: nothing new
    }
}

public enum StreakCalculator {
    /// Longest run of consecutive completed days ever.
    public static func bestStreak(completedDays: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

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
