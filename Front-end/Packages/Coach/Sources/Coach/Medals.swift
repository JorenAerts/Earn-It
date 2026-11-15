import Foundation

/// Achievements earned from the wake-up history.
public enum Medal: String, CaseIterable, Sendable, Identifiable {
    case firstMission, firstTry, streak3, streak7, streak30, streak100, earlyBird, ironWill, comeback, hatTrick, perfectWeek

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstMission: "First Squish"
        case .firstTry: "One and Done"
        case .streak3: "Triple Jiggle"
        case .streak7: "Week of Wobble"
        case .streak30: "Solid Month"
        case .streak100: "Slime Legend"
        case .earlyBird: "Dawn Drip"
        case .ironWill: "Sticky Will"
        case .comeback: "Bounce Back"
        case .hatTrick: "Hat Trick"
        case .perfectWeek: "Flawless Goo"
        }
    }

    public var requirement: String {
        switch self {
        case .firstMission: "Complete your first mission."
        case .firstTry: "Get up on the first ring."
        case .streak3: "3-day streak."
        case .streak7: "7-day streak."
        case .streak30: "30-day streak."
        case .streak100: "100-day streak."
        case .earlyBird: "Finish a mission before 06:00."
        case .ironWill: "Finish a mission after 5 or more re-rings."
        case .comeback: "Finish a mission after missing 2 or more days."
        case .hatTrick: "First ring, 3 mornings in a row."
        case .perfectWeek: "First ring, 7 mornings in a row."
        }
    }

    /// SF Symbol for the medal face.
    public var symbol: String {
        switch self {
        case .firstMission: "flag.fill"
        case .firstTry: "bell.fill"
        case .streak3: "flame"
        case .streak7: "flame.fill"
        case .streak30: "shield.fill"
        case .streak100: "crown.fill"
        case .earlyBird: "sunrise.fill"
        case .ironWill: "figure.strengthtraining.traditional"
        case .comeback: "arrow.uturn.up"
        case .hatTrick: "star.fill"
        case .perfectWeek: "star.circle.fill"
        }
    }
}

public enum MedalRules {
    /// All medals earned so far.
    public static func earned(_ history: [DaySummary], calendar: Calendar = .current) -> Set<Medal> {
        let done = history.filter(\.completed).sorted { $0.day < $1.day }
        var medals = Set<Medal>()
        guard !done.isEmpty else { return medals }
        medals.insert(.firstMission)
        if done.contains(where: { $0.reArms == 0 }) { medals.insert(.firstTry) }
        if done.contains(where: { $0.reArms >= 5 }) { medals.insert(.ironWill) }
        if done.contains(where: { d in d.completedAt.map { calendar.component(.hour, from: $0) < 6 } ?? false }) {
            medals.insert(.earlyBird)
        }

        var best = 0, run = 0, bestFirstTry = 0, firstTryRun = 0
        var previous: Date?
        for day in done {
            let start = calendar.startOfDay(for: day.day)
            let consecutive = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } == start
            if let previous, let gap = calendar.dateComponents([.day], from: previous, to: start).day, gap >= 3 {
                medals.insert(.comeback)  // ≥2 missed days in between
            }
            run = consecutive ? run + 1 : 1
            firstTryRun = day.reArms == 0 ? (consecutive ? firstTryRun + 1 : 1) : 0
            best = max(best, run)
            bestFirstTry = max(bestFirstTry, firstTryRun)
            previous = start
        }
        if best >= 3 { medals.insert(.streak3) }
        if best >= 7 { medals.insert(.streak7) }
        if best >= 30 { medals.insert(.streak30) }
        if best >= 100 { medals.insert(.streak100) }
        if bestFirstTry >= 3 { medals.insert(.hatTrick) }
        if bestFirstTry >= 7 { medals.insert(.perfectWeek) }
        return medals
    }
}

/// What today's finished mission changed: XP gained, promotion, new medals.
public struct MorningReport: Equatable, Sendable {
    public let xpGained: Int
    public let before: RankProgress
    public let after: RankProgress
    public let newMedals: [Medal]

    public var promoted: Bool { after.rank > before.rank }

    /// Compares the history with and without `day`.
    public static func make(history: [DaySummary], day: Date, calendar: Calendar = .current) -> MorningReport {
        let without = history.filter { !calendar.isDate($0.day, inSameDayAs: day) }
        let before = XPRules.progress(without, calendar: calendar)
        let after = XPRules.progress(history, calendar: calendar)
        let medals = MedalRules.earned(history, calendar: calendar).subtracting(MedalRules.earned(without, calendar: calendar))
        return MorningReport(xpGained: max(0, after.xp - before.xp), before: before, after: after,
                             newMedals: Medal.allCases.filter(medals.contains))
    }
}
