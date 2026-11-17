import ActivityKit
import AlarmKit
import AppIntents
import Core
import Foundation
import Localization
import os
import SwiftUI

private let log = Logger(subsystem: "be.gloop.app", category: "alarm")

/// Builds the intent attached to the alarm's X (stop) control. It lives in the app target
/// (so the system can discover it); the engine only needs to construct it.
public struct AlarmIntentFactory: Sendable {
    public var stop: @Sendable (UUID) -> any LiveActivityIntent

    public init(stop: @escaping @Sendable (UUID) -> any LiveActivityIntent) {
        self.stop = stop
    }
}

/// Live AlarmKit implementation. Device only for real ringing.
@MainActor
public final class AlarmKitScheduler: AlarmScheduling {
    private let intents: AlarmIntentFactory

    public init(intents: AlarmIntentFactory) {
        self.intents = intents
    }

    public var authorization: AlarmAuthorization {
        Self.map(AlarmManager.shared.authorizationState)
    }

    public func requestAuthorization() async -> AlarmAuthorization {
        do {
            return Self.map(try await AlarmManager.shared.requestAuthorization())
        } catch {
            return authorization
        }
    }

    public func scheduleMain(_ plan: AlarmPlan) async throws {
        let time = Alarm.Schedule.Relative.Time(hour: plan.hour, minute: plan.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = plan.weekdays.isEmpty
            ? .never
            : .weekly(plan.weekdays.sorted().compactMap(Self.weekday))
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: recurrence))
        let config = AlarmManager.AlarmConfiguration<GloopAlarmMetadata>.alarm(
            schedule: schedule,
            attributes: attributes(title: plan.alarmTitle, attempt: 0, countdown: false),
            stopIntent: intents.stop(plan.id),
            sound: .named(plan.sound.systemSoundFileName)
        )
        _ = try await AlarmManager.shared.schedule(id: plan.id, configuration: config)
    }

    public func scheduleOneOff(id: UUID, at date: Date, title: String, sound: SoundChoice) async throws {
        let config = AlarmManager.AlarmConfiguration<GloopAlarmMetadata>.alarm(
            schedule: .fixed(date),
            attributes: attributes(title: title, attempt: 0, countdown: false),
            stopIntent: intents.stop(id),
            sound: .named(sound.systemSoundFileName)
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
    }

    public func scheduleFollowUp(id: UUID, after duration: TimeInterval, title: String, attempt: Int,
                                 sound: SoundChoice) async throws {
        let config = AlarmManager.AlarmConfiguration<GloopAlarmMetadata>.timer(
            duration: duration,
            attributes: attributes(title: title, attempt: attempt, countdown: true),
            stopIntent: intents.stop(id),
            sound: .named(sound.systemSoundFileName)
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
        log.info("follow-up \(id, privacy: .public) in \(duration)s")
    }

    public func stop(id: UUID) {
        do {
            try AlarmManager.shared.stop(id: id)
            log.info("stopped \(id, privacy: .public)")
        } catch {
            log.notice("stop \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func cancel(id: UUID) {
        do {
            try AlarmManager.shared.cancel(id: id)
            log.info("cancelled \(id, privacy: .public)")
        } catch {
            log.notice("cancel \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func scheduledAlarms() -> [ScheduledAlarm] {
        ((try? AlarmManager.shared.alarms) ?? []).map { Self.describe($0) }
    }

    public func alarmUpdates() -> AsyncStream<[ScheduledAlarm]> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                for await alarms in AlarmManager.shared.alarmUpdates {
                    continuation.yield(alarms.map(Self.describe))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Private


    private static func describe(_ alarm: Alarm) -> ScheduledAlarm {
        ScheduledAlarm(id: alarm.id, state: String(describing: alarm.state),
                       isAlerting: alarm.state == .alerting, isCountingDown: alarm.state == .countdown)
    }

    private func attributes(title: String, attempt: Int, countdown: Bool) -> AlarmAttributes<GloopAlarmMetadata> {
        // Only the system X/Stop control: it opens the app on the mission (see StopAlarmIntent).
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title))
        // No pause button: the re-ring countdown can't be paused.
        let presentation = AlarmPresentation(
            alert: alert,
            countdown: countdown ? AlarmPresentation.Countdown(title: L10n.resource("Rings again in")) : nil
        )
        return AlarmAttributes(
            presentation: presentation,
            metadata: GloopAlarmMetadata(title: title, attempt: attempt),
            tintColor: .orange
        )
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> AlarmAuthorization {
        switch state {
        case .authorized: .authorized
        case .denied: .denied
        default: .notDetermined
        }
    }

    private static func weekday(_ number: Int) -> Locale.Weekday? {
        switch number {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
    }
}
