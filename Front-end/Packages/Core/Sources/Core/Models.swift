import Foundation
import Localization

// MARK: - Missions

public enum MissionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case math
    case shake
    case qr
    case object
    case quiz
    case memory
    case typing
    case sky
    case bed
    case colorHunt

    public var id: String { rawValue }

    /// The missions offered in onboarding (the rest is in the app's mission picker).
    public static let onboardingKinds: [MissionKind] = [.math, .shake, .qr, .object, .quiz]

    /// Folder in the mission picker (filter chips).
    public var category: MissionCategory {
        switch self {
        case .math, .quiz, .memory, .typing: .brain
        case .shake: .body
        case .qr, .object, .sky, .bed, .colorHunt: .outOfBed
        }
    }

    public var displayName: String {
        switch self {
        case .math: L10n.tr("Math problems")
        case .shake: L10n.tr("Shake the phone")
        case .qr: L10n.tr("Scan a code")
        case .object: L10n.tr("Scan your item")
        case .quiz: L10n.tr("Quiz")
        case .memory: L10n.tr("Memory match")
        case .typing: L10n.tr("Tongue twister")
        case .sky: L10n.tr("Photo of the sky")
        case .bed: L10n.tr("Made-up bed")
        case .colorHunt: L10n.tr("Color hunt")
        }
    }

    /// Shown in the alarm title: "Gloop - Math Problem".
    public var alarmTitle: String {
        switch self {
        case .math: L10n.tr("Math Problem")
        case .shake: L10n.tr("Shake It")
        case .qr: L10n.tr("Scan Code")
        case .object: L10n.tr("Scan Item")
        case .quiz: L10n.tr("Quiz")
        case .memory: L10n.tr("Memory")
        case .typing: L10n.tr("Type It")
        case .sky: L10n.tr("Find the Sky")
        case .bed: L10n.tr("Make Your Bed")
        case .colorHunt: L10n.tr("Color Hunt")
        }
    }

    /// SF Symbol used in the mission picker, editor rows and the mission screen.
    public var symbol: String {
        switch self {
        case .math: "function"
        case .shake: "iphone.radiowaves.left.and.right"
        case .qr: "qrcode.viewfinder"
        case .object: "camera.viewfinder"
        case .quiz: "questionmark.bubble.fill"
        case .memory: "square.grid.3x3.fill"
        case .typing: "keyboard.fill"
        case .sky: "cloud.sun.fill"
        case .bed: "bed.double.fill"
        case .colorHunt: "paintpalette.fill"
        }
    }

    /// One line in the mission picker: what you'll have to do.
    public var tagline: String {
        switch self {
        case .math: L10n.tr("Solve problems in a row. Wakes up your brain.")
        case .shake: L10n.tr("Shake your phone hard. Wakes up your body.")
        case .qr: L10n.tr("Scan a code you stuck in another room.")
        case .object: L10n.tr("Scan an item you pick, like your toothbrush or coffee cup.")
        case .quiz: L10n.tr("Answer trivia questions on a topic you pick.")
        case .memory: L10n.tr("Flip cards and find all the pairs.")
        case .typing: L10n.tr("Type a tongue twister without a single mistake.")
        case .sky: L10n.tr("Point the camera at the sky, through a window or outside.")
        case .bed: L10n.tr("Make your bed and show it to the camera.")
        case .colorHunt: L10n.tr("Find something in a random color and show it to the camera.")
        }
    }

    /// Rough time it takes, shown in the picker.
    public var estimatedDuration: String {
        switch self {
        case .math: L10n.tr("~1 min")
        case .shake: L10n.tr("~30 s")
        case .qr, .object, .quiz, .memory, .typing, .bed, .colorHunt: L10n.tr("~1 min")
        case .sky: L10n.tr("~30 s")
        }
    }

    public var needsCamera: Bool { [.qr, .object, .sky, .bed, .colorHunt].contains(self) }

    /// Camera missions with a flashlight button. Not the sky: a flashlight can't light it up.
    public var usesTorch: Bool { needsCamera && self != .sky }

    /// Has to be set up before the alarm can use it (register a code / scan an item).
    public var needsSetup: Bool { needsPayload }

    /// After this long on the mission screen, offer a backup mission ("Can't find it?").
    public var backupAfter: TimeInterval? {
        switch self {
        case .object, .bed, .colorHunt: 120
        case .math, .shake, .qr, .quiz, .memory, .typing, .sky: nil
        }
    }

    /// "3 problems", "30 shakes" for `MissionConfig.target`.
    public func targetText(_ n: Int) -> String {
        switch self {
        case .math: L10n.tr("\(n) problems")
        case .shake: L10n.tr("\(n) shakes")
        case .qr: L10n.tr("\(n) codes")
        case .object: L10n.tr("\(n) items")
        case .quiz: L10n.tr("\(n) correct answers")
        case .memory: L10n.tr("\(n) pairs")
        case .typing: L10n.tr("\(n) tongue twisters")
        case .colorHunt: L10n.tr("\(n) colors")
        case .sky, .bed: L10n.tr("\(n) items")
        }
    }

    public var defaultTarget: Int {
        switch self {
        case .math: 3
        case .shake: 30
        case .qr, .object: 1
        case .quiz: 3
        case .memory: 6
        case .typing: 2
        case .sky, .bed: 1
        case .colorHunt: 2
        }
    }

    /// Allowed `target` values in setup; nil = target not configurable.
    public var targetRange: ClosedRange<Int>? {
        switch self {
        case .math: 1...20
        case .shake: 5...200
        case .qr, .object, .memory: nil
        case .quiz: 1...10
        case .typing: 1...5
        case .colorHunt: 1...3
        case .sky, .bed: nil
        }
    }

    public var targetStep: Int {
        switch self {
        case .math: 1
        case .shake: 5
        case .qr, .object, .quiz, .memory, .typing, .sky, .bed, .colorHunt: 1
        }
    }

    public var usesDifficulty: Bool {
        switch self {
        case .math, .shake, .memory, .typing: true
        case .qr, .object, .quiz, .sky, .bed, .colorHunt: false
        }
    }

    /// Needs something registered at setup (the QR code / the scanned item).
    public var needsPayload: Bool { self == .qr || self == .object || self == .bed }
}

