import Core
import Foundation

// MARK: - Answers

/// What keeps you in bed — picked in onboarding (multi-select), used to suggest the mission.
public enum MorningStruggle: String, Codable, CaseIterable, Sendable, Identifiable {
    case phoneInBed, snooze, sleepThrough, stayInBed, noEnergy
    /// Older saved progress used this case; it maps to "awake but staying in bed".
    case fallBackAsleep

    public var id: String { rawValue }

    /// Shown in onboarding (the legacy case is hidden).
    public static var choices: [MorningStruggle] { [.phoneInBed, .snooze, .sleepThrough, .stayInBed, .noEnergy] }

    public var title: String {
        switch self {
        case .phoneInBed: "Scrolling my phone"
        case .snooze: "Hitting snooze"
        case .sleepThrough: "Sleeping through alarms"
        case .stayInBed, .fallBackAsleep: "I wake up but stay in bed"
        case .noEnergy: "Feeling groggy for ages"
        }
    }

    public var symbol: String {
        switch self {
        case .phoneInBed: "iphone.gen3"
        case .snooze: "arrow.trianglehead.2.clockwise"
        case .sleepThrough: "moon.zzz.fill"
        case .stayInBed, .fallBackAsleep: "bed.double.fill"
        case .noEnergy: "battery.25percent"
        }
    }

    /// Mission that best counters this struggle.
    public var suggestedMission: MissionKind {
        switch self {
        case .snooze, .phoneInBed, .sleepThrough: .math     // engage the brain
        case .stayInBed, .fallBackAsleep, .noEnergy: .shake  // get the body moving
        }
    }
}

public enum AgeRange: String, Codable, CaseIterable, Sendable, Identifiable {
    case teen = "13-17", young = "18-24", adult = "25-34", mid = "35-44", older = "45-54", senior = "55+"
    public var id: String { rawValue }
    public var title: String { rawValue.replacingOccurrences(of: "-", with: "–") }
    public var symbol: String {
        switch self {
        case .teen: "backpack.fill"
        case .young: "graduationcap.fill"
        case .adult: "briefcase.fill"
        case .mid: "figure.2.and.child.holdinghands"
        case .older: "house.fill"
        case .senior: "globe.europe.africa.fill"
        }
    }
}

public enum HeardFrom: String, Codable, CaseIterable, Sendable, Identifiable {
    case instagram, tiktok, youtube, appStore, friend, reddit, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        case .appStore: "App Store"
        case .friend: "Friend or family"
        case .reddit: "Reddit"
        case .other: "Somewhere else"
        }
    }
    /// Plain symbols (no brand logos).
    public var symbol: String {
        switch self {
        case .instagram: "camera.fill"
        case .tiktok: "music.note"
        case .youtube: "play.rectangle.fill"
        case .appStore: "app.badge.fill"
        case .friend: "person.2.fill"
        case .reddit: "bubble.left.and.bubble.right.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}

/// "What goes through your head when your alarm rings?"
public enum AlarmReaction: String, Codable, CaseIterable, Sendable, Identifiable {
    case imUp, fiveMore, backupAlarm, whySoEarly
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .imUp: "I'm up"
        case .fiveMore: "Just 5 more minutes"
        case .backupAlarm: "I have a backup alarm"
        case .whySoEarly: "Ugh, why so early?"
        }
    }
    public var symbol: String {
        switch self {
        case .imUp: "bolt.fill"
        case .fiveMore: "zzz"
        case .backupAlarm: "alarm.waves.left.and.right.fill"
        case .whySoEarly: "questionmark"
        }
    }
}

/// "How long until you actually get up?"
public enum GetUpTime: String, Codable, CaseIterable, Sendable, Identifiable {
    case under10, tenTo30, thirtyTo60, overHour
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .under10: "Under 10 minutes"
        case .tenTo30: "10–30 minutes"
        case .thirtyTo60: "30–60 minutes"
        case .overHour: "Over an hour"
        }
    }
    public var symbol: String {
        switch self {
        case .under10: "gauge.with.dots.needle.0percent"
        case .tenTo30: "gauge.with.dots.needle.33percent"
        case .thirtyTo60: "gauge.with.dots.needle.67percent"
        case .overHour: "gauge.with.dots.needle.100percent"
        }
    }
    /// Typical minutes lost per morning (midpoint of the range).
    public var minutesLost: Int {
        switch self {
        case .under10: 5
        case .tenTo30: 20
        case .thirtyTo60: 45
        case .overHour: 75
        }
    }
}

