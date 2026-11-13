import Core
import Foundation

/// What makes mornings hard — picked in onboarding, used to suggest missions.
public enum MorningStruggle: String, Codable, CaseIterable, Sendable, Identifiable {
    case snooze, fallBackAsleep, phoneInBed, noEnergy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .snooze: "I keep hitting snooze"
        case .fallBackAsleep: "I fall back asleep"
        case .phoneInBed: "I scroll my phone in bed"
        case .noEnergy: "I feel groggy for ages"
        }
    }

    public var symbol: String {
        switch self {
        case .snooze: "alarm.waves.left.and.right"
        case .fallBackAsleep: "bed.double.fill"
        case .phoneInBed: "iphone.gen3"
        case .noEnergy: "battery.25percent"
        }
    }

    /// Mission that best counters this struggle.
    public var suggestedMission: MissionKind {
        switch self {
        case .snooze, .phoneInBed: .math        // engage the brain
        case .fallBackAsleep, .noEnergy: .shake // get the body moving
        }
    }
}

/// Answers collected during onboarding (also synced to the profile when signed in).
public struct OnboardingAnswers: Codable, Hashable, Sendable {
    public var hour: Int = 7
    public var minute: Int = 0
    public var weekdays: Set<Int> = Set(2...6)
    public var struggles: Set<MorningStruggle> = []

    public init() {}

    /// Missions for the first alarm: one per distinct suggestion, Math first; Math if nothing picked.
    public var suggestedMissions: [MissionKind] {
        let kinds = Set(struggles.map(\.suggestedMission))
        let ordered = MissionKind.allCases.filter(kinds.contains)
        return ordered.isEmpty ? [.math] : ordered
    }

    /// The first alarm, prefilled from the answers.
    public func firstAlarm() -> AlarmPlan {
        AlarmPlan(label: "Wake up", hour: hour, minute: minute, weekdays: weekdays,
                  missions: suggestedMissions.map { MissionConfig(kind: $0) }, isEnabled: true)
    }
}

public enum OnboardingStep: String, Codable, CaseIterable, Sendable {
    case welcome, howItWorks, goals, account, permissions, firstAlarm, paywall
}

/// Facts the flow needs to decide which steps to skip.
public struct OnboardingContext: Equatable, Sendable {
    public var accountsAvailable: Bool
    public var isSignedIn: Bool
    public var isPro: Bool

    public init(accountsAvailable: Bool, isSignedIn: Bool, isPro: Bool) {
        self.accountsAvailable = accountsAvailable
        self.isSignedIn = isSignedIn
        self.isPro = isPro
    }
}

/// Pure step logic: order, skipping, back navigation.
public enum OnboardingFlow {
    public static func shouldSkip(_ step: OnboardingStep, _ context: OnboardingContext) -> Bool {
        switch step {
        case .account: !context.accountsAvailable || context.isSignedIn
        case .paywall: context.isPro
        default: false
        }
    }

    /// Next visible step, or nil when onboarding is complete.
    public static func next(after step: OnboardingStep, _ context: OnboardingContext) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: step) else { return nil }
        return all[(index + 1)...].first { !shouldSkip($0, context) }
    }

    public static func previous(before step: OnboardingStep, _ context: OnboardingContext) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: step) else { return nil }
        return all[..<index].last { !shouldSkip($0, context) }
    }

    /// Steps shown with this context (for the progress bar).
    public static func visibleSteps(_ context: OnboardingContext) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { !shouldSkip($0, context) }
    }
}

/// Saved progress so a killed app resumes where the user left off.
public struct OnboardingProgress: Codable, Equatable, Sendable {
    public var step: OnboardingStep = .welcome
    public var answers = OnboardingAnswers()
    public var completed = false

    public init() {}
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
