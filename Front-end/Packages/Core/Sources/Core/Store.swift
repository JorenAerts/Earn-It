import Foundation

/// Tiny JSON-in-UserDefaults store for state that App Intents (and later extensions) need.
/// Swap `defaults` for an App Group suite once the paid team + App Group exist (M2).
public final class KeyValueStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let plan = "earnit.plan"
        static let session = "earnit.session"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadPlan() -> AlarmPlan {
        load(Key.plan) ?? AlarmPlan()
    }

    public func savePlan(_ plan: AlarmPlan) {
        save(plan, Key.plan)
    }

    public func loadSession() -> SessionState? {
        load(Key.session)
    }

    public func saveSession(_ session: SessionState?) {
        if let session { save(session, Key.session) } else { defaults.removeObject(forKey: Key.session) }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? encoder.encode(value) { defaults.set(data, forKey: key) }
    }
}
