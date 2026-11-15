import Coach
import Core
import Foundation

/// The leaderboard week: Monday 00:00 → next Monday, in local time.
public enum WeekWindow {
    public static func start(of date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2  // Monday
        cal.minimumDaysInFirstWeek = 4
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
    }
}

/// "2026-11-15": the local calendar day, as the backend stores it.
public enum DayKey {
    public static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Ranked leaderboard rows: competition ranking (1, 1, 3), ties broken by name for display.
public enum LeaderboardRanking {
    public enum Period: String, CaseIterable, Sendable, Identifiable {
        case week = "This week", allTime = "All time"
        public var id: String { rawValue }
    }

    public struct Entry: Identifiable, Hashable, Sendable {
        public let position: Int
        public let row: LeaderboardRow
        public let points: Int
        public var id: UUID { row.userID }
    }

    public static func rank(_ rows: [LeaderboardRow], by period: Period) -> [Entry] {
        func points(_ row: LeaderboardRow) -> Int { period == .week ? row.weekXP : row.totalXP }
        let sorted = rows.sorted {
            if points($0) != points($1) { return points($0) > points($1) }
            if $0.streak != $1.streak { return $0.streak > $1.streak }
            return buddyName($0.displayName).localizedCaseInsensitiveCompare(buddyName($1.displayName)) == .orderedAscending
        }
        var entries: [Entry] = []
        for (index, row) in sorted.enumerated() {
            let position: Int
            if let previous = entries.last, previous.points == points(row) {
                position = previous.position
            } else {
                position = index + 1
            }
            entries.append(Entry(position: position, row: row, points: points(row)))
        }
        return entries
    }
}

/// Club invite codes: 8 characters without look-alikes, shown as "ABCD-2345".
public enum InviteCode {
    public static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    public static let length = 8

    public static func generate() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// "abcd-2345", " ABCD2345 ", "gloop://join/ABCD2345", "https://…/join/ABCD-2345" → "ABCD2345".
    public static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: text), url.scheme != nil {
            let parts = ([url.host() ?? ""] + url.pathComponents).filter { $0 != "/" && !$0.isEmpty }
            guard let joinIndex = parts.firstIndex(of: "join"), joinIndex + 1 < parts.count else { return nil }
            text = parts[joinIndex + 1]
        }
        let code = text.uppercased().filter { $0 != "-" && $0 != " " }
        guard code.count == length, code.allSatisfy(alphabet.contains) else { return nil }
        return code
    }

    /// "ABCD-2345".
    public static func display(_ code: String) -> String {
        guard code.count == length else { return code }
        return String(code.prefix(4)) + "-" + String(code.suffix(4))
    }

    public static func link(_ code: String) -> URL {
        URL(string: "gloop://join/\(code)")!
    }

    /// Text for the share sheet.
    public static func shareText(club: String, code: String) -> String {
        "Join my wake-up club \"\(club)\" on Gloop! Code: \(display(code)) — or tap \(link(code).absoluteString)"
    }
}

/// BeReal rule: the others' photos of today unlock once you've posted or skipped.
public enum FeedGate {
    public static func isUnlocked(myPhotoState: PhotoState) -> Bool { myPhotoState.unlocksFeed }

    /// Show the "Share your morning" prompt: you finished today's mission, are in a club and haven't decided yet.
    public static func shouldPrompt(missionDoneToday: Bool, clubCount: Int, myPhotoState: PhotoState) -> Bool {
        missionDoneToday && clubCount > 0 && myPhotoState == .none
    }
}

public enum ClubRules {
    public static let nameRange = 2...40
    public static let maxDescription = 200
    public static let maxMembers = 100
    public static let freeClubLimit = 1

    public enum Problem: Equatable, Sendable {
        case nameLength, descriptionLength, inappropriate

