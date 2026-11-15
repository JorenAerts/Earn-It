import Coach
import Core
import Foundation

/// Pure: how onboarding answers change the app, and what Sergeant Rise says about them.
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
        return "That's about \(number) hour\(hours > 1 ? "s" : "") back every week."
    }

    /// Summary line under the wake-up time.
    public static func goalLine(_ goal: MorningGoal?) -> String {
        switch goal {
        case .onTime: "On time. Every time."
        case .workout: "Time to train before the world wakes up"
        case .quietTime: "Quiet time that's all yours"
        case .getAhead: "A head start on your day"
        case .feelAwake: "Awake, not a zombie"
        case nil: "Your mornings, earned"
        }
    }

    /// The last step of the summary timeline.
    public static func finishLine(_ goal: MorningGoal?) -> String {
        switch goal {
        case .workout: "You're up. Go train."
        case .quietTime: "You're up. Coffee's yours."
        case .getAhead: "You're up, and ahead."
        default: "You're up. Glad you set it."
        }
    }

    /// Sergeant Rise reacting to an answer (speech bubble). nil = stay quiet.
    public static func coachReaction(to step: OnboardingStep, answers: OnboardingAnswers) -> String? {
        let name = answers.name.trimmingCharacters(in: .whitespaces)
        let who = name.isEmpty ? "recruit" : name
        switch step {
        case .welcome:
            return "Sergeant Rise reporting. I'll get you out of bed. Every. Single. Morning."
        case .name:
            return name.isEmpty ? "Every soldier has a name. What's yours?" : "\(name). Good name. Let's make it a disciplined one."
        case .ageRange:
            return "Just so I know who I'm training."
        case .heardFrom:
            return "Someone's spreading the word. Good."
        case .alarmReaction:
            switch answers.reaction {
            case .imUp: return "Ha! Then let's keep it that way."
            case .fiveMore: return "Five minutes. Sure. That's how it starts."
            case .backupAlarm: return "A backup for your backup? I'll be your only alarm from now on."
            case .whySoEarly: return "Because I said so, \(who). I'll go easy on you. Not."
            case nil: return "Be honest. I'll know."
            }
        case .getUpTime:
            switch answers.getUpTime {
            case .under10: return "Not bad. We'll make it zero."
            case .tenTo30: return "That's a whole episode of lying around. Noted."
            case .thirtyTo60: return "An hour?! We have work to do."
            case .overHour: return "Over an hour. Right. Short re-rings for you, \(who)."
            case nil: return nil
            }
        case .struggles:
            if answers.struggles.contains(.snooze) { return "The snooze button is not your friend. I am." }
            if answers.struggles.contains(.phoneInBed) { return "Phone down, feet on the floor. That's the drill." }
            if answers.struggles.contains(.sleepThrough) { return "You won't sleep through me. I keep coming back." }
            if !answers.struggles.isEmpty { return "Got it. I'll pick a mission that gets you moving." }
            return "Pick everything that sounds like you."
        case .goal:
            return answers.goal == nil ? "What's the reward, \(who)?" : "That's worth getting up for."
        case .wakeTime:
            return "\(answers.timeText). I'll be there."
        case .mission:
            return "This is what stops me. Nothing else will."
        case .sound:
            return "Pick something you can't ignore."
        default:
            return nil
        }
    }
}

/// `Config/SocialProof.json`. Only real numbers and real reviews go in; empty = hidden.
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
