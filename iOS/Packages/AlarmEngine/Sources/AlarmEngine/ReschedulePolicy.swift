import Core
import Foundation

/// Pure decisions for keeping AlarmKit in step with the alarm list.
///
/// Background (device logs, 17 Nov 2026): two scheduling passes on app open (launch refresh +
/// foreground restore) both cancelled and re-added the same alarm id; AlarmKit refused the second
/// with "Not scheduling an alarm with a duplicate ID" (AlarmServiceError invalidInput, shown as
/// "AlarmKit error 0"). So: passes run one at a time, unchanged alarms are left alone, and an
/// error while the alarm is present counts as scheduled.
public enum ReschedulePolicy {
    public enum Decision: Equatable, Sendable { case skip, schedule }

    /// What AlarmKit should hold for `plan`. A change (time, days, title/language, sound, pause,
    /// app version) means re-scheduling; otherwise the alarm already there is kept.
    public static func signature(for plan: AlarmPlan, pauseFirstRing: Date?, paused: Bool, appVersion: String) -> String {
        let pausePart: String
        if paused {
            pausePart = pauseFirstRing.map { "pause@\(Int($0.timeIntervalSince1970))" } ?? "pause-indefinite"
        } else {
            pausePart = "weekly"
        }
        let days = plan.weekdays.sorted().map(String.init).joined(separator: ",")
        return [String(format: "%02d:%02d", plan.hour, plan.minute), days, plan.alarmTitle,
                plan.sound.systemSoundFileName, pausePart, appVersion].joined(separator: "|")
    }

    /// `force` = the user just saved this alarm (always re-register it).
    public static func decide(enabled: Bool, busy: Bool, present: Bool, signatureMatches: Bool, force: Bool) -> Decision {
        guard enabled, !busy else { return .skip }
        if force { return .schedule }
        return present && signatureMatches ? .skip : .schedule
    }

    /// AlarmKit alarms nobody owns any more (not an alarm id, follow-up or test ring) that are
    /// idle. Ringing or counting-down alarms are never touched.
    public static func orphans(_ alarms: [ScheduledAlarm], known: Set<UUID>) -> [UUID] {
        alarms.filter { !known.contains($0.id) && !$0.isAlerting && !$0.isCountingDown }.map(\.id)
    }
}
