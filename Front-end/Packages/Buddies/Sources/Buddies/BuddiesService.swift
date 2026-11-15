import Foundation

public enum BuddiesError: LocalizedError, Equatable {
    case signedOut
    case unavailable
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in to use Buddies."
        case .unavailable: "Buddies isn't available in this build."
        case .message(let text): text
        }
    }
}

/// Everything social. `day` / `weekStart` are local calendar days ("2026-11-15", see `DayKey`).
@MainActor
public protocol BuddiesService: AnyObject {
    var isAvailable: Bool { get }

    func myClubs(day: String) async throws -> [Club]
    func createClub(_ draft: ClubDraft) async throws -> UUID
    func updateClub(_ id: UUID, _ draft: ClubDraft) async throws
    func deleteClub(_ id: UUID) async throws
    func joinClub(code: String) async throws -> UUID
    func joinPublicClub(_ id: UUID) async throws
    func leaveClub(_ id: UUID) async throws
    func removeMember(_ userID: UUID, from club: UUID) async throws
    func regenerateInvite(_ club: UUID) async throws -> String
    func searchPublicClubs(_ query: String) async throws -> [DiscoverClub]

    func today(club: UUID, day: String) async throws -> [MemberToday]
    func leaderboard(club: UUID, weekStart: String) async throws -> [LeaderboardRow]
    func send(_ report: WakeReport) async throws

    func myPhotoState(day: String) async throws -> PhotoState
    func feed(club: UUID, day: String) async throws -> [MorningPost]
    /// Short-lived URLs for photo paths from `feed`.
    func imageURLs(_ paths: [String]) async throws -> [String: URL]
    func postMorning(jpeg: Data, day: String, clubs: [UUID]) async throws
    func skipMorning(day: String) async throws
    func react(to post: UUID, emoji: String?) async throws

    func report(_ kind: ReportKind, id: UUID, reason: String) async throws
    func block(_ userID: UUID) async throws
    func unblock(_ userID: UUID) async throws
    func blockedUsers() async throws -> [BlockedUser]

    func shareWakeTime() async throws -> Bool
    func setShareWakeTime(_ on: Bool) async throws
}

/// No Supabase config: the tab explains Buddies needs accounts.
@MainActor
public final class UnavailableBuddiesService: BuddiesService {
    public init() {}
    public var isAvailable: Bool { false }
    public func myClubs(day: String) async throws -> [Club] { [] }
    public func createClub(_ draft: ClubDraft) async throws -> UUID { throw BuddiesError.unavailable }
    public func updateClub(_ id: UUID, _ draft: ClubDraft) async throws { throw BuddiesError.unavailable }
    public func deleteClub(_ id: UUID) async throws { throw BuddiesError.unavailable }
    public func joinClub(code: String) async throws -> UUID { throw BuddiesError.unavailable }
    public func joinPublicClub(_ id: UUID) async throws { throw BuddiesError.unavailable }
    public func leaveClub(_ id: UUID) async throws { throw BuddiesError.unavailable }
    public func removeMember(_ userID: UUID, from club: UUID) async throws { throw BuddiesError.unavailable }
    public func regenerateInvite(_ club: UUID) async throws -> String { throw BuddiesError.unavailable }
    public func searchPublicClubs(_ query: String) async throws -> [DiscoverClub] { [] }
    public func today(club: UUID, day: String) async throws -> [MemberToday] { [] }
    public func leaderboard(club: UUID, weekStart: String) async throws -> [LeaderboardRow] { [] }
    public func send(_ report: WakeReport) async throws { throw BuddiesError.unavailable }
    public func myPhotoState(day: String) async throws -> PhotoState { .none }
    public func feed(club: UUID, day: String) async throws -> [MorningPost] { [] }
    public func imageURLs(_ paths: [String]) async throws -> [String: URL] { [:] }
    public func postMorning(jpeg: Data, day: String, clubs: [UUID]) async throws { throw BuddiesError.unavailable }
    public func skipMorning(day: String) async throws {}
    public func react(to post: UUID, emoji: String?) async throws { throw BuddiesError.unavailable }
    public func report(_ kind: ReportKind, id: UUID, reason: String) async throws { throw BuddiesError.unavailable }
    public func block(_ userID: UUID) async throws { throw BuddiesError.unavailable }
    public func unblock(_ userID: UUID) async throws { throw BuddiesError.unavailable }
    public func blockedUsers() async throws -> [BlockedUser] { [] }
    public func shareWakeTime() async throws -> Bool { true }
    public func setShareWakeTime(_ on: Bool) async throws { throw BuddiesError.unavailable }
}
