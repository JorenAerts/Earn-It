import Core
import Foundation

/// Free extras earned without Pro. Today: inviting a friend in onboarding unlocks one sound.
public enum BonusUnlocks {
    static let key = "gloop.bonus.inviteSound"
    public static let inviteSound: AlarmSound = .riseAndConquer

    public static func isUnlocked(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    public static func unlock(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    /// Sounds free users may use thanks to bonuses.
    public static func sounds(_ defaults: UserDefaults = .standard) -> Set<AlarmSound> {
        isUnlocked(defaults) ? [inviteSound] : []
    }
}