/// Folders in the mission picker.
public enum MissionCategory: String, CaseIterable, Sendable, Identifiable {
    case brain, body, outOfBed, mindset

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .brain: L10n.tr("Brain")
        case .body: L10n.tr("Body")
        case .outOfBed: L10n.tr("Out of bed")
        case .mindset: L10n.tr("Mindset")
        }
    }

    public var symbol: String {
        switch self {
        case .brain: "brain.head.profile"
        case .body: "figure.run"
        case .outOfBed: "bed.double.fill"
        case .mindset: "sparkles"
        }
    }

    /// Kinds in this folder, in picker order.
    public var kinds: [MissionKind] { MissionKind.allCases.filter { $0.category == self } }
}

/// Quiz topics (20 questions each in `Config/Quiz.json`, translated per language).
public enum QuizTopic: String, Codable, CaseIterable, Sendable, Identifiable {
    case general, geography, science, animals, history, sports, moviesMusic, food

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: L10n.tr("General knowledge")
        case .geography: L10n.tr("Geography")
        case .science: L10n.tr("Science")
        case .animals: L10n.tr("Animals")
        case .history: L10n.tr("History")
        case .sports: L10n.tr("Sports")
        case .moviesMusic: L10n.tr("Movies & music")
        case .food: L10n.tr("Food")
        }
    }

    public var symbol: String {
        switch self {
        case .general: "lightbulb.fill"
        case .geography: "globe.europe.africa.fill"
        case .science: "atom"
        case .animals: "pawprint.fill"
        case .history: "building.columns.fill"
        case .sports: "sportscourt.fill"
        case .moviesMusic: "film.fill"
        case .food: "fork.knife"
        }
    }
}

