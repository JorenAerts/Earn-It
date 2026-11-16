import Coach
import Core
import Foundation
import Localization

/// Pure: how onboarding answers change the app, and what Gloop says about them.
public enum OnboardingPersonalization {
    /// Coach tone that fits the answer (changeable in Settings).
    public static func suggestedTone(_ reaction: AlarmReaction?) -> CoachIntensity {
        switch reaction {
        case .imUp: .gentle
        case .fiveMore, .backupAlarm, nil: .toughLove
        case .whySoEarly: .savage
        }
    }

    /// Re-ring time after X: the longer you usually linger, the less time you get.
    public static func reArmMinutes(_ getUpTime: GetUpTime?) -> Int {
        switch getUpTime {
        case .under10: 3
        case .tenTo30, .thirtyTo60, nil: 2
        case .overHour: 1
        }
    }

    /// Hours won back per week: minutes usually lost × alarm days, in half hours, rounded down.
    /// nil when it's under one hour (not worth bragging about).
    public static func hoursBackPerWeek(_ getUpTime: GetUpTime?, weekdays: Set<Int>) -> Double? {
        guard let getUpTime else { return nil }
        let days = weekdays.isEmpty ? 1 : weekdays.count
        let hours = Double(getUpTime.minutesLost * days) / 60
        let rounded = (hours * 2).rounded(.down) / 2
        return rounded >= 1 ? rounded : nil
    }

    /// "That's about 3½ hours back every week."
    public static func hoursBackText(_ hours: Double) -> String {
        let whole = Int(hours)
        let half = hours - Double(whole) >= 0.5
        let number = half ? (whole == 0 ? "½" : "\(whole)½") : "\(whole)"
        return hours > 1 ? L10n.tr("That's about \(number) hours back every week.")
                         : L10n.tr("That's about \(number) hour back every week.")
    }

    /// Summary line under the wake-up time.
    public static func goalLine(_ goal: MorningGoal?) -> String {
        switch goal {
        case .onTime: L10n.tr("On time. Every time.")
        case .workout: L10n.tr("Time to train before the world wakes up")
        case .quietTime: L10n.tr("Quiet time that's all yours")
        case .getAhead: L10n.tr("A head start on your day")
        case .feelAwake: L10n.tr("Awake, not a zombie")
        case nil: L10n.tr("Your mornings, earned")
        }
    }

    /// The last step of the summary timeline.
    public static func finishLine(_ goal: MorningGoal?) -> String {
        switch goal {
        case .workout: L10n.tr("You're up. Go train.")
        case .quietTime: L10n.tr("You're up. Coffee's yours.")
        case .getAhead: L10n.tr("You're up, and ahead.")
        default: L10n.tr("You're up. Glad you set it.")
        }
    }

    /// Gloop reacting to an answer (speech bubble). nil = stay quiet.
    public static func coachReaction(to step: OnboardingStep, answers: OnboardingAnswers) -> String? {
        let name = answers.name.trimmingCharacters(in: .whitespaces)
        let who = name.isEmpty ? "friend" : name
        switch step {
        case .welcome:
            return L10n.tr("Hi, I'm \(CoachIdentity.name)! I get droopy when you snooze, so let's not.")
        case .name:
            return name.isEmpty ? L10n.tr("What should I call you?") : "\(name)! Love it. We're going to be a great team."
        case .ageRange:
            return L10n.tr("Just so I know who I'm waking up.")
        case .heardFrom:
            return L10n.tr("Glad you found me!")
        case .alarmReaction:
            switch answers.reaction {
            case .imUp: return L10n.tr("Ooh, a morning person. I like you already.")
            case .fiveMore: return L10n.tr("Five minutes. Sure. That's how I end up a puddle.")
            case .backupAlarm: return L10n.tr("A backup for your backup? You only need me now.")
            case .whySoEarly: return L10n.tr("Because the day is waiting, \(who). I'll make it worth it.")
            case nil: return L10n.tr("Be honest. I can tell.")
            }
        case .getUpTime:
            switch answers.getUpTime {
            case .under10: return L10n.tr("Not bad! Let's make it zero.")
            case .tenTo30: return L10n.tr("That's a whole episode of lying around. Noted.")
            case .thirtyTo60: return L10n.tr("An hour?! I'm melting just hearing that.")
            case .overHour: return L10n.tr("Over an hour. Okay, short re-rings for you, \(who).")
            case nil: return nil
            }
        case .struggles:
            if answers.struggles.contains(.snooze) { return L10n.tr("The snooze button is not your friend. I am.") }
            if answers.struggles.contains(.phoneInBed) { return L10n.tr("Phone down, feet on the floor. Deal?") }
            if answers.struggles.contains(.sleepThrough) { return L10n.tr("You won't sleep through me. I keep coming back.") }
            if !answers.struggles.isEmpty { return L10n.tr("Got it. I'll pick a mission that gets you moving.") }
            return L10n.tr("Pick everything that sounds like you.")
        case .goal:
            return answers.goal == nil ? L10n.tr("What's the reward, \(who)?") : L10n.tr("That's worth getting up for.")
        case .wakeTime:
            return L10n.tr("\(answers.timeText). I'll be there, bouncing.")
        case .mission:
            return L10n.tr("This is the only thing that stops me. Pick wisely.")
        case .sound:
            return L10n.tr("Pick something you can't ignore.")
        default:
            return nil
        }
    }
}

/// `Shared/Config/SocialProof.json`. Only real numbers and real reviews go in; empty = hidden.
public struct SocialProof: Codable, Equatable, Sendable {
    public struct Stat: Codable, Equatable, Sendable, Identifiable {
        public let value: String
        public let label: String
        public var id: String { label }
    }

    public struct Review: Codable, Equatable, Sendable, Identifiable {
        public let name: String
        public let text: String
        public let stars: Int
        public var id: String { name + text }
    }

    public var stats: [Stat]
    public var reviews: [Review]

    public static let empty = SocialProof(stats: [], reviews: [])

    public static func decode(_ data: Data?) -> SocialProof {
        struct File: Decodable { let stats: [Stat]?; let reviews: [Review]? }
        guard let data, let file = try? JSONDecoder().decode(File.self, from: data) else { return .empty }
        return SocialProof(stats: file.stats ?? [], reviews: (file.reviews ?? []).filter { (1...5).contains($0.stars) })
    }

    public static func load(from bundle: Bundle = .main) -> SocialProof {
        decode(bundle.url(forResource: "SocialProof", withExtension: "json").flatMap { try? Data(contentsOf: $0) })
    }
}
