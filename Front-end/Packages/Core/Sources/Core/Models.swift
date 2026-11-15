import Foundation

// MARK: - Missions

public enum MissionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case math
    case shake
    case qr
    case object

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .math: "Math problems"
        case .shake: "Shake the phone"
        case .qr: "Scan a code"
        case .object: "Scan your item"
        }
    }

    /// Shown in the alarm title: "Earn It - Math Problem".
    public var alarmTitle: String {
        switch self {
        case .math: "Math Problem"
        case .shake: "Shake It"
        case .qr: "Scan Code"
        case .object: "Scan Item"
        }
    }

    /// SF Symbol used in the mission picker, editor rows and the mission screen.
    public var symbol: String {
        switch self {
        case .math: "function"
        case .shake: "iphone.radiowaves.left.and.right"
        case .qr: "qrcode.viewfinder"
        case .object: "camera.viewfinder"
        }
    }

    /// One line in the mission picker: what you'll have to do.
    public var tagline: String {
        switch self {
        case .math: "Solve problems in a row. Wakes up your brain."
        case .shake: "Shake your phone hard. Wakes up your body."
        case .qr: "Scan a code you stuck in another room."
        case .object: "Scan an item you pick, like your toothbrush or coffee cup."
        }
    }

    /// Rough time it takes, shown in the picker.
    public var estimatedDuration: String {
        switch self {
        case .math: "~1 min"
        case .shake: "~30 s"
        case .qr, .object: "~1 min"
        }
    }

    public var needsCamera: Bool { self == .qr || self == .object }

    /// Has to be set up before the alarm can use it (register a code / scan an item).
    public var needsSetup: Bool { needsPayload }

    /// After this long on the mission screen, offer a backup mission ("Can't find it?").
    public var backupAfter: TimeInterval? {
        switch self {
        case .object: 120
        case .math, .shake, .qr: nil
        }
    }

    /// Unit label for `MissionConfig.target`.
    public var targetLabel: String {
        switch self {
        case .math: "problems"
        case .shake: "shakes"
        case .qr: "code"
        case .object: "item"
        }
    }

    public var defaultTarget: Int {
        switch self {
        case .math: 3
        case .shake: 30
        case .qr, .object: 1
        }
    }

    /// Allowed `target` values in setup; nil = target not configurable.
    public var targetRange: ClosedRange<Int>? {
        switch self {
        case .math: 1...20
        case .shake: 5...200
        case .qr, .object: nil
        }
    }

    public var targetStep: Int {
        switch self {
        case .math: 1
        case .shake: 5
        case .qr, .object: 1
        }
    }

    public var usesDifficulty: Bool {
        switch self {
        case .math, .shake: true
        case .qr, .object: false
        }
    }

    /// Needs something registered at setup (the QR code / the scanned item).
    public var needsPayload: Bool { self == .qr || self == .object }
}

public enum MissionDifficulty: String, Codable, CaseIterable, Sendable, Identifiable {
    case easy, medium, hard
    public var id: String { rawValue }
}

