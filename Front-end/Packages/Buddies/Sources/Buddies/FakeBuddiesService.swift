import Foundation

/// In-memory Buddies for unit tests, previews and screenshots (`-buddiesSample`).
/// Follows the same rules as the backend (membership, BeReal unlock, blocks).
@MainActor
public final class FakeBuddiesService: BuddiesService {
    public struct StoredClub {
        public var club: Club
        public var members: [UUID: ClubRole]
    }

    public let me: UUID
    public var signedIn = true
    public var failNext: BuddiesError?
    public private(set) var clubs: [UUID: StoredClub] = [:]
    public private(set) var names: [UUID: String] = [:]
    public private(set) var reports: [String: [UUID: WakeReport]] = [:]  // day → user → report
    public private(set) var photoStates: [String: [UUID: PhotoState]] = [:]
    public private(set) var posts: [(post: MorningPost, day: String, clubs: Set<UUID>)] = []
    public private(set) var reactions: [UUID: [UUID: String]] = [:]  // post → user → emoji
    public private(set) var blocked: Set<UUID> = []
    public private(set) var filedReports: [(ReportKind, UUID, String)] = []
    public var sharesTime = true

    public init(me: UUID = UUID(), name: String = "You") {
        self.me = me
        names[me] = name
    }

    public var isAvailable: Bool { true }

    // MARK: Clubs

    public func myClubs(day: String) async throws -> [Club] {
        try check()
        return clubs.values.filter { $0.members[me] != nil }.map { stored in
            var club = stored.club
            club.role = stored.members[me] ?? .member
            club.memberCount = stored.members.count
            club.upToday = stored.members.keys.filter { reports[day]?[$0] != nil }.count
            return club
        }
        .sorted { $0.name < $1.name }
    }

    public func createClub(_ draft: ClubDraft) async throws -> UUID {
        try check()
        if let problem = ClubRules.validate(draft) { throw BuddiesError.message(problem.message) }
        let id = UUID()
        clubs[id] = StoredClub(club: Club(id: id, name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                          description: draft.description, emoji: draft.emoji, isPublic: draft.isPublic,
                                          inviteCode: InviteCode.generate(), role: .owner, ownerID: me),
                               members: [me: .owner])
        return id
    }

    public func updateClub(_ id: UUID, _ draft: ClubDraft) async throws {
        try check()
        guard clubs[id]?.members[me] == .owner else { throw BuddiesError.message("Only the club owner can do that.") }
        clubs[id]?.club.name = draft.name
        clubs[id]?.club.description = draft.description
        clubs[id]?.club.emoji = draft.emoji
        clubs[id]?.club.isPublic = draft.isPublic
    }

    public func deleteClub(_ id: UUID) async throws {
        try check()
        guard clubs[id]?.members[me] == .owner else { throw BuddiesError.message("Only the club owner can do that.") }
        clubs[id] = nil
    }

    public func joinClub(code: String) async throws -> UUID {
        try check()
        guard let normalized = InviteCode.normalize(code),
              let id = clubs.values.first(where: { $0.club.inviteCode == normalized })?.club.id
        else { throw BuddiesError.message("No club found with this code.") }
        try join(id)
        return id
    }

    public func joinPublicClub(_ id: UUID) async throws {
        try check()
        guard clubs[id]?.club.isPublic == true else {
            throw BuddiesError.message("This club is private. Ask a member for the invite code.")
        }
        try join(id)
    }

    private func join(_ id: UUID) throws {
        guard let stored = clubs[id] else { throw BuddiesError.message("No club found with this code.") }
        if stored.members[me] != nil { return }
        guard stored.members.count < ClubRules.maxMembers else { throw BuddiesError.message("This club is full (100 members).") }
        clubs[id]?.members[me] = .member
    }

