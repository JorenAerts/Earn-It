import Core
import Foundation

/// Everything the home-screen and Lock Screen widgets show, written by the app into the
/// shared App Group and read by the widget extension (which can't see the app's database).
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public enum DayMark: String, Codable, Sendable { case done, failed, none }

    public var generatedAt: Date
    /// Start of the most recent day with a finished mission.
    public var lastCompletedDay: Date?
    /// Streak as of `generatedAt` (use `streak(at:)` for display).
    public var streak: Int
    public var bestStreak: Int
    public var xp: Int
    /// Oldest → today (as of `generatedAt`), 14 entries.
    public var lastDays: [DayMark]
    /// Most impressive medals first, max 3 (Medal raw values).
    public var recentMedals: [String]
    public var mood: CoachMood
    public var coachLine: String
    public var isPro: Bool
    public var nextAlarm: Date?

    public init(generatedAt: Date, lastCompletedDay: Date?, streak: Int, bestStreak: Int, xp: Int,
                lastDays: [DayMark], recentMedals: [String], mood: CoachMood, coachLine: String,
                isPro: Bool, nextAlarm: Date?) {
        self.generatedAt = generatedAt
        self.lastCompletedDay = lastCompletedDay
        self.streak = streak
        self.bestStreak = bestStreak
        self.xp = xp
        self.lastDays = lastDays
        self.recentMedals = recentMedals
        self.mood = mood
        self.coachLine = coachLine
        self.isPro = isPro
        self.nextAlarm = nextAlarm
    }

    public var progress: RankProgress { RankProgress(xp: xp) }
    public var medals: [Medal] { recentMedals.compactMap(Medal.init(rawValue:)) }

    /// The streak as it should read at `date`: it survives until the end of the day after the
    /// last finished mission, then drops to 0 (the widget refreshes itself at midnight).
    public func streak(at date: Date, calendar: Calendar = .current) -> Int {
        guard let last = lastCompletedDay else { return 0 }
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              calendar.startOfDay(for: last) >= yesterday
        else { return 0 }
        return streak
    }

    public func completedToday(at date: Date, calendar: Calendar = .current) -> Bool {
        lastCompletedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
    }

    /// The 14-day strip shifted to `date` (days after `generatedAt` have no data yet).
    public func days(at date: Date, calendar: Calendar = .current) -> [DayMark] {
        let shift = calendar.dateComponents([.day], from: calendar.startOfDay(for: generatedAt),
                                            to: calendar.startOfDay(for: date)).day ?? 0
        guard shift > 0 else { return lastDays }
        return Array((lastDays + Array(repeating: .none, count: min(shift, 14))).suffix(14))
    }

    /// Builds the snapshot from the full wake-up history.
    public static func make(history: [DaySummary], now: Date, state: CoachState, line: String,
                            isPro: Bool, nextAlarm: Date?, calendar: Calendar = .current) -> WidgetSnapshot {
        let completed = history.filter(\.completed).map(\.day)
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(history.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { a, _ in a })
        let lastDays: [DayMark] = (0..<14).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today), let log = byDay[day] else { return .none }
            return log.completed ? .done : (log.failSafe ? .failed : .none)
        }
        let earned = MedalRules.earned(history, calendar: calendar)
        let medals = Medal.allCases.reversed().filter(earned.contains).prefix(3).map(\.rawValue)
        return WidgetSnapshot(
            generatedAt: now,
            lastCompletedDay: completed.max().map { calendar.startOfDay(for: $0) },
            streak: StreakCalculator.currentStreak(completedDays: completed, today: now, calendar: calendar),
            bestStreak: StreakCalculator.bestStreak(completedDays: completed, calendar: calendar),
            xp: XPRules.totalXP(history, calendar: calendar),
            lastDays: lastDays,
            recentMedals: medals,
            mood: state.mood,
            coachLine: line,
            isPro: isPro,
            nextAlarm: nextAlarm)
    }

    /// Shown in the widget gallery and before the app has written anything.
    public static let placeholder = WidgetSnapshot(
        generatedAt: .now, lastCompletedDay: Calendar.current.startOfDay(for: .now), streak: 12, bestStreak: 21,
        xp: 1_240, lastDays: Array(repeating: .done, count: 12) + [.failed, .done],
        recentMedals: [Medal.streak7.rawValue, Medal.hatTrick.rawValue, Medal.firstTry.rawValue],
        mood: .proud, coachLine: "Twelve days straight. Promotion material, soldier.", isPro: true, nextAlarm: nil)
}