public enum MissionDifficulty: String, Codable, CaseIterable, Sendable, Identifiable {
    case easy, medium, hard
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .easy: L10n.tr("Easy")
        case .medium: L10n.tr("Medium")
        case .hard: L10n.tr("Hard")
        }
    }
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
        case .math: L10n.tr("Solve \(target) problems in a row.")
        case .shake: L10n.tr("Shake your phone \(target) times.")
        case .qr: L10n.tr("Go to your code and scan it.")
        case .object:
            if let label, !label.isEmpty { L10n.tr("Find your \(L10n.inSentence(label)) and point the camera at it.") }
            else { L10n.tr("Find your item and point the camera at it.") }
        case .quiz: L10n.tr("Answer \(target) \(quizTopic.title) questions correctly.")
        case .memory: L10n.tr("Find all \(memoryPairs) pairs.")
        case .typing: L10n.tr("Type \(target) tongue twisters without a mistake.")
        case .sky: L10n.tr("Go to a window or outside and point the camera at the sky.")
        case .bed: L10n.tr("Make your bed, then stand at the foot of it and point the camera at it.")
        case .colorHunt: L10n.tr("Find \(target) things in the colors Gloop asks for.")
        }
    }

    /// Quiz: the topic is stored in `payload` (default General knowledge).
    public var quizTopic: QuizTopic {
        get { payload.flatMap(QuizTopic.init(rawValue:)) ?? .general }
        set { payload = newValue.rawValue }
    }

    /// Memory: pairs on the board, from the difficulty.
    public var memoryPairs: Int {
        switch difficulty {
        case .easy: 6
        case .medium: 8
        case .hard: 10
        }
    }

    /// Alarm title part: "Scan Toothbrush" for a named item.
    public var alarmTitle: String {
        if kind == .object, let label, !label.isEmpty { return L10n.tr("Scan \(label)") }
        return kind.alarmTitle
    }

    /// Fully configured and playable.
    public var isReady: Bool {
        !kind.needsPayload || !(payload?.isEmpty ?? true)
    }

    /// One-line description for lists: "3 problems · medium", "Code registered".
    public var summary: String {
        switch kind {
        case .qr: isReady ? L10n.tr("Code registered") : L10n.tr("No code registered")
        case .object: isReady ? (label ?? L10n.tr("Item scanned")) : L10n.tr("No item scanned yet")
        case .math: L10n.tr("\(target) problems · \(difficulty.title)")
        case .shake: L10n.tr("\(target) shakes · \(difficulty.title)")
        case .quiz: L10n.tr("\(quizTopic.title) · \(target) correct")
        case .memory: L10n.tr("\(memoryPairs) pairs · \(difficulty.title)")
        case .typing: L10n.tr("\(target) tongue twisters · \(difficulty.title)")
        case .sky: L10n.tr("Any sky: day, night, clouds or rain")
        case .bed: isReady ? L10n.tr("Bed scanned") : L10n.tr("No bed scanned yet")
        case .colorHunt: L10n.tr("\(target) colors")
        }
    }
}

// MARK: - Alarm sound

/// Bundled alarm tones (App/Sounds/Gloop_<rawValue>.caf). The same file rings via AlarmKit
/// and keeps playing in-app during the mission.
public enum AlarmSound: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic, chime, siren, digital, pulse
    case radar, gentleRise, reveille, morningMood, furElise
    /// Bonus: unlocked for free users by inviting a friend in onboarding.
    case riseAndConquer

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: L10n.tr("Classic Beep")
        case .chime: L10n.tr("Morning Chime")
        case .siren: L10n.tr("Rising Siren")
        case .digital: L10n.tr("Digital")
        case .pulse: L10n.tr("Deep Pulse")
        case .radar: L10n.tr("Radar")
        case .gentleRise: L10n.tr("Gentle Rise")
        case .reveille: L10n.tr("Reveille")
        case .morningMood: L10n.tr("Morning Mood")
        case .furElise: L10n.tr("Für Elise")
        case .riseAndConquer: L10n.tr("Rise & Conquer")
        }
    }

    public enum Category: String, CaseIterable, Sendable {
        case tones = "Tones", melodies = "Melodies"

        public var title: String {
            switch self {
            case .tones: L10n.tr("Tones")
            case .melodies: L10n.tr("Melodies")
            }
        }
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
        case .reveille: L10n.tr("Traditional bugle call")
        case .morningMood: L10n.tr("Edvard Grieg, Peer Gynt")
        case .furElise: L10n.tr("Ludwig van Beethoven")
        default: nil
        }
    }

    /// Resource name without extension.
    public var resourceName: String { "Gloop_\(rawValue)" }
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
        case []: return L10n.tr("Once")
        case Set(1...7): return L10n.tr("Every day")
        case Set(2...6): return L10n.tr("Weekdays")
        case [1, 7]: return L10n.tr("Weekends")
        default:
            var calendar = Calendar.current
            calendar.locale = L10n.locale
            let symbols = calendar.shortWeekdaySymbols
            // Monday-first order for display.
            return [2, 3, 4, 5, 6, 7, 1].filter(weekdays.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// Every mission is configured (e.g. a QR code is registered).
    public var isReady: Bool { !missions.isEmpty && missions.allSatisfy(\.isReady) }

    /// Alarm title: app name + the mission(s) to solve, e.g. "Gloop - Math Problem + Shake It".
    public var alarmTitle: String {
        let missions = missions.map(\.alarmTitle)
        return missions.isEmpty ? "Gloop" : "Gloop - " + missions.joined(separator: " + ")
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