public struct MissionConfig: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: MissionKind
    public var difficulty: MissionDifficulty
    /// Math: problems correct in a row. Shake: shakes. QR: unused (1).
    public var target: Int
    /// Mission-specific registered value. QR: the code's payload string. Object: reference ID.
    public var payload: String?
    /// User-facing name of what was registered, e.g. "Toothbrush".
    public var label: String?

    public init(id: UUID = UUID(), kind: MissionKind, difficulty: MissionDifficulty = .medium,
                target: Int? = nil, payload: String? = nil, label: String? = nil) {
        self.id = id
        self.kind = kind
        self.difficulty = difficulty
        self.target = target ?? kind.defaultTarget
        self.payload = payload
        self.label = label
    }

    /// What the mission screen tells the user to do.
    public var instruction: String {
        switch kind {
        case .math: "Solve \(target) problem\(target == 1 ? "" : "s") in a row."
        case .shake: "Shake your phone \(target) times."
        case .qr: "Go to your code and scan it."
        case .object: "Find your \(label?.lowercased() ?? "item") and point the camera at it."
        }
    }

    /// Alarm title part: "Scan Toothbrush" for a named item.
    public var alarmTitle: String {
        if kind == .object, let label, !label.isEmpty { return "Scan \(label)" }
        return kind.alarmTitle
    }

    /// Fully configured and playable.
    public var isReady: Bool {
        !kind.needsPayload || !(payload?.isEmpty ?? true)
    }

    /// One-line description for lists: "3 problems · medium", "Code registered".
    public var summary: String {
        switch kind {
        case .qr: isReady ? "Code registered" : "No code registered"
        case .object: isReady ? (label ?? "Item scanned") : "No item scanned yet"
        case .math, .shake: "\(target) \(kind.targetLabel) · \(difficulty.rawValue)"
        }
    }
}

// MARK: - Alarm sound

/// Bundled alarm tones (App/Sounds/EarnIt_<rawValue>.caf). The same file rings via AlarmKit
/// and keeps playing in-app during the mission.
public enum AlarmSound: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic, chime, siren, digital, pulse
    case radar, gentleRise, reveille, morningMood, furElise
    /// Bonus: unlocked for free users by inviting a friend in onboarding.
    case riseAndConquer

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: "Classic Beep"
        case .chime: "Morning Chime"
        case .siren: "Rising Siren"
        case .digital: "Digital"
        case .pulse: "Deep Pulse"
        case .radar: "Radar"
        case .gentleRise: "Gentle Rise"
        case .reveille: "Reveille"
        case .morningMood: "Morning Mood"
        case .furElise: "Für Elise"
        case .riseAndConquer: "Rise & Conquer"
        }
    }

    public enum Category: String, CaseIterable, Sendable {
        case tones = "Tones", melodies = "Melodies"
    }

    public var category: Category {
        switch self {
        case .classic, .siren, .digital, .pulse, .radar: .tones
        case .chime, .gentleRise, .reveille, .morningMood, .furElise, .riseAndConquer: .melodies
        }
    }

    /// Short credit for public-domain melodies (performed by our own generator).
    public var credit: String? {
        switch self {
        case .reveille: "Traditional bugle call"
        case .morningMood: "Edvard Grieg, Peer Gynt"
        case .furElise: "Ludwig van Beethoven"
        default: nil
        }
    }

    /// Resource name without extension.
    public var resourceName: String { "EarnIt_\(rawValue)" }
    public var fileName: String { resourceName + ".caf" }
}

// MARK: - Sound choice

/// A song picked from Apple Music. Plays in the app (MusicKit, subscribers); the system alarm
/// rings with `fallback` because Apple Music songs can't become alarm sound files.
public struct AppleMusicPick: Codable, Hashable, Sendable {
    public var songID: String
    public var title: String
    public var artist: String
    /// Where playback starts, in seconds.
    public var startOffset: Double
    public var artworkURL: URL?
    public var fallback: AlarmSound

    public init(songID: String, title: String, artist: String, startOffset: Double = 0,
                artworkURL: URL? = nil, fallback: AlarmSound = .classic) {
        self.songID = songID
        self.title = title
        self.artist = artist
        self.startOffset = startOffset
        self.artworkURL = artworkURL
        self.fallback = fallback
    }
}

/// What an alarm sounds like: a built-in tone, the user's own sound, or an Apple Music song.
public enum SoundChoice: Hashable, Sendable {
    case builtIn(AlarmSound)
    /// File `Library/Sounds/custom-<id>.caf`, see `CustomSoundLibrary`.
    case custom(id: UUID, name: String)
    case appleMusic(AppleMusicPick)

    // Shortcuts so `sound: .classic` reads naturally.
    public static let classic = SoundChoice.builtIn(.classic)
    public static let chime = SoundChoice.builtIn(.chime)
    public static let siren = SoundChoice.builtIn(.siren)
    public static let digital = SoundChoice.builtIn(.digital)
    public static let pulse = SoundChoice.builtIn(.pulse)

