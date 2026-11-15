import Foundation

/// When to show Apple's rating prompt: only at happy moments, rarely, never right after a bad
/// morning or on the paywall. Apple itself also caps it at 3 prompts a year. No gating: we never
/// ask "do you like Gloop?" first.
public enum RatingPolicy {
    public enum Moment: Equatable, Sendable {
        /// Total number of first-ring mornings so far.
        case firstRingMornings(Int)
        /// Current streak length after this morning.
        case streak(Int)
        /// Gloop reached a new evolution stage.
        case evolved

        public var reason: String {
            switch self {
            case .firstRingMornings: "firstRing"
            case .streak: "streak"
            case .evolved: "evolved"
            }
        }

        /// Only these values are worth asking at.
        var qualifies: Bool {
            switch self {
            case .firstRingMornings(let n): n == 3 || n == 10
            case .streak(let days): [7, 30, 100].contains(days)
            case .evolved: true
            }
        }
    }

    public struct State: Equatable, Sendable {
        public var installDate: Date
        public var lastPrompt: Date?
        public var lastPromptVersion: String?

        public init(installDate: Date, lastPrompt: Date? = nil, lastPromptVersion: String? = nil) {
            self.installDate = installDate
            self.lastPrompt = lastPrompt
            self.lastPromptVersion = lastPromptVersion
        }
    }

    public static let minDaysSinceInstall = 3
    public static let minDaysBetweenPrompts = 60

    /// The first qualifying moment of this morning, or nil (don't ask).
    public static func moment(from moments: [Moment], state: State, now: Date, appVersion: String,
                              failSafeToday: Bool, calendar: Calendar = .current) -> Moment? {
        guard !failSafeToday, state.lastPromptVersion != appVersion else { return nil }
        let sinceInstall = calendar.dateComponents([.day], from: state.installDate, to: now).day ?? 0
        guard sinceInstall >= minDaysSinceInstall else { return nil }
        if let last = state.lastPrompt,
           (calendar.dateComponents([.day], from: last, to: now).day ?? 0) < minDaysBetweenPrompts { return nil }
        return moments.first(where: \.qualifies)
    }
}

/// Shows the What's New sheet once per version after an update (never on a fresh install).
public enum WhatsNewPolicy {
    /// - Parameters:
    ///   - lastSeenVersion: the version whose notes were last shown/acknowledged (nil = never ran).
    ///   - availableVersions: versions that have notes in WhatsNew.json.
    /// - Returns: the version to show notes for, or nil.
    public static func versionToShow(current: String, lastSeenVersion: String?, availableVersions: [String]) -> String? {
        guard let last = lastSeenVersion, last != current else { return nil }  // fresh install or already seen
        return availableVersions.contains(current) ? current : nil
    }
}

/// Small persisted state for the growth features.
@MainActor
public final class GrowthStore {
    public static let shared = GrowthStore()
    private let defaults: UserDefaults
    private enum Key {
        static let install = "gloop.growth.installDate"
        static let lastPrompt = "gloop.growth.lastRatingPrompt"
        static let lastPromptVersion = "gloop.growth.lastRatingVersion"
        static let whatsNewSeen = "gloop.growth.whatsNewSeenVersion"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.install) == nil { defaults.set(Date(), forKey: Key.install) }
    }

    public var ratingState: RatingPolicy.State {
        RatingPolicy.State(installDate: defaults.object(forKey: Key.install) as? Date ?? Date(),
                           lastPrompt: defaults.object(forKey: Key.lastPrompt) as? Date,
                           lastPromptVersion: defaults.string(forKey: Key.lastPromptVersion))
    }

    public func didPromptRating(version: String, at date: Date = Date()) {
        defaults.set(date, forKey: Key.lastPrompt)
        defaults.set(version, forKey: Key.lastPromptVersion)
    }

    /// nil on the very first launch; then remembers what was seen.
    public var whatsNewSeenVersion: String? { defaults.string(forKey: Key.whatsNewSeen) }

    public func markWhatsNewSeen(_ version: String) { defaults.set(version, forKey: Key.whatsNewSeen) }

    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