    public func leaveClub(_ id: UUID) async throws {
        try check()
        guard let role = clubs[id]?.members.removeValue(forKey: me) else { return }
        if role == .owner {
            if let heir = clubs[id]?.members.keys.sorted(by: { $0.uuidString < $1.uuidString }).first {
                clubs[id]?.members[heir] = .owner
                clubs[id]?.club.ownerID = heir
            } else {
                clubs[id] = nil
            }
        }
    }

    public func removeMember(_ userID: UUID, from club: UUID) async throws {
        try check()
        guard clubs[club]?.members[me] == .owner else { throw BuddiesError.message("Only the club owner can remove members.") }
        clubs[club]?.members[userID] = nil
    }

    public func regenerateInvite(_ club: UUID) async throws -> String {
        try check()
        guard clubs[club]?.members[me] == .owner else { throw BuddiesError.message("Only the club owner can change the code.") }
        let code = InviteCode.generate()
        clubs[club]?.club.inviteCode = code
        return code
    }

    public func searchPublicClubs(_ query: String) async throws -> [DiscoverClub] {
        try check()
        let q = query.trimmingCharacters(in: .whitespaces)
        return clubs.values.filter { $0.club.isPublic && (q.isEmpty || $0.club.name.localizedCaseInsensitiveContains(q)) }
            .map { DiscoverClub(id: $0.club.id, name: $0.club.name, description: $0.club.description, emoji: $0.club.emoji,
                                memberCount: $0.members.count, isMember: $0.members[me] != nil) }
            .sorted { $0.memberCount > $1.memberCount }
    }

    // MARK: Today & leaderboard

    public func today(club: UUID, day: String) async throws -> [MemberToday] {
        try check()
        let stored = try member(of: club)
        return stored.members.filter { !blocked.contains($0.key) }.map { user, role in
            let report = reports[day]?[user]
            return MemberToday(userID: user, displayName: names[user], role: role,
                               completedAt: report?.completedAt, sharesTime: user == me ? true : sharesTime,
                               rings: report?.rings, streak: report?.streak ?? 0, rank: report?.rank,
                               photoState: photoStates[day]?[user] ?? .none, isMe: user == me)
        }
    }

    public func leaderboard(club: UUID, weekStart: String) async throws -> [LeaderboardRow] {
        try check()
        let stored = try member(of: club)
        return stored.members.keys.filter { !blocked.contains($0) }.map { user in
            let all = reports.flatMap { day, byUser in byUser[user].map { [(day, $0)] } ?? [] }
            let week = all.filter { $0.0 >= weekStart && $0.0 < Self.addDays(weekStart, 7) }
            let latest = all.max { $0.0 < $1.0 }?.1
            return LeaderboardRow(userID: user, displayName: names[user], weekXP: week.map(\.1.xp).reduce(0, +),
                                  totalXP: all.map(\.1.xp).reduce(0, +), streak: latest?.streak ?? 0,
                                  rank: latest?.rank, isMe: user == me)
        }
    }

    public func send(_ report: WakeReport) async throws {
        try check()
        reports[report.day, default: [:]][me] = report
    }

    // MARK: Photos

    public func myPhotoState(day: String) async throws -> PhotoState {
        try check()
        return photoStates[day]?[me] ?? .none
    }

    public func feed(club: UUID, day: String) async throws -> [MorningPost] {
        try check()
        _ = try member(of: club)
        let unlocked = FeedGate.isUnlocked(myPhotoState: photoStates[day]?[me] ?? .none)
        return posts.filter { $0.day == day && $0.clubs.contains(club) && !blocked.contains($0.post.userID) }
            .map { entry in
                var post = entry.post
                let visible = unlocked || post.userID == me
                post.locked = !visible
                if !visible { post.imagePath = nil }
                let byUser = reactions[post.id] ?? [:]
                post.reactions = Dictionary(byUser.values.map { ($0, 1) }, uniquingKeysWith: +)
                post.myReaction = byUser[me]
                post.isMe = post.userID == me
                return post
            }
    }

