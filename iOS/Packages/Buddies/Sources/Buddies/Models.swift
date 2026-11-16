import Coach
import Core
import Foundation
import Localization

public enum ClubRole: String, Codable, Sendable {
    case owner, member
}

/// A club the user belongs to.
public struct Club: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var emoji: String
    public var isPublic: Bool
    public var inviteCode: String
    public var role: ClubRole
    public var memberCount: Int
    /// Members who finished their mission today.
    public var upToday: Int
    public var ownerID: UUID?

    public init(id: UUID = UUID(), name: String, description: String = "", emoji: String = "⏰", isPublic: Bool = false,
                inviteCode: String, role: ClubRole = .member, memberCount: Int = 1, upToday: Int = 0, ownerID: UUID? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.emoji = emoji
        self.isPublic = isPublic
        self.inviteCode = inviteCode
        self.role = role
        self.memberCount = memberCount
        self.upToday = upToday
        self.ownerID = ownerID
    }

    public var isOwner: Bool { role == .owner }

    enum CodingKeys: String, CodingKey {
        case id, name, description, emoji, role
        case isPublic = "is_public", inviteCode = "invite_code", memberCount = "member_count"
        case upToday = "up_today", ownerID = "owner_id"
    }
}

/// What the creator fills in.
public struct ClubDraft: Equatable, Sendable {
    public var name: String
    public var description: String
    public var emoji: String
    public var isPublic: Bool

    public init(name: String = "", description: String = "", emoji: String = "⏰", isPublic: Bool = false) {
        self.name = name
        self.description = description
        self.emoji = emoji
        self.isPublic = isPublic
    }
}

/// A public club in search results.
public struct DiscoverClub: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var emoji: String
    public var memberCount: Int
    public var isMember: Bool

    public init(id: UUID = UUID(), name: String, description: String = "", emoji: String = "⏰",
                memberCount: Int = 1, isMember: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.emoji = emoji
        self.memberCount = memberCount
        self.isMember = isMember
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, emoji
        case memberCount = "member_count", isMember = "is_member"
    }
}

public enum PhotoState: String, Codable, Sendable {
    case none, posted, skipped

    /// Posting or skipping unlocks the others' photos of the day.
    public var unlocksFeed: Bool { self != .none }
}

/// A member's morning in a club's Today list.
public struct MemberToday: Codable, Identifiable, Hashable, Sendable {
    public let userID: UUID
    public var displayName: String?
    public var role: ClubRole
    /// When the mission was finished. Day precision only when the member hides their time.
    public var completedAt: Date?
    public var sharesTime: Bool
    public var rings: Int?
    public var streak: Int
    public var rank: String?
    public var photoState: PhotoState
    public var isMe: Bool

    public var id: UUID { userID }
    public var isUp: Bool { completedAt != nil }

    public init(userID: UUID = UUID(), displayName: String?, role: ClubRole = .member, completedAt: Date? = nil,
                sharesTime: Bool = true, rings: Int? = nil, streak: Int = 0, rank: String? = nil,
                photoState: PhotoState = .none, isMe: Bool = false) {
        self.userID = userID
        self.displayName = displayName
        self.role = role
        self.completedAt = completedAt
        self.sharesTime = sharesTime
        self.rings = rings
        self.streak = streak
        self.rank = rank
        self.photoState = photoState
        self.isMe = isMe
    }

    enum CodingKeys: String, CodingKey {
        case role, rings, streak, rank
        case userID = "user_id", displayName = "display_name", completedAt = "completed_at"
        case sharesTime = "shares_time", photoState = "photo_state", isMe = "is_me"
    }
}

/// One member's points, before ranking.
public struct LeaderboardRow: Codable, Identifiable, Hashable, Sendable {
    public let userID: UUID
    public var displayName: String?
    public var weekXP: Int
    public var totalXP: Int
    public var streak: Int
    public var rank: String?
    public var isMe: Bool

    public var id: UUID { userID }

    public init(userID: UUID = UUID(), displayName: String?, weekXP: Int, totalXP: Int, streak: Int = 0,
                rank: String? = nil, isMe: Bool = false) {
        self.userID = userID
        self.displayName = displayName
        self.weekXP = weekXP
        self.totalXP = totalXP
        self.streak = streak
        self.rank = rank
        self.isMe = isMe
    }

    /// The evolution stage (for the badge), from its title; old military titles still map.
    public var coachRank: Rank? { Rank.from(title: rank) }

    enum CodingKeys: String, CodingKey {
        case streak, rank
        case userID = "user_id", displayName = "display_name", weekXP = "week_xp", totalXP = "total_xp", isMe = "is_me"
    }
}

/// A morning photo in a club.
public struct MorningPost: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let userID: UUID
    public var displayName: String?
    /// nil while locked (the viewer hasn't posted or skipped yet).
    public var imagePath: String?
    public var createdAt: Date
    public var locked: Bool
    public var reactions: [String: Int]
    public var myReaction: String?
    public var isMe: Bool

    public init(id: UUID = UUID(), userID: UUID = UUID(), displayName: String?, imagePath: String?, createdAt: Date,
                locked: Bool, reactions: [String: Int] = [:], myReaction: String? = nil, isMe: Bool = false) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.imagePath = imagePath
        self.createdAt = createdAt
        self.locked = locked
        self.reactions = reactions
        self.myReaction = myReaction
        self.isMe = isMe
    }

    enum CodingKeys: String, CodingKey {
        case id, locked, reactions
        case userID = "user_id", displayName = "display_name", imagePath = "image_path", createdAt = "created_at"
        case myReaction = "my_reaction", isMe = "is_me"
    }

    public static let reactionChoices = ["🔥", "💪", "😴", "⏰", "👏"]
}

public struct BlockedUser: Codable, Identifiable, Hashable, Sendable {
    public let userID: UUID
    public var displayName: String?
    public var id: UUID { userID }

    public init(userID: UUID, displayName: String?) {
        self.userID = userID
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id", displayName = "display_name"
    }
}

public enum ReportKind: String, Codable, Sendable {
    case post, club, user
}

/// Shown for members without a name.
public func buddyName(_ name: String?) -> String {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? L10n.tr("Buddy") : trimmed
}
