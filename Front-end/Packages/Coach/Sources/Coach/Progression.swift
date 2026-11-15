import Foundation

/// Gloop's evolution stages, earned with XP from good mornings. Raw values and thresholds are
/// unchanged from the old military ranks, so history and XP carry over.
public enum Rank: Int, CaseIterable, Comparable, Sendable, Identifiable {
    case droplet, blob, jelly, gloopling, bouncer, squisher, wobbler, megaGloop, superGloop, royalGloop, kingGloop

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .droplet: "Droplet"
        case .blob: "Blob"
        case .jelly: "Jelly"
        case .gloopling: "Gloopling"
        case .bouncer: "Bouncer"
        case .squisher: "Squisher"
        case .wobbler: "Wobbler"
        case .megaGloop: "Mega Gloop"
        case .superGloop: "Super Gloop"
        case .royalGloop: "Royal Gloop"
        case .kingGloop: "King Gloop"
        }
    }

    /// XP needed to reach this stage.
    public var threshold: Int {
        switch self {
        case .droplet: 0
        case .blob: 100
        case .jelly: 300
        case .gloopling: 600
        case .bouncer: 1_000
        case .squisher: 1_600
        case .wobbler: 2_500
        case .megaGloop: 3_600
        case .superGloop: 5_000
        case .royalGloop: 7_000
        case .kingGloop: 10_000
        }
    }

    public var next: Rank? { Rank(rawValue: rawValue + 1) }

    public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }

    public static func forXP(_ xp: Int) -> Rank {
        allCases.last { xp >= $0.threshold } ?? .droplet
    }

    /// Military titles used before Gloop (still stored in Buddies reports on the server).
    static let legacyTitles = ["Recruit", "Private", "Private First Class", "Corporal", "Sergeant", "Staff Sergeant",
                               "Lieutenant", "Captain", "Major", "Colonel", "General"]

    /// The stage for a title, new or legacy. nil for unknown text.
    public static func from(title: String?) -> Rank? {
        guard let title else { return nil }
        if let rank = allCases.first(where: { $0.title == title }) { return rank }
        return legacyTitles.firstIndex(of: title).flatMap(Rank.init(rawValue:))
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
