import Core
import Foundation
import Localization

/// The character's name and pronoun, in one place.
public enum CoachIdentity {
    public static let name = "Gloop"
    /// For copy like "Gloop perks up when …, he's bouncing again."
    public static let pronoun = "he"
}

/// How well the user keeps up with their mornings, 0…1. Drives how perky or droopy the slime looks.
/// Recomputed from the history every time, so it never drifts.
public enum SlimeVitality {
    /// Where a brand-new user starts: healthy, but room to grow.
    public static let start = 0.75
    static let window = 14
    static let decay = 0.85
    /// How much the starting value still counts (in "days"), so one bad morning isn't a collapse.
    static let priorWeight = 1.2

    /// Score of one alarm day: first ring 1.0, −0.1 per re-ring (min 0.5), missed / fail-safe 0.
    public static func score(_ day: DaySummary) -> Double {
        guard day.completed else { return 0 }
        return max(0.5, 1 - 0.1 * Double(day.reArms))
    }

    /// - Parameters:
    ///   - history: logged mornings (finished or fail-safe).
    ///   - wasAlarmDay: whether an alarm should have rung that day (enabled, not paused). Unlogged
    ///     alarm days after the first logged morning count as missed; days without an alarm are
    ///     ignored. Today only counts once logged.
    public static func compute(history: [DaySummary], now: Date, calendar: Calendar = .current,
                               wasAlarmDay: (Date) -> Bool = { _ in false }) -> Double {
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(history.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { a, _ in a })
        // Before the first logged morning the user wasn't using the app yet: nothing counts as missed.
        let firstDay = byDay.keys.min()
        var weighted = priorWeight * start
        var weights = priorWeight
        for age in 0..<window {
            guard let day = calendar.date(byAdding: .day, value: -age, to: today) else { continue }
            let value: Double
            if let log = byDay[day] {
                value = score(log)
            } else if age > 0, let firstDay, day > firstDay, wasAlarmDay(day) {
                value = 0
            } else {
                continue
            }
            let w = pow(decay, Double(age))
            weighted += w * value
            weights += w
        }
        let streak = StreakCalculator.currentStreak(completedDays: history.filter(\.completed).map(\.day),
                                                    today: now, calendar: calendar)
        let bonus = min(0.1, Double(streak) * 0.02)
        return min(1, max(0, weighted / weights + bonus))
    }

    /// One line for Settings / Progress.
    public static func summary(_ vitality: Double) -> String {
        let name = CoachIdentity.name
        switch vitality {
        case 0.8...: return L10n.tr("\(name) is bouncing. Keep getting up on the first ring.")
        case 0.5..<0.8: return L10n.tr("\(name) is doing fine. A few first-ring mornings and he'll bounce.")
        case 0.25..<0.5: return L10n.tr("\(name) is starting to sag. Snoozes and misses make him droop.")
        default: return L10n.tr("\(name) has melted into a puddle. Three good mornings in a row will perk him up.")
        }
    }
}
