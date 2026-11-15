import Core
import Foundation
import Telemetry

// Mapping app models to non-personal analytics values (no labels, names or IDs).

extension AlarmPlan {
    public func telemetrySummary(alarmCount: Int) -> AlarmSummary {
        AlarmSummary(missions: missions.map(\.kind.rawValue).joined(separator: "+"), soundKind: sound.telemetryKind,
                     weekdaysCount: weekdays.count, hour: hour, reRingMinutes: reArmMinutes, alarmCount: alarmCount)
    }
}

extension SoundChoice {
    /// "builtIn.reveille", "custom", "appleMusic" — never a file or song name.
    var telemetryKind: String {
        switch self {
        case .builtIn(let sound): "builtIn.\(sound.rawValue)"
        case .custom: "custom"
        case .appleMusic: "appleMusic"
        }
    }
}

extension OnboardingAnswers {
    /// The answer given on `step`, as analytics parameters (enums and buckets only).
    func telemetryAnswers(for step: OnboardingStep) -> [String: String] {
        switch step {
        case .name: ["gaveName": "\(!name.trimmingCharacters(in: .whitespaces).isEmpty)"]
        case .ageRange: ageRange.map { ["ageRange": $0.rawValue] } ?? [:]
        case .heardFrom: heardFrom.map { ["heardFrom": $0.rawValue] } ?? [:]
        case .alarmReaction: reaction.map { ["reaction": $0.rawValue] } ?? [:]
        case .getUpTime: getUpTime.map { ["getUpTime": $0.rawValue] } ?? [:]
        case .struggles: ["struggles": struggles.map(\.rawValue).sorted().joined(separator: "+")]
        case .goal: goal.map { ["goal": $0.rawValue] } ?? [:]
        case .wakeTime: ["wakeHour": TelemetryBuckets.hour(hour), "weekdaysCount": "\(weekdays.count)"]
        case .mission: ["mission": chosenMissions.map(\.kind.rawValue).joined(separator: "+")]
        case .missionSetup:
            chosenMissions.first.map { ["difficulty": $0.difficulty.rawValue, "target": "\($0.target)"] } ?? [:]
        case .sound: ["sound": sound.telemetryKind]
        default: [:]
        }
    }
}
