import Core
import Foundation
import Observation
import os

private let log = Logger(subsystem: "be.earnit.app", category: "alarm")

/// Owns the wake-up loop: schedule → ring → re-arm until mission done → cancel follow-ups.
/// Called by the UI and by the App Intents attached to the alarm buttons.
@MainActor
@Observable
public final class AlarmCoordinator {
    public private(set) var plan: AlarmPlan
    public private(set) var session: SessionState?
    public private(set) var lastError: String?

    private let store: KeyValueStore
    private let scheduler: any AlarmScheduling
    private let now: @Sendable () -> Date

    public init(store: KeyValueStore, scheduler: any AlarmScheduling, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.scheduler = scheduler
        self.now = now
        self.plan = store.loadPlan()
        self.session = store.loadSession()
    }

    public var authorization: AlarmAuthorization { scheduler.authorization }

    public func requestAuthorization() async -> AlarmAuthorization {
        await scheduler.requestAuthorization()
    }

    /// Re-read persisted state (an intent may have changed it while the app was backgrounded).
    public func reload() {
        plan = store.loadPlan()
        session = store.loadSession()
        sync(with: scheduler.scheduledAlarms())
    }

    /// Keeps the UI in step with AlarmKit while the app runs (ringing / countdown → mission).
    public func observeSystemAlarms() async {
        for await alarms in scheduler.alarmUpdates() {
            sync(with: alarms)
        }
    }

    /// An alarm is ringing, or a re-ring countdown runs (X pressed): the mission is due.
    private func sync(with alarms: [ScheduledAlarm]) {
        if alarms.contains(where: \.isAlerting) {
            markAwaitingMission(newRing: true)
        } else if alarms.contains(where: { $0.isCountingDown && $0.id != plan.id }) {
            markAwaitingMission()  // countdowns only exist inside an active cycle
        }
    }

    /// The app should show the mission screen right now.
    public var needsMission: Bool {
        ReArmPolicy.currentSession(session, now: now()).awaitingMission
    }

    public var nextFireDate: Date? {
        plan.isEnabled ? plan.nextFireDate(after: now()) : nil
    }

    // MARK: Plan

    public func apply(_ newPlan: AlarmPlan) async {
        scheduler.cancel(id: plan.id)
        if newPlan.id != plan.id { scheduler.cancel(id: newPlan.id) }
        plan = newPlan
        store.savePlan(newPlan)
        guard newPlan.isEnabled else { return }
        do {
            try await scheduler.scheduleMain(newPlan)
            lastError = nil
        } catch {
            lastError = "Could not schedule alarm: \(error.localizedDescription)"
        }
    }

    /// Re-register the main alarm so it picks up the current alarm layout (title, buttons)
    /// after an app update. Skipped while it is ringing or counting down.
    public func refreshMainAlarm() async {
        guard plan.isEnabled,
              !scheduler.scheduledAlarms().contains(where: { $0.id == plan.id && ($0.isAlerting || $0.isCountingDown) })
        else { return }
        await apply(plan)
    }

    // MARK: Ringing loop

    /// App opened on the mission without an alarm button (Live Activity tap / deep link).
    public func missionStarted(id: UUID?) {
        markAwaitingMission(trackingAlarm: id)
        log.info("mission started, alarm keeps ringing id=\(id?.uuidString ?? "nil", privacy: .public)")
    }

    private func markAwaitingMission(trackingAlarm id: UUID? = nil, newRing: Bool = false) {
        var s = freshOrCurrentSession(newRing: newRing)
        guard !s.missionDone else { return }
        if s.firstEndedAt == nil { s.firstEndedAt = now() }
        if let id, id != plan.id, !s.followUpIDs.contains(id) { s.followUpIDs.append(id) }
        persist(s)
    }

    /// X on the alarm: silence it, re-arm a countdown follow-up, and (app opens) show the mission.
    public func alarmEnded(id: UUID?) async {
        let current = now()
        // Make sure the alert is silenced (and a one-off removed) before re-arming.
        if let id {
            scheduler.stop(id: id)
            if id != plan.id { scheduler.cancel(id: id) }
        }
        var s = freshOrCurrentSession(newRing: true)
        if s.firstEndedAt == nil { s.firstEndedAt = current }
        if let id { s.followUpIDs.removeAll { $0 == id } }
        log.info("alarm ended id=\(id?.uuidString ?? "nil", privacy: .public) reArms=\(s.reArmCount)")

        switch ReArmPolicy.decide(session: s, plan: plan, now: current) {
        case .done:
            break
        case .failSafe:
            s.failSafeTriggered = true
            silenceAll()
            s.followUpIDs = []
            log.notice("fail-safe triggered")
        case let .reArm(date, attempt):
            let followUp = UUID()
            do {
                try await scheduler.scheduleFollowUp(id: followUp, after: date.timeIntervalSince(current),
                                                     title: plan.alarmTitle, attempt: attempt)
                s.followUpIDs.append(followUp)
                s.reArmCount = attempt
                log.info("re-armed attempt=\(attempt) at=\(date, privacy: .public)")
            } catch {
                lastError = "Could not re-arm: \(error.localizedDescription)"
            }
        }
        persist(s)
    }

    /// Mission verified. Returns the finished session so the caller can log it.
    @discardableResult
    public func missionSucceeded() -> SessionState {
        var s = ReArmPolicy.currentSession(store.loadSession(), now: now())
        silenceAll(extra: s.followUpIDs)
        s.followUpIDs = []
        s.missionCompletedAt = now()
        persist(s)
        log.notice("mission succeeded, all alarms silenced")
        return s
    }

    /// Stops whatever is ringing and removes every one-off alarm, including ones the session
    /// lost track of. The main plan alarm is only stopped, so its weekly repeat survives.
    private func silenceAll(extra: [UUID] = []) {
        let ids = Set(scheduler.scheduledAlarms().map(\.id)).union(extra)
        for id in ids {
            scheduler.stop(id: id)
            if id != plan.id { scheduler.cancel(id: id) }
        }
    }

    // MARK: Debug

    public func debugRing(inSeconds seconds: TimeInterval) async {
        let id = UUID()
        do {
            try await scheduler.scheduleOneOff(id: id, at: now().addingTimeInterval(seconds), title: plan.alarmTitle)
            var s = ReArmPolicy.currentSession(store.loadSession(), now: now())
            s.followUpIDs.append(id)
            persist(s)
        } catch {
            lastError = "Could not schedule test alarm: \(error.localizedDescription)"
        }
    }

    public func debugResetSession() {
        silenceAll(extra: session?.followUpIDs ?? [])
        persist(nil)
    }

    /// Test helper: forget today's session but leave AlarmKit alarms untouched.
    public func debugResetSessionKeepingAlarms() { persist(nil) }

    /// Panic button: silence and remove every one-off alarm (main plan stays scheduled).
    public func debugStopAll() {
        silenceAll(extra: session?.followUpIDs ?? [])
        if var s = session {
            s.followUpIDs = []
            persist(s)
        }
    }

    public func debugScheduledAlarms() -> [ScheduledAlarm] { scheduler.scheduledAlarms() }

    // MARK: Helpers

    private func freshOrCurrentSession(newRing: Bool) -> SessionState {
        let stored = store.loadSession()
        let s = ReArmPolicy.currentSession(stored, now: now(), newRing: newRing)
        if newRing, let stored, stored.isFinished, s != stored {
            log.info("new ring after finished cycle → fresh session")
        }
        return s
    }

    private func persist(_ s: SessionState?) {
        store.saveSession(s)
        session = s
    }
}
