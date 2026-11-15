import Coach
import Foundation

/// Reads/writes the widget snapshot as JSON in the shared App Group container.
/// The group id comes from the `GloopAppGroup` Info.plist key (same in app + widget extension).
/// Without the App Group entitlement (free Apple team) the container is nil: the app skips
/// writing and widgets show their "open the app" state.
public struct SnapshotStore: Sendable {
    public static let fileName = "widget-snapshot.json"
    let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    /// The shared store, if this build has the App Group.
    public static var shared: SnapshotStore {
        let group = Bundle.main.object(forInfoDictionaryKey: "GloopAppGroup") as? String
        let url = group.flatMap { $0.isEmpty ? nil : FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
        return SnapshotStore(directory: url)
    }

    public var isAvailable: Bool { directory != nil }

    public func load() -> WidgetSnapshot? {
        guard let url = directory?.appending(path: Self.fileName),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    public func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = directory?.appending(path: Self.fileName) else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

/// Widget kinds + deep links shared by the app (reload / routing) and the extension.
public enum WidgetIDs {
    public static let streak = "be.gloop.widget.streak"
    public static let streakRank = "be.gloop.widget.streakRank"
    public static let serviceRecord = "be.gloop.widget.serviceRecord"
    public static let lockStreak = "be.gloop.widget.lockStreak"
    public static let lockStreakRank = "be.gloop.widget.lockStreakRank"

    public static let progressURL = URL(string: "gloop://progress")!
    public static let paywallURL = URL(string: "gloop://paywall")!
}
