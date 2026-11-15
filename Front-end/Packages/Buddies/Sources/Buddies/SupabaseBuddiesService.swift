import Account
import Foundation
import Localization
import Supabase
import os

private let log = Logger(subsystem: "be.gloop.app", category: "buddies")

/// Buddies on Supabase (see Backend/supabase/migrations/*_buddies.sql). Uses the auth client so
/// every call carries the signed-in user's session; all access rules live in RLS + RPCs.
@MainActor
public final class SupabaseBuddiesService: BuddiesService {
    private let client: SupabaseClient
    private let currentUser: @MainActor () -> UUID?
    private static let bucket = "morning"

    public init(client: SupabaseClient, currentUser: @escaping @MainActor () -> UUID?) {
        self.client = client
        self.currentUser = currentUser
    }

    public var isAvailable: Bool { true }

    // MARK: Clubs

    public func myClubs(day: String) async throws -> [Club] {
        guard currentUser() != nil else { return [] }
        return try await call { try await self.client.rpc("my_clubs", params: ["today": day]).execute().value }
    }

    public func createClub(_ draft: ClubDraft) async throws -> UUID {
        struct Params: Encodable {
            let p_name, p_description, p_emoji: String
            let p_is_public: Bool
        }
        return try await call {
            try await self.client.rpc("create_club", params: Params(p_name: draft.name, p_description: draft.description,
                                                                   p_emoji: draft.emoji, p_is_public: draft.isPublic))
                .execute().value
        }
    }

    public func updateClub(_ id: UUID, _ draft: ClubDraft) async throws {
        struct Row: Encodable {
            let name, description, emoji: String
            let is_public: Bool
        }
        try await call {
            try await self.client.from("clubs")
                .update(Row(name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: draft.description, emoji: draft.emoji, is_public: draft.isPublic))
                .eq("id", value: id).execute()
        }
    }

    public func deleteClub(_ id: UUID) async throws {
        try await call { try await self.client.from("clubs").delete().eq("id", value: id).execute() }
    }

    public func joinClub(code: String) async throws -> UUID {
        guard let normalized = InviteCode.normalize(code) else {
            throw BuddiesError.message(L10n.tr("That doesn't look like an invite code (8 letters and numbers)."))
        }
        return try await call { try await self.client.rpc("join_club", params: ["code": normalized]).execute().value }
    }

    public func joinPublicClub(_ id: UUID) async throws {
        try await call { try await self.client.rpc("join_public_club", params: ["club": id]).execute() }
    }

    public func leaveClub(_ id: UUID) async throws {
        try await call { try await self.client.rpc("leave_club", params: ["club": id]).execute() }
    }

    public func removeMember(_ userID: UUID, from club: UUID) async throws {
        try await call { try await self.client.rpc("remove_member", params: ["club": club, "member": userID]).execute() }
    }

    public func regenerateInvite(_ club: UUID) async throws -> String {
        try await call { try await self.client.rpc("regenerate_invite", params: ["club": club]).execute().value }
    }

    public func searchPublicClubs(_ query: String) async throws -> [DiscoverClub] {
        try await call { try await self.client.rpc("search_public_clubs", params: ["query": query]).execute().value }
    }

    // MARK: Today & leaderboard

    public func today(club: UUID, day: String) async throws -> [MemberToday] {
        struct Params: Encodable { let club: UUID; let today: String }
        return try await call {
            try await self.client.rpc("club_today", params: Params(club: club, today: day)).execute().value
        }
    }

    public func leaderboard(club: UUID, weekStart: String) async throws -> [LeaderboardRow] {
        struct Params: Encodable { let club: UUID; let week_start: String }
        return try await call {
            try await self.client.rpc("club_leaderboard", params: Params(club: club, week_start: weekStart)).execute().value
        }
    }

    public func send(_ report: WakeReport) async throws {
        guard let user = currentUser() else { throw BuddiesError.signedOut }
        struct Row: Encodable {
            let user_id: UUID
            let day: String
            let completed_at: Date
            let alarm_time: String?
            let rings, xp, streak: Int
            let rank: String
        }
        let row = Row(user_id: user, day: report.day, completed_at: report.completedAt, alarm_time: report.alarmTime,
                      rings: report.rings, xp: report.xp, streak: report.streak, rank: report.rank)
        // Upsert without photo_state, so a posted / skipped photo stays as it is.
        try await call { try await self.client.from("wake_reports").upsert(row, onConflict: "user_id,day").execute() }
    }

    // MARK: Morning photos

    public func myPhotoState(day: String) async throws -> PhotoState {
        guard let user = currentUser() else { return .none }
        struct Row: Decodable { let photo_state: PhotoState }
        let rows: [Row] = try await call {
            try await self.client.from("wake_reports").select("photo_state")
                .eq("user_id", value: user).eq("day", value: day).limit(1).execute().value
        }
        return rows.first?.photo_state ?? .none
    }