    /// Whether AlarmKit plays files from `Library/Sounds` (device-verified, see CLAUDE.md).
    /// When false, own sounds ring the system alarm with Classic Beep and play in-app after X.
    nonisolated(unsafe) public static var customSoundsRingNatively = true

    public var displayName: String {
        switch self {
        case .builtIn(let sound): sound.displayName
        case .custom(_, let name): name
        case .appleMusic(let pick): "\(pick.title) – \(pick.artist)"
        }
    }

    public var builtIn: AlarmSound? {
        if case .builtIn(let sound) = self { return sound }
        return nil
    }

    /// The file the *system* alarm (AlarmKit) rings with.
    public var systemSoundFileName: String {
        switch self {
        case .builtIn(let sound): sound.fileName
        case .custom(let id, _):
            Self.customSoundsRingNatively ? CustomSoundLibrary.fileName(for: id) : AlarmSound.classic.fileName
        case .appleMusic(let pick): pick.fallback.fileName
        }
    }

    public var symbol: String {
        switch self {
        case .builtIn: "speaker.wave.2.fill"
        case .custom: "waveform"
        case .appleMusic: "music.note"
        }
    }
}

extension SoundChoice: Codable {
    private enum CodingKeys: String, CodingKey { case type, sound, id, name, appleMusic }

    /// Accepts the old format (`"sound": "chime"`) as well as the new tagged object.
    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
            self = .builtIn(AlarmSound(rawValue: raw) ?? .classic)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "custom":
            self = .custom(id: try c.decode(UUID.self, forKey: .id), name: try c.decode(String.self, forKey: .name))
        case "appleMusic":
            self = .appleMusic(try c.decode(AppleMusicPick.self, forKey: .appleMusic))
        default:
            self = .builtIn(AlarmSound(rawValue: try c.decodeIfPresent(String.self, forKey: .sound) ?? "") ?? .classic)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .builtIn(let sound):
            try c.encode("builtIn", forKey: .type)
            try c.encode(sound.rawValue, forKey: .sound)
        case .custom(let id, let name):
            try c.encode("custom", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
        case .appleMusic(let pick):
            try c.encode("appleMusic", forKey: .type)
            try c.encode(pick, forKey: .appleMusic)
        }
    }
}

/// Where the user's own sounds live: `Library/Sounds` (the folder iOS searches for named sounds).
public enum CustomSoundLibrary {
    public static let maxSounds = 20
    public static let maxDuration: Double = 30

    public static func fileName(for id: UUID) -> String { "custom-\(id.uuidString).caf" }

    public static var directory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appending(path: "Sounds")
    }

    public static func url(for id: UUID, in directory: URL = directory) -> URL {
        directory.appending(path: fileName(for: id))
    }
}

/// Decodes a mission or nil when its kind no longer exists.
private struct LossyMission: Decodable {
    let config: MissionConfig?
    init(from decoder: any Decoder) throws {
        config = try? MissionConfig(from: decoder)
    }
}

// MARK: - Alarm plan