    public func imageURLs(_ paths: [String]) async throws -> [String: URL] {
        Dictionary(uniqueKeysWithValues: paths.map { ($0, URL(string: "https://example.com/\($0)")!) })
    }

    public func postMorning(jpeg: Data, day: String, clubs: [UUID]) async throws {
        try check()
        guard !clubs.isEmpty else { throw BuddiesError.message("Pick at least one club.") }
        let mine = Set(clubs.filter { self.clubs[$0]?.members[me] != nil })
        let post = MorningPost(userID: me, displayName: names[me], imagePath: "\(me)/\(UUID()).jpg", createdAt: .now,
                               locked: false, isMe: true)
        posts.append((post, day, mine))
        photoStates[day, default: [:]][me] = .posted
    }

    public func skipMorning(day: String) async throws {
        try check()
        if photoStates[day]?[me] != .posted { photoStates[day, default: [:]][me] = .skipped }
    }

    public func react(to post: UUID, emoji: String?) async throws {
        try check()
        reactions[post, default: [:]][me] = emoji
    }

    // MARK: Safety

    public func report(_ kind: ReportKind, id: UUID, reason: String) async throws {
        try check()
        filedReports.append((kind, id, reason))
    }

    public func block(_ userID: UUID) async throws {
        try check()
        blocked.insert(userID)
    }

    public func unblock(_ userID: UUID) async throws {
        try check()
        blocked.remove(userID)
    }

    public func blockedUsers() async throws -> [BlockedUser] {
        try check()
        return blocked.map { BlockedUser(userID: $0, displayName: names[$0]) }
    }

    public func shareWakeTime() async throws -> Bool { sharesTime }
    public func setShareWakeTime(_ on: Bool) async throws { sharesTime = on }

    // MARK: Test & sample helpers

    /// Another person joins a club (tests / samples).
    public func addMember(_ name: String, to club: UUID, id: UUID = UUID()) -> UUID {
        names[id] = name
        clubs[club]?.members[id] = .member
        return id
    }

    /// Someone else's morning.
    public func simulateMorning(of user: UUID, day: String, report: WakeReport, photo: Bool, clubs: Set<UUID>) {
        reports[day, default: [:]][user] = report
        if photo {
            posts.append((MorningPost(userID: user, displayName: names[user], imagePath: "\(user)/\(UUID()).jpg",
                                      createdAt: report.completedAt, locked: false), day, clubs))
            photoStates[day, default: [:]][user] = .posted
        }
    }

    /// Creates a club owned by `me` without the async API (samples).
    public func addClubSync(_ draft: ClubDraft) -> UUID {
        let id = UUID()
        clubs[id] = StoredClub(club: Club(id: id, name: draft.name, description: draft.description, emoji: draft.emoji,
                                          isPublic: draft.isPublic, inviteCode: InviteCode.generate(), role: .owner,
                                          ownerID: me),
                               members: [me: .owner])
        return id
    }

    /// A public club made by someone else.
    @discardableResult
    public func addPublicClub(_ name: String, emoji: String, members: Int) -> UUID {
        let id = UUID()
        var stored = StoredClub(club: Club(id: id, name: name, emoji: emoji, isPublic: true,
                                           inviteCode: InviteCode.generate()), members: [:])
        for i in 0..<members {
            let user = UUID()
            names[user] = "Member \(i + 1)"
            stored.members[user] = i == 0 ? .owner : .member
        }
        clubs[id] = stored
        return id
    }

    private func member(of club: UUID) throws -> StoredClub {
        guard let stored = clubs[club], stored.members[me] != nil else {
            throw BuddiesError.message("Not a member of this club.")
        }
        return stored
    }

    private func check() throws {
        guard signedIn else { throw BuddiesError.signedOut }
        if let error = failNext {
            failNext = nil
            throw error
        }
    }

    static func addDays(_ day: String, _ n: Int) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day), let next = Calendar(identifier: .gregorian).date(byAdding: .day, value: n, to: date)
        else { return day }
        return f.string(from: next)
    }
}