    public func feed(club: UUID, day: String) async throws -> [MorningPost] {
        struct Params: Encodable { let club: UUID; let today: String }
        return try await call {
            try await self.client.rpc("club_feed", params: Params(club: club, today: day)).execute().value
        }
    }

    public func imageURLs(_ paths: [String]) async throws -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        let results = try await call {
            try await self.client.storage.from(Self.bucket).createSignedURLs(paths: paths, expiresIn: 3600)
        }
        var urls: [String: URL] = [:]
        for (path, result) in zip(paths, results) {
            if case .success(let signed) = result { urls[path] = signed.signedURL }
        }
        return urls
    }

    public func postMorning(jpeg: Data, day: String, clubs: [UUID]) async throws {
        guard let user = currentUser() else { throw BuddiesError.signedOut }
        let id = UUID()
        let path = "\(user.uuidString.lowercased())/\(id.uuidString.lowercased()).jpg"
        try await call {
            _ = try await self.client.storage.from(Self.bucket)
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        }
        struct Params: Encodable {
            let post_id: UUID
            let today: String
            let path: String
            let clubs: [UUID]
        }
        do {
            try await call {
                try await self.client.rpc("create_morning_post",
                                          params: Params(post_id: id, today: day, path: path, clubs: clubs)).execute()
            }
        } catch {
            _ = try? await client.storage.from(Self.bucket).remove(paths: [path])  // don't leave an orphan
            throw error
        }
    }

    public func skipMorning(day: String) async throws {
        try await call { try await self.client.rpc("skip_morning_post", params: ["today": day]).execute() }
    }

    public func react(to post: UUID, emoji: String?) async throws {
        struct Params: Encodable { let post: UUID; let emoji: String? }
        try await call { try await self.client.rpc("react_to_post", params: Params(post: post, emoji: emoji)).execute() }
    }

    // MARK: Safety

    public func report(_ kind: ReportKind, id: UUID, reason: String) async throws {
        guard let user = currentUser() else { throw BuddiesError.signedOut }
        struct Row: Encodable { let reporter_id: UUID; let kind: String; let target_id: UUID; let reason: String }
        try await call {
            try await self.client.from("reports")
                .insert(Row(reporter_id: user, kind: kind.rawValue, target_id: id, reason: String(reason.prefix(500))))
                .execute()
        }
    }

    public func block(_ userID: UUID) async throws {
        guard let user = currentUser() else { throw BuddiesError.signedOut }
        struct Row: Encodable { let blocker_id: UUID; let blocked_id: UUID }
        try await call {
            try await self.client.from("blocks").upsert(Row(blocker_id: user, blocked_id: userID),
                                                        onConflict: "blocker_id,blocked_id", ignoreDuplicates: true)
                .execute()
        }
    }

    public func unblock(_ userID: UUID) async throws {
        guard let user = currentUser() else { throw BuddiesError.signedOut }
        try await call {
            try await self.client.from("blocks").delete()
                .eq("blocker_id", value: user).eq("blocked_id", value: userID).execute()
        }
    }

    public func blockedUsers() async throws -> [BlockedUser] {
        try await call { try await self.client.rpc("blocked_users").execute().value }
    }

    public func shareWakeTime() async throws -> Bool {
        guard let user = currentUser() else { return true }
        struct Row: Decodable { let share_wake_time: Bool? }
        let rows: [Row] = try await call {
            try await self.client.from("profiles").select("share_wake_time").eq("id", value: user).limit(1).execute().value
        }
        return rows.first?.share_wake_time ?? true
    }

    public func setShareWakeTime(_ on: Bool) async throws {
        guard let user = currentUser() else { throw BuddiesError.signedOut }
        try await call {
            try await self.client.from("profiles").update(["share_wake_time": on]).eq("id", value: user).execute()
        }
    }

    // MARK: Errors

    /// Function / table not found: the Buddies migration hasn't been applied.
    static let missingSetupCodes: Set<String> = ["PGRST202", "PGRST205", "42883", "42P01"]

    /// Server messages from our RPCs are written for people; everything else gets a generic text.
    private func call<T>(_ work: () async throws -> T) async throws -> T {
        guard currentUser() != nil else { throw BuddiesError.signedOut }
        do {
            return try await work()
        } catch let error as PostgrestError {
            log.error("buddies rpc: \(error.message, privacy: .public)")
            if Self.missingSetupCodes.contains(error.code ?? "") {
                throw BuddiesError.message(L10n.tr("Buddies isn't set up on the server yet (database migration missing)."))
            }
            throw BuddiesError.message(error.code == "P0001" || error.code == "42501"
                                       ? error.message : L10n.tr("Something went wrong. Try again in a moment."))
        } catch let error as BuddiesError {
            throw error
        } catch {
            log.error("buddies: \(error.localizedDescription, privacy: .public)")
            throw BuddiesError.message(L10n.tr("Couldn't reach Gloop. Check your connection and try again."))
        }
    }
}
