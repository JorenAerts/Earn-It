import Foundation

/// Military ranks, earned with XP from good mornings.
public enum Rank: Int, CaseIterable, Comparable, Sendable, Identifiable {
    case recruit, privateSoldier, privateFirstClass, corporal, sergeant, staffSergeant,
         lieutenant, captain, major, colonel, general

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .recruit: "Recruit"
        case .privateSoldier: "Private"
        case .privateFirstClass: "Private First Class"
        case .corporal: "Corporal"
        case .sergeant: "Sergeant"
        case .staffSergeant: "Staff Sergeant"
        case .lieutenant: "Lieutenant"
        case .captain: "Captain"
        case .major: "Major"
        case .colonel: "Colonel"
        case .general: "General"
        }
    }

    /// XP needed to reach this rank.
    public var threshold: Int {
        switch self {
        case .recruit: 0
        case .privateSoldier: 100
        case .privateFirstClass: 300
        case .corporal: 600
        case .sergeant: 1_000
        case .staffSergeant: 1_600
        case .lieutenant: 2_500
        case .captain: 3_600
        case .major: 5_000
        case .colonel: 7_000
        case .general: 10_000
        }
    }

    public var next: Rank? { Rank(rawValue: rawValue + 1) }

    public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }

    public static func forXP(_ xp: Int) -> Rank {
        allCases.last { xp >= $0.threshold } ?? .recruit
    }
}

/// Where the user stands: total XP, rank and progress to the next rank.
public struct RankProgress: Equatable, Sendable {
    public let xp: Int
    public let rank: Rank

    public init(xp: Int) {
        self.xp = xp
        self.rank = Rank.forXP(xp)
    }

    public var next: Rank? { rank.next }
    public var xpToNext: Int? { next.map { $0.threshold - xp } }

    /// 0…1 within the current rank (1 at General).
    public var fraction: Double {
        guard let next else { return 1 }
        let span = Double(next.threshold - rank.threshold)
        return min(1, max(0, Double(xp - rank.threshold) / span))
    }
}

public enum XPRules {
    public static let missionDone = 50
    public static let firstTryBonus = 25
    public static let perReRing = 5
    public static let minimumWhenDone = 10
    public static let perStreakDay = 5
    public static let maxStreakBonusDays = 10

    /// XP for one morning, given the streak length including that morning.
    public static func xp(for day: DaySummary, streak: Int) -> Int {
        guard day.completed else { return 0 }
        var xp = missionDone - perReRing * day.reArms
        if day.reArms == 0 { xp += firstTryBonus }
        xp = max(minimumWhenDone, xp)
        return xp + perStreakDay * min(max(streak, 1), maxStreakBonusDays)
    }

    /// Total XP from the full history (recomputed, so it never drifts).
    public static func totalXP(_ history: [DaySummary], calendar: Calendar = .current) -> Int {
        var total = 0, streak = 0
        var previous: Date?
        for day in history.sorted(by: { $0.day < $1.day }) {
            let start = calendar.startOfDay(for: day.day)
            if day.completed {
                if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == start {
                    streak += 1
                } else {
                    streak = 1
                }
                previous = start
            } else {
                streak = 0
                previous = nil
            }
            total += xp(for: day, streak: streak)
        }
        return total
    }

    public static func progress(_ history: [DaySummary], calendar: Calendar = .current) -> RankProgress {
        RankProgress(xp: totalXP(history, calendar: calendar))
    }
}
