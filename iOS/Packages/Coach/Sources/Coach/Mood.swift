import Foundation
import Localization

/// The coach's five moods, best to worst.
public enum CoachMood: String, Codable, CaseIterable, Sendable, Identifiable {
    case proud, calm, suspicious, angry, disappointed

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .proud: L10n.tr("Proud")
        case .calm: L10n.tr("Calm")
        case .suspicious: L10n.tr("Suspicious")
        case .angry: L10n.tr("Angry")
        case .disappointed: L10n.tr("Disappointed")
        }
    }
}

/// How harsh he talks. Same moods, different lines.
public enum CoachIntensity: String, Codable, CaseIterable, Sendable, Identifiable {
    case gentle, toughLove, savage

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gentle: L10n.tr("Gentle")
        case .toughLove: L10n.tr("Tough love")
        case .savage: L10n.tr("Savage")
        }
    }
}

/// Why he's in his current mood — selects the line he says.
public enum CoachContext: String, Codable, CaseIterable, Sendable {
    case idle, night, noAlarm
    case ringing, reRing
    case missionSuccess, firstTry, streakMilestone
    case failSafe, streakBroken
}

/// Mood + context + how angry (0…1, only for `.angry`, grows with re-rings).
public struct CoachState: Equatable, Sendable {
    public var mood: CoachMood
    public var context: CoachContext
    public var anger: Double

    public init(mood: CoachMood, context: CoachContext, anger: Double = 0) {
        self.mood = mood
        self.context = context
        self.anger = min(1, max(0, anger))
    }
}
