import Foundation
import Observation

/// Who may open the hidden Developer page. Xcode (DEBUG) builds: anyone. TestFlight / App Store:
/// only accounts listed in `Config/Developer.json` (Supabase user UUIDs, no emails).
public enum DeveloperAccess {
    public static func canUnlock(isDebugBuild: Bool, userID: UUID?, allowlist: Set<UUID>) -> Bool {
        if isDebugBuild { return true }
        guard let userID else { return false }
        return allowlist.contains(userID)
    }

    public static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// `Config/Developer.json` → `{ "developerUserIDs": ["…"] }`. Unknown / bad entries are ignored.
    public static func allowlist(from data: Data?) -> Set<UUID> {
        struct File: Decodable { let developerUserIDs: [String]? }
        guard let data, let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return Set((file.developerUserIDs ?? []).compactMap(UUID.init(uuidString:)))
    }

    public static func bundledAllowlist(_ bundle: Bundle = .main) -> Set<UUID> {
        allowlist(from: bundle.url(forResource: "Developer", withExtension: "json").flatMap { try? Data(contentsOf: $0) })
    }
}

/// Counts taps on the Version row: 7 quick taps (each within `window` of the previous) unlock.
public struct TapUnlock: Equatable, Sendable {
    public static let required = 7
    public var window: TimeInterval = 3
    public private(set) var count = 0
    private var last: Date?

    public init(window: TimeInterval = 3) { self.window = window }

    public enum Result: Equatable, Sendable {
        case nothing
        /// "N more taps…" (shown from tap 4 on).
        case hint(remaining: Int)
        case unlocked
    }

    public mutating func tap(at now: Date) -> Result {
        if let last, now.timeIntervalSince(last) > window { count = 0 }
        last = now
        count += 1
        if count >= Self.required {
            count = 0
            last = nil
            return .unlocked
        }
        let remaining = Self.required - count
        return remaining <= 3 ? .hint(remaining: remaining) : .nothing
    }
}

/// Whether the Developer page is unlocked on this device (`earnit.developerMode`).
@MainActor
@Observable
public final class DeveloperMode {
    public static let shared = DeveloperMode()

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "earnit.developerMode"
    private static let ownerKey = "earnit.developerMode.user"

    public private(set) var isOn: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.bool(forKey: Self.key)
    }

    /// `userID` is remembered so a release build locks again when someone else signs in.
    public func unlock(userID: UUID?) {
        isOn = true
        defaults.set(true, forKey: Self.key)
        defaults.set(userID?.uuidString, forKey: Self.ownerKey)
    }

    public func lock() {
        isOn = false
        defaults.set(false, forKey: Self.key)
        defaults.removeObject(forKey: Self.ownerKey)
    }

    /// Release builds: developer mode only stays on for the account that unlocked it.
    public func validate(userID: UUID?, isDebugBuild: Bool = DeveloperAccess.isDebugBuild,
                         allowlist: Set<UUID> = DeveloperAccess.bundledAllowlist()) {
        guard isOn, !isDebugBuild else { return }
        let owner = defaults.string(forKey: Self.ownerKey).flatMap(UUID.init(uuidString:))
        if !DeveloperAccess.canUnlock(isDebugBuild: false, userID: userID, allowlist: allowlist) || owner != userID {
            lock()
        }
    }
}
