import Foundation

/// Tiny JSON-in-UserDefaults store for state that App Intents (and later extensions) need.
/// Swap `defaults` for an App Group suite once the paid team + App Group exist (M2).
public final class KeyValueStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let legacyPlan = "gloop.plan"
        static let plans = "gloop.plans"
        static let session = "gloop.session"
        static let owners = "gloop.alarmOwners"
        static let pause = "gloop.pause"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// All alarms. Migrates the single alarm saved by earlier versions.
    public func loadPlans() -> [AlarmPlan] {
        if let plans: [AlarmPlan] = load(Key.plans) { return plans }
        if let legacy: AlarmPlan = load(Key.legacyPlan) {
            savePlans([legacy])
            defaults.removeObject(forKey: Key.legacyPlan)
            return [legacy]
        }
        return []
    }

    public func savePlans(_ plans: [AlarmPlan]) {
        save(plans, Key.plans)
    }

    /// One-off alarm (follow-up / test) → the plan it belongs to.
    public func loadOwners() -> [UUID: UUID] {
        load(Key.owners) ?? [:]
    }

    public func saveOwners(_ owners: [UUID: UUID]) {
        save(owners, Key.owners)
    }

    /// Test / migration helper: write a plan in the pre-multi-alarm format.
    public func saveLegacyPlan(_ plan: AlarmPlan) {
        save(plan, Key.legacyPlan)
    }

    /// "Pause all alarms": nil = not paused.
    public func loadPause() -> AlarmPause? {
        load(Key.pause)
    }

    public func savePause(_ pause: AlarmPause?) {
        if let pause { save(pause, Key.pause) } else { defaults.removeObject(forKey: Key.pause) }
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
