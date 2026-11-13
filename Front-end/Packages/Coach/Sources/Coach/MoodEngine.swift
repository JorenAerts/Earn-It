import Core
import Foundation

/// One finished day, as the coach sees it (mapped from `DayLog`).
public struct DaySummary: Equatable, Sendable {
    public var day: Date
    public var completed: Bool
    public var reArms: Int
    public var failSafe: Bool

    public init(day: Date, completed: Bool, reArms: Int, failSafe: Bool) {
        self.day = day
        self.completed = completed
        self.reArms = reArms
        self.failSafe = failSafe
    }
}

/// Everything the mood depends on. Pure input → `MoodEngine.evaluate`.
public struct CoachInput: Sendable {
    public var now: Date
    /// A ringing cycle is waiting for its mission.
    public var missionDue: Bool
    /// Today's ring cycle (re-rings, completion, fail-safe).
    public var session: SessionState?
    public var history: [DaySummary]
    public var nextAlarm: Date?

    public init(now: Date, missionDue: Bool, session: SessionState?, history: [DaySummary], nextAlarm: Date?) {
        self.now = now
        self.missionDue = missionDue
        self.session = session
        self.history = history
        self.nextAlarm = nextAlarm
    }
}

public enum MoodEngine {
    /// Re-rings at which anger peaks (1.0).
    public static let maxAngerReRings = 5
    public static let streakMilestones: Set<Int> = [3, 7, 14, 30, 50, 100, 200, 365]

    /// First matching rule wins.
    public static func evaluate(_ input: CoachInput, calendar: Calendar = .current) -> CoachState {
        let completedDays = input.history.filter(\.completed).map(\.day)
        let streak = StreakCalculator.currentStreak(completedDays: completedDays, today: input.now, calendar: calendar)

        // 1. Alarm is ringing / mission open: suspicious, then angrier with every re-ring.
        if input.missionDue {
            let reArms = input.session?.reArmCount ?? 0
            if reArms == 0 { return CoachState(mood: .suspicious, context: .ringing) }
            return CoachState(mood: .angry, context: .reRing,
                              anger: Double(reArms) / Double(maxAngerReRings))
        }

        // 2. Today's cycle finished.
        if let session = input.session, calendar.isDate(session.day, inSameDayAs: input.now) {
            if session.missionDone {
                if streakMilestones.contains(streak) { return CoachState(mood: .proud, context: .streakMilestone) }
                if session.reArmCount == 0 { return CoachState(mood: .proud, context: .firstTry) }
                return CoachState(mood: .proud, context: .missionSuccess)
            }
            if session.failSafeTriggered { return CoachState(mood: .disappointed, context: .failSafe) }
        }

        // 3. Streak just broken: had a streak that ended yesterday-ago, within the last week.
        if streak == 0, let last = completedDays.max(),
           let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last),
                                              to: calendar.startOfDay(for: input.now)).day,
           (2...7).contains(days) {
            return CoachState(mood: .disappointed, context: .streakBroken)
        }

        // 4. No alarm planned.
        guard input.nextAlarm != nil else { return CoachState(mood: .calm, context: .noAlarm) }

        // 5. Evening / night before an alarm.
        let hour = calendar.component(.hour, from: input.now)
        if hour >= 21 || hour < 4 { return CoachState(mood: .calm, context: .night) }

        return CoachState(mood: .calm, context: .idle)
    }
}
