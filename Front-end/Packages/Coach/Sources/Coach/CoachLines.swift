import Foundation

/// Sergeant Rise's lines from `Config/CoachLines.json`:
/// `{ "<context>": { "gentle": [...], "toughLove": [...], "savage": [...] } }`.
/// Placeholders: `{streak}`, `{time}` (next alarm, e.g. 07:00), `{rings}` (re-rings so far),
/// `{name}` (the user's name; "soldier" when unknown).
public struct CoachLines: Sendable {
    public let table: [String: [String: [String]]]

    public init(table: [String: [String: [String]]]) {
        self.table = table
    }

    public static func load(from bundle: Bundle = .main) -> CoachLines {
        guard let url = bundle.url(forResource: "CoachLines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [String: [String]]].self, from: data)
        else { return CoachLines(table: [:]) }
        return CoachLines(table: table)
    }

    public func lines(for context: CoachContext, intensity: CoachIntensity) -> [String] {
        table[context.rawValue]?[intensity.rawValue] ?? []
    }

    /// Stable pick: the same line all day for a context (no flicker on every redraw),
    /// a different one on another day. `variant` lets callers rotate (e.g. per re-ring).
    public func line(for context: CoachContext, intensity: CoachIntensity, day: Date, variant: Int = 0,
                     values: [String: String] = [:], calendar: Calendar = .current) -> String {
        let options = lines(for: context, intensity: intensity)
        guard !options.isEmpty else { return "" }
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        let index = (dayNumber &+ variant &+ context.rawValue.count) % options.count
        var filled = values
        if (filled["name"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty { filled["name"] = "soldier" }
        return Self.fill(options[abs(index)], filled)
    }

    public static func fill(_ template: String, _ values: [String: String]) -> String {
        values.reduce(template) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}

/// The user's coach settings.
public final class CoachPreferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private let intensityKey = "earnit.coach.intensity"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var intensity: CoachIntensity {
        get { defaults.string(forKey: intensityKey).flatMap(CoachIntensity.init(rawValue:)) ?? .toughLove }
        set { defaults.set(newValue.rawValue, forKey: intensityKey) }
    }

    public var notifications: CoachNotificationSettings {
        get {
            CoachNotificationSettings(enabled: defaults.bool(forKey: "earnit.coach.notify"),
                                      eveningHour: defaults.object(forKey: "earnit.coach.eveningHour") as? Int ?? 22,
                                      eveningMinute: defaults.object(forKey: "earnit.coach.eveningMinute") as? Int ?? 0)
        }
        set {
            defaults.set(newValue.enabled, forKey: "earnit.coach.notify")
            defaults.set(newValue.eveningHour, forKey: "earnit.coach.eveningHour")
            defaults.set(newValue.eveningMinute, forKey: "earnit.coach.eveningMinute")
        }
    }

    /// Day key of the last roast sent, so a fail-safe is roasted once.
    public var lastRoastDay: String? {
        get { defaults.string(forKey: "earnit.coach.lastRoast") }
        set { defaults.set(newValue, forKey: "earnit.coach.lastRoast") }
    }
}