/// The single POC alarm. Stored as JSON so App Intents (and later extensions) can read it cheaply.
public struct AlarmPlan: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Optional name shown in the list ("Work days", "Gym").
    public var label: String
    public var sound: SoundChoice
    public var hour: Int
    public var minute: Int
    /// Calendar weekday numbers, 1 = Sunday … 7 = Saturday. Empty = one-off (next occurrence).
    public var weekdays: Set<Int>
    public var missions: [MissionConfig]
    public var reArmMinutes: Int
    /// Fail-safe: after this many follow-ups the alarm gives up (nobody gets stuck).
    public var maxReArms: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        label: String = "",
        sound: SoundChoice = .classic,
        hour: Int = 7,
        minute: Int = 0,
        weekdays: Set<Int> = Set(1...7),
        missions: [MissionConfig] = [MissionConfig(kind: .math)],
        reArmMinutes: Int = 2,
        maxReArms: Int = 15,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.label = label
        self.sound = sound
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.missions = missions
        self.reArmMinutes = reArmMinutes
        self.maxReArms = maxReArms
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, sound, hour, minute, weekdays, missions, reArmMinutes, maxReArms, isEnabled
    }

    /// Tolerant decoding: alarms saved by older versions lack `label` / `sound`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        sound = try c.decodeIfPresent(SoundChoice.self, forKey: .sound) ?? .classic
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        weekdays = try c.decode(Set<Int>.self, forKey: .weekdays)
        // Lossy: missions removed from the app (e.g. the old "steps" kind) are dropped
        // instead of making the whole alarm list undecodable.
        let decoded = try c.decode([LossyMission].self, forKey: .missions).compactMap(\.config)
        // Never leave an alarm without a mission (it could then be stopped for free).
        missions = decoded.isEmpty ? [MissionConfig(kind: .math)] : decoded
        reArmMinutes = try c.decode(Int.self, forKey: .reArmMinutes)
        maxReArms = try c.decode(Int.self, forKey: .maxReArms)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
    }

    /// "07:00"
    public var timeText: String { String(format: "%02d:%02d", hour, minute) }

    /// "Every day", "Weekdays", "Mon, Wed", "Once".
    public var repeatText: String {
        switch weekdays {
        case []: return "Once"
        case Set(1...7): return "Every day"
        case Set(2...6): return "Weekdays"
        case [1, 7]: return "Weekends"
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            // Monday-first order for display.
            return [2, 3, 4, 5, 6, 7, 1].filter(weekdays.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// Every mission is configured (e.g. a QR code is registered).
    public var isReady: Bool { !missions.isEmpty && missions.allSatisfy(\.isReady) }

    /// Alarm title: app name + the mission(s) to solve, e.g. "Earn It - Math Problem + Shake It".
    public var alarmTitle: String {
        let missions = missions.map(\.alarmTitle)
        return missions.isEmpty ? "Earn It" : "Earn It - " + missions.joined(separator: " + ")
    }

    /// Next time this plan rings strictly after `date`.
    public func nextFireDate(after date: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if fire > date, weekdays.isEmpty || weekdays.contains(weekday) {
                return fire
            }
        }
        return nil
    }
}

// MARK: - Wake session

/// State of today's wake-up. Written by the app and by App Intents (same process, standard UserDefaults).
public struct SessionState: Codable, Hashable, Sendable {
    /// Start of the day this session belongs to.
    public var day: Date
    public var firstEndedAt: Date?
    public var missionCompletedAt: Date?
    public var reArmCount: Int
    public var failSafeTriggered: Bool
    /// Follow-up alarm IDs currently scheduled (cancelled on mission success).
    public var followUpIDs: [UUID]
    /// The alarm (plan) that started this ring cycle: its missions, sound and re-ring settings apply.
    public var planID: UUID?

    public init(day: Date, firstEndedAt: Date? = nil, missionCompletedAt: Date? = nil,
                reArmCount: Int = 0, failSafeTriggered: Bool = false, followUpIDs: [UUID] = [],
                planID: UUID? = nil) {
        self.planID = planID
        self.day = day
        self.firstEndedAt = firstEndedAt
        self.missionCompletedAt = missionCompletedAt
        self.reArmCount = reArmCount
        self.failSafeTriggered = failSafeTriggered
        self.followUpIDs = followUpIDs
    }

    public var missionDone: Bool { missionCompletedAt != nil }

    /// This ring cycle is over (mission done or fail-safe hit).
    public var isFinished: Bool { missionDone || failSafeTriggered }

    /// An alarm has gone off and the mission is still outstanding.
    public var awaitingMission: Bool { firstEndedAt != nil && !missionDone && !failSafeTriggered }
}