/// "What would you do with the time back?"
public enum MorningGoal: String, Codable, CaseIterable, Sendable, Identifiable {
    case onTime, workout, quietTime, getAhead, feelAwake
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .onTime: "Be on time, every time"
        case .workout: "Work out before my day"
        case .quietTime: "Have quiet time for me"
        case .getAhead: "Get ahead on my day"
        case .feelAwake: "Feel awake, not a zombie"
        }
    }
    public var symbol: String {
        switch self {
        case .onTime: "clock.badge.checkmark.fill"
        case .workout: "figure.run"
        case .quietTime: "cup.and.saucer.fill"
        case .getAhead: "sunrise.fill"
        case .feelAwake: "eye.fill"
        }
    }
}

/// Answers collected during onboarding (also synced to the profile when signed in).
public struct OnboardingAnswers: Codable, Hashable, Sendable {
    public var name = ""
    public var ageRange: AgeRange?
    public var heardFrom: HeardFrom?
    public var reaction: AlarmReaction?
    public var getUpTime: GetUpTime?
    public var struggles: Set<MorningStruggle> = []
    public var goal: MorningGoal?
    public var hour: Int = 7
    public var minute: Int = 0
    public var weekdays: Set<Int> = Set(2...6)
    /// Chosen in the mission step (nil = use the suggestion).
    public var missions: [MissionConfig]?
    public var sound: SoundChoice = .classic
    /// The alarm onboarding created: replaying onboarding updates it instead of adding another.
    public var createdPlanID: UUID?

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case name, ageRange, heardFrom, reaction, getUpTime, struggles, goal, hour, minute, weekdays
        case missions, sound, createdPlanID
    }

    /// Tolerant: progress saved by older versions (fewer fields, removed cases) still loads.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        ageRange = try? c.decodeIfPresent(AgeRange.self, forKey: .ageRange)
        heardFrom = try? c.decodeIfPresent(HeardFrom.self, forKey: .heardFrom)
        reaction = try? c.decodeIfPresent(AlarmReaction.self, forKey: .reaction)
        getUpTime = try? c.decodeIfPresent(GetUpTime.self, forKey: .getUpTime)
        let rawStruggles = (try? c.decodeIfPresent([String].self, forKey: .struggles)) ?? []
        struggles = Set(rawStruggles.compactMap(MorningStruggle.init(rawValue:)))
        goal = try? c.decodeIfPresent(MorningGoal.self, forKey: .goal)
        hour = (try? c.decodeIfPresent(Int.self, forKey: .hour)) ?? 7
        minute = (try? c.decodeIfPresent(Int.self, forKey: .minute)) ?? 0
        weekdays = (try? c.decodeIfPresent(Set<Int>.self, forKey: .weekdays)) ?? Set(2...6)
        missions = try? c.decodeIfPresent([MissionConfig].self, forKey: .missions)
        sound = (try? c.decodeIfPresent(SoundChoice.self, forKey: .sound)) ?? .classic
        createdPlanID = try? c.decodeIfPresent(UUID.self, forKey: .createdPlanID)
    }

    /// Missions suggested by the struggles: one per distinct suggestion, Math first; Math if nothing picked.
    public var suggestedMissions: [MissionKind] {
        let kinds = Set(struggles.map(\.suggestedMission))
        let ordered = MissionKind.allCases.filter(kinds.contains)
        return ordered.isEmpty ? [.math] : ordered
    }

    /// The mission the mission step preselects (the first suggestion).
    public var suggestedMission: MissionKind { suggestedMissions.first ?? .math }

    /// What the alarm will use.
    public var chosenMissions: [MissionConfig] {
        missions ?? [MissionConfig(kind: suggestedMission)]
    }

    /// The first alarm, built from the answers.
    public func firstAlarm() -> AlarmPlan {
        let ready = chosenMissions.filter(\.isReady)
        return AlarmPlan(id: createdPlanID ?? UUID(), label: "Wake up", sound: sound, hour: hour, minute: minute,
                         weekdays: weekdays, missions: ready.isEmpty ? [MissionConfig(kind: .math)] : ready,
                         reArmMinutes: OnboardingPersonalization.reArmMinutes(getUpTime),
                         isEnabled: true)
    }

    public var timeText: String { String(format: "%02d:%02d", hour, minute) }
}

// MARK: - Steps

