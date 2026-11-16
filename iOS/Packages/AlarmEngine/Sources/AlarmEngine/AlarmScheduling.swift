import Core
import Foundation

public enum AlarmAuthorization: Sendable {
    case notDetermined, denied, authorized
}

/// An alarm the system currently knows about (debug + clean-up sweeps).
public struct ScheduledAlarm: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let state: String
    public let isAlerting: Bool
    /// A re-ring countdown is running (user pressed X, mission still open).
    public let isCountingDown: Bool
    public init(id: UUID, state: String, isAlerting: Bool = false, isCountingDown: Bool = false) {
        self.id = id
        self.state = state
        self.isAlerting = isAlerting
        self.isCountingDown = isCountingDown
    }
}

/// Abstraction over AlarmKit so the coordinator is testable on the Simulator.
@MainActor
public protocol AlarmScheduling: AnyObject {
    var authorization: AlarmAuthorization { get }
    func requestAuthorization() async -> AlarmAuthorization
    /// The plan's main (possibly repeating) alarm, using `plan.id`.
    func scheduleMain(_ plan: AlarmPlan) async throws
    /// One-off alarm at a fixed date (debug "ring in…").
    func scheduleOneOff(id: UUID, at date: Date, title: String, sound: SoundChoice) async throws
    /// Re-ring after Stop: a countdown alarm, shown live on the Lock Screen / Dynamic Island.
    func scheduleFollowUp(id: UUID, after duration: TimeInterval, title: String, attempt: Int,
                          sound: SoundChoice) async throws
    /// Silence an alerting alarm. A repeating alarm stays scheduled for its next occurrence.
    func stop(id: UUID)
    /// Remove an alarm entirely.
    func cancel(id: UUID)
    /// Every alarm AlarmKit currently holds for this app.
    func scheduledAlarms() -> [ScheduledAlarm]
    /// Live stream of alarm state changes.
    func alarmUpdates() -> AsyncStream<[ScheduledAlarm]>
}

/// In-memory scheduler for unit tests and previews.
@MainActor
public final class FakeScheduler: AlarmScheduling {
    public var authorization: AlarmAuthorization = .authorized
    public private(set) var mainPlans: [UUID: AlarmPlan] = [:]
    public private(set) var oneOffs: [UUID: (date: Date, title: String)] = [:]
    public private(set) var followUpDurations: [UUID: TimeInterval] = [:]
    public private(set) var sounds: [UUID: SoundChoice] = [:]
    public private(set) var stopped: [UUID] = []
    public private(set) var cancelled: [UUID] = []
    /// Alarms currently ringing (tests set this).
    public var alerting: Set<UUID> = []

    public init() {}

    public func requestAuthorization() async -> AlarmAuthorization { authorization }
    public func scheduleMain(_ plan: AlarmPlan) async throws {
        mainPlans[plan.id] = plan
        sounds[plan.id] = plan.sound
    }
    public func scheduleOneOff(id: UUID, at date: Date, title: String, sound: SoundChoice) async throws {
        oneOffs[id] = (date, title)
        sounds[id] = sound
    }
    public func scheduleFollowUp(id: UUID, after duration: TimeInterval, title: String, attempt: Int,
                                 sound: SoundChoice) async throws {
        oneOffs[id] = (Date().addingTimeInterval(duration), title)
        followUpDurations[id] = duration
        sounds[id] = sound
    }
    public func stop(id: UUID) {
        stopped.append(id)
        alerting.remove(id)
        oneOffs[id] = nil  // a stopped one-off alarm is finished
        followUpDurations[id] = nil
    }
    public func cancel(id: UUID) {
        cancelled.append(id)
        mainPlans[id] = nil
        oneOffs[id] = nil
        followUpDurations[id] = nil
    }
    public func scheduledAlarms() -> [ScheduledAlarm] {
        (Array(mainPlans.keys) + Array(oneOffs.keys)).map {
            ScheduledAlarm(id: $0, state: alerting.contains($0) ? "alerting" : "scheduled",
                           isAlerting: alerting.contains($0),
                           isCountingDown: followUpDurations[$0] != nil && !alerting.contains($0))
        }
    }
    public func alarmUpdates() -> AsyncStream<[ScheduledAlarm]> { AsyncStream { $0.finish() } }

    /// Test helper: an alarm AlarmKit has but the session lost track of.
    public func injectOrphan(id: UUID = UUID(), at date: Date = .now) -> UUID {
        oneOffs[id] = (date, "orphan")
        return id
    }
}