        public var message: String {
            switch self {
            case .nameLength: "Use 2 to 40 characters for the name."
            case .descriptionLength: "Keep the description under \(ClubRules.maxDescription) characters."
            case .inappropriate: "Pick a different name: public clubs must be friendly for everyone."
            }
        }
    }

    /// A short blocklist for public names (App Review 1.2). Reports catch the rest.
    static let blockedWords = ["fuck", "shit", "bitch", "cunt", "nigg", "fag", "porn", "nazi", "rape",
                               "kut", "hoer", "kanker", "neuk"]

    public static func validate(_ draft: ClubDraft) -> Problem? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nameRange.contains(name.count) else { return .nameLength }
        guard draft.description.count <= maxDescription else { return .descriptionLength }
        if draft.isPublic && containsBlockedWord(name + " " + draft.description) { return .inappropriate }
        return nil
    }

    public static func containsBlockedWord(_ text: String) -> Bool {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "0", with: "o").replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e").replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "$", with: "s")
        let words = folded.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        return words.contains { word in blockedWords.contains { word.hasPrefix($0) } }
    }

    /// Free users can create one club; Pro unlimited (the server caps at 10 per user).
    public static func canCreate(ownedCount: Int, isPro: Bool) -> Bool {
        isPro ? ownedCount < 10 : ownedCount < freeClubLimit
    }
}

/// What the app tells the clubs after a finished mission.
public struct WakeReport: Codable, Equatable, Sendable {
    public var day: String
    public var completedAt: Date
    public var alarmTime: String?
    public var rings: Int
    public var xp: Int
    public var streak: Int
    public var rank: String

    public init(day: String, completedAt: Date, alarmTime: String?, rings: Int, xp: Int, streak: Int, rank: String) {
        self.day = day
        self.completedAt = completedAt
        self.alarmTime = alarmTime
        self.rings = rings
        self.xp = xp
        self.streak = streak
        self.rank = rank
    }

    enum CodingKeys: String, CodingKey {
        case day, rings, xp, streak, rank
        case completedAt = "completed_at", alarmTime = "alarm_time"
    }

    /// The morning of `day` from the full history (which includes that day). XP is that day's
    /// share of the total, so it matches `XPRules` exactly.
    public static func make(day: Date, completedAt: Date, rings: Int, alarmTime: String?, history: [DaySummary],
                            calendar: Calendar = .current) -> WakeReport {
        let start = calendar.startOfDay(for: day)
        let without = history.filter { calendar.startOfDay(for: $0.day) != start }
        let xp = XPRules.totalXP(history, calendar: calendar) - XPRules.totalXP(without, calendar: calendar)
        let completed = history.filter(\.completed).map(\.day)
        return WakeReport(day: DayKey.string(day, calendar: calendar), completedAt: completedAt, alarmTime: alarmTime,
                          rings: rings, xp: max(0, xp),
                          streak: StreakCalculator.currentStreak(completedDays: completed, today: day, calendar: calendar),
                          rank: XPRules.progress(history, calendar: calendar).rank.title)
    }
}

/// Reports waiting to be sent (offline, signed out). Newest per day wins.
@MainActor
public final class WakeReportQueue {
    private let defaults: UserDefaults
    private static let key = "gloop.buddies.pending"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var pending: [WakeReport] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        return (try? JSONDecoder().decode([WakeReport].self, from: data)) ?? []
    }

    public func enqueue(_ report: WakeReport) {
        var list = pending.filter { $0.day != report.day }
        list.append(report)
        save(Array(list.suffix(14)))
    }

    /// Sends everything pending; keeps what fails for next time.
    public func flush(using send: (WakeReport) async throws -> Void) async {
        var sent: [WakeReport] = []
        for report in pending {
            if (try? await send(report)) != nil { sent.append(report) }
        }
        // Re-read: a report may have been queued while sending.
        save(pending.filter { !sent.contains($0) })
    }

    private func save(_ list: [WakeReport]) {
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: Self.key) }
    }
}