public enum OnboardingStep: String, Codable, CaseIterable, Sendable {
    case welcome, name, ageRange, heardFrom, alarmReaction, whyItWorks, getUpTime, struggles, goal
    case wakeTime, comparison, permissions, mission, missionSetup, sound, inviteFriend, account
    case building, summary, paywall

    /// Older saved progress may name steps that no longer exist.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "howItWorks": self = .whyItWorks
        case "goals": self = .struggles
        case "firstAlarm": self = .mission
        default: self = OnboardingStep(rawValue: raw) ?? .welcome
        }
    }

    /// Steps without a progress bar or back button (full-screen moments).
    public var isFullScreen: Bool {
        switch self {
        case .welcome, .building, .summary, .paywall: true
        default: false
        }
    }
}

/// Facts the flow needs to decide which steps to skip.
public struct OnboardingContext: Equatable, Sendable {
    public var accountsAvailable: Bool
    public var isSignedIn: Bool
    public var isPro: Bool
    public var bonusSoundUnlocked: Bool
    /// The chosen mission has settings (math difficulty, shake count, QR / item registration).
    public var missionHasSetup: Bool

    public init(accountsAvailable: Bool, isSignedIn: Bool, isPro: Bool, bonusSoundUnlocked: Bool = false,
                missionHasSetup: Bool = true) {
        self.accountsAvailable = accountsAvailable
        self.isSignedIn = isSignedIn
        self.isPro = isPro
        self.bonusSoundUnlocked = bonusSoundUnlocked
        self.missionHasSetup = missionHasSetup
    }
}

/// Pure step logic: order, skipping, back navigation.
public enum OnboardingFlow {
    public static func shouldSkip(_ step: OnboardingStep, _ context: OnboardingContext) -> Bool {
        switch step {
        case .account: !context.accountsAvailable || context.isSignedIn
        case .paywall: context.isPro
        case .inviteFriend: context.bonusSoundUnlocked
        case .missionSetup: !context.missionHasSetup
        default: false
        }
    }

    /// Next visible step, or nil when onboarding is complete.
    public static func next(after step: OnboardingStep, _ context: OnboardingContext) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: step) else { return nil }
        return all[(index + 1)...].first { !shouldSkip($0, context) }
    }

    /// Back stops at the building step: the alarm is already made, so the finale can't be redone.
    public static func previous(before step: OnboardingStep, _ context: OnboardingContext) -> OnboardingStep? {
        guard ![.welcome, .building, .summary].contains(step) else { return nil }
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: step) else { return nil }
        return all[..<index].last { !shouldSkip($0, context) && $0 != .building }
    }

    /// Steps shown with this context (for the progress bar).
    public static func visibleSteps(_ context: OnboardingContext) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { !shouldSkip($0, context) }
    }

    /// 0…1 for the progress bar.
    public static func fraction(at step: OnboardingStep, _ context: OnboardingContext) -> Double {
        let steps = visibleSteps(context)
        guard let index = steps.firstIndex(of: step), steps.count > 1 else { return 0 }
        return Double(index) / Double(steps.count - 1)
    }
}

// MARK: - Persistence

/// Saved progress so a killed app resumes where the user left off.
public struct OnboardingProgress: Codable, Equatable, Sendable {
    public var step: OnboardingStep = .welcome
    public var answers = OnboardingAnswers()
    public var completed = false

    public init() {}

    private enum CodingKeys: String, CodingKey { case step, answers, completed }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        step = (try? c.decodeIfPresent(OnboardingStep.self, forKey: .step)) ?? .welcome
        answers = (try? c.decodeIfPresent(OnboardingAnswers.self, forKey: .answers)) ?? OnboardingAnswers()
        completed = (try? c.decodeIfPresent(Bool.self, forKey: .completed)) ?? false
    }
}

public final class OnboardingStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "earnit.onboarding"
    /// Flag written by versions before the onboarding flow.
    private let legacyKey = "earnit.onboarded"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> OnboardingProgress {
        if let data = defaults.data(forKey: key),
           let progress = try? JSONDecoder().decode(OnboardingProgress.self, from: data) {
            return progress
        }
        var progress = OnboardingProgress()
        // Existing users already set up the app: don't make them onboard again.
        if defaults.bool(forKey: legacyKey) {
            progress.completed = true
            save(progress)
        }
        return progress
    }

    public func save(_ progress: OnboardingProgress) {
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: key) }
    }

    /// Debug: run onboarding again (answers kept).
    public func reset() {
        var progress = load()
        progress.completed = false
        progress.step = .welcome
        save(progress)
        defaults.removeObject(forKey: legacyKey)
    }
}
