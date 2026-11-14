import Core
import Foundation
import Observation
import os

private let log = Logger(subsystem: "be.earnit.app", category: "alarm")

/// Owns the wake-up loop for all alarms: schedule → ring → re-arm until mission done → cancel.
/// Called by the UI and by the App Intent attached to the alarm's X control.
///
/// Every ring cycle belongs to one alarm (`SessionState.planID`): that alarm's missions,
/// sound and re-ring settings apply until the cycle finishes.
@MainActor
@Observable
public final class AlarmCoordinator {
    public private(set) var plans: [AlarmPlan]
    public private(set) var session: SessionState?
    public private(set) var lastError: String?
    /// "Pause all alarms". Stays set until resumed or (for a dated pause) until it runs out.
    public private(set) var pause: AlarmPause?

    private let store: KeyValueStore
    private let scheduler: any AlarmScheduling
    private let sound: any AlarmSounding
    private let now: @Sendable () -> Date

    public init(store: KeyValueStore, scheduler: any AlarmScheduling, sound: any AlarmSounding,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.scheduler = scheduler
        self.sound = sound
        self.now = now
        self.plans = store.loadPlans()
        self.session = store.loadSession()
        self.pause = store.loadPause()
    }

    public var authorization: AlarmAuthorization { scheduler.authorization }

    public func requestAuthorization() async -> AlarmAuthorization {
        await scheduler.requestAuthorization()
    }

    /// Re-read persisted state (an intent may have changed it while the app was backgrounded).
    public func reload() {
        plans = store.loadPlans()
        session = store.loadSession()
        pause = store.loadPause()
        sync(with: scheduler.scheduledAlarms())
        updateSound()
    }

    /// Keeps the UI in step with AlarmKit while the app runs (ringing / countdown → mission).
    public func observeSystemAlarms() async {
        for await alarms in scheduler.alarmUpdates() {
            sync(with: alarms)
        }
    }

    /// An alarm is ringing, or a re-ring countdown runs (X pressed): the mission is due.
    private func sync(with alarms: [ScheduledAlarm]) {
        let mainIDs = Set(plans.map(\.id))
        if let ringing = alarms.first(where: \.isAlerting) {
            markAwaitingMission(ringingID: ringing.id, newRing: true)
        } else if alarms.contains(where: { $0.isCountingDown && !mainIDs.contains($0.id) }) {
            markAwaitingMission()  // countdowns only exist inside an active cycle
        }
    }

    /// The app should show the mission screen right now.
    public var needsMission: Bool {
        ReArmPolicy.currentSession(session, now: now()).awaitingMission
    }

    /// The alarm whose cycle is running (or would run): its missions are shown.
    public var activePlan: AlarmPlan? {
        plan(id: session?.planID) ?? plans.first
    }

    /// Soonest upcoming ring across all enabled alarms.
    public var nextAlarm: (plan: AlarmPlan, date: Date)? {
        plans.compactMap { plan in nextFireDate(for: plan).map { (plan, $0) } }
            .min { $0.1 < $1.1 }
    }

    /// Next ring, taking a pause into account (nil while paused indefinitely).
    public func nextFireDate(for plan: AlarmPlan) -> Date? {
        guard plan.isEnabled else { return nil }
        if let pause = activePause { return PausePolicy.firstRing(of: plan, after: pause) }
        return plan.nextFireDate(after: now())
    }

    // MARK: Pause all alarms

    /// The pause in effect right now (an expired one is ignored).
    public var activePause: AlarmPause? {
        PausePolicy.isPaused(pause, at: now()) ? pause : nil
    }

    /// Pause every alarm. Alarms ringing or counting down right now are left alone. A dated
    /// pause schedules each alarm's first ring after the pause as a one-off (same id), so alarms
    /// come back even if the app is never opened; the weekly repeat returns on the next launch.
    public func pauseAll(_ newPause: AlarmPause) async {
        pause = newPause
        store.savePause(newPause)
        await rescheduleAll()
        log.notice("alarms paused until \(newPause.until?.description ?? "resumed", privacy: .public)")
    }

    public func resumeAll() async {
        pause = nil
        store.savePause(nil)
        await rescheduleAll()
        log.notice("alarms resumed")
    }

    /// Clears a pause that has run out and restores the normal schedule. Called on launch / foreground.
    public func resumeIfPauseExpired() async {
        guard PausePolicy.isExpired(pause, at: now()) else { return }
        await resumeAll()
    }

    // MARK: Alarms (CRUD)

    /// Add a new alarm or replace an existing one (matched by id), then (re)schedule it.
    public func save(_ plan: AlarmPlan) async {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        store.savePlans(plans)
        await schedule(plan)
    }

    public func setEnabled(_ enabled: Bool, for id: UUID) async {
        guard var plan = plan(id: id) else { return }
        plan.isEnabled = enabled
        await save(plan)
    }

    public func delete(id: UUID) {
        scheduler.stop(id: id)
        scheduler.cancel(id: id)
        plans.removeAll { $0.id == id }
        store.savePlans(plans)
    }

    /// Re-register enabled alarms so they pick up the current alarm layout / sound after an app
    /// update. Skips alarms that are ringing or counting down right now.
    public func refreshAlarms() async {
        if PausePolicy.isExpired(pause, at: now()) {
            pause = nil
            store.savePause(nil)
        }
        await rescheduleAll()
    }

    /// Repeating alarms that AlarmKit no longer holds (e.g. the one-off "first ring after a pause"
    /// just finished) get their weekly schedule back.
    public func restoreMissingAlarms() async {
        await resumeIfPauseExpired()
        guard activePause == nil else { return }
        let known = Set(scheduler.scheduledAlarms().map(\.id))
        for plan in plans where plan.isEnabled && !plan.weekdays.isEmpty && !known.contains(plan.id) {
            await schedule(plan)
        }
    }

    private func rescheduleAll() async {
        let busy = Set(scheduler.scheduledAlarms().filter { $0.isAlerting || $0.isCountingDown }.map(\.id))
        for plan in plans where plan.isEnabled && !busy.contains(plan.id) {
            await schedule(plan)
        }
    }

    private func schedule(_ plan: AlarmPlan) async {
        scheduler.cancel(id: plan.id)
        guard plan.isEnabled else { return }
        do {
            if let pause = activePause {
                // Paused: only the first ring after the pause, as a one-off with the plan's id.
                guard let first = PausePolicy.firstRing(of: plan, after: pause) else { return }
                try await scheduler.scheduleOneOff(id: plan.id, at: first, title: plan.alarmTitle, sound: plan.sound)
            } else {
                try await scheduler.scheduleMain(plan)
            }
            lastError = nil
        } catch {
            lastError = "Could not schedule alarm: \(error.localizedDescription)"
        }
    }

    // MARK: Ringing loop

    /// App opened on the mission without the alarm's X (Live Activity tap / deep link).
    public func missionStarted(id: UUID?) {
        markAwaitingMission(ringingID: id)
        log.info("mission started id=\(id?.uuidString ?? "nil", privacy: .public)")
    }

    private func markAwaitingMission(ringingID id: UUID? = nil, newRing: Bool = false) {
        var s = freshOrCurrentSession(newRing: newRing)
        guard !s.missionDone else { return }
        if s.firstEndedAt == nil { s.firstEndedAt = now() }
        if s.planID == nil { s.planID = owner(of: id)?.id }
        if let id, plan(id: id) == nil, !s.followUpIDs.contains(id) { s.followUpIDs.append(id) }
        persist(s)
    }

    /// X on the alarm: silence it, re-arm a countdown follow-up, and (app opens) show the mission.
    public func alarmEnded(id: UUID?) async {
        let current = now()
        let isMain = plan(id: id) != nil
        // Make sure the alert is silenced (and a one-off removed) before re-arming.
        if let id {
            scheduler.stop(id: id)
            if !isMain { scheduler.cancel(id: id) }
        }
        var s = freshOrCurrentSession(newRing: true)
        if s.firstEndedAt == nil { s.firstEndedAt = current }
        if s.planID == nil { s.planID = owner(of: id)?.id }
        if let id { s.followUpIDs.removeAll { $0 == id } }
        log.info("alarm ended id=\(id?.uuidString ?? "nil", privacy: .public) reArms=\(s.reArmCount)")

        guard let plan = plan(id: s.planID) else {
            persist(s)
            return
        }
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
                                                     title: plan.alarmTitle, attempt: attempt, sound: plan.sound)
                s.followUpIDs.append(followUp)
                s.reArmCount = attempt
                setOwner(plan.id, of: followUp)
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
        Task { await restoreMissingAlarms() }
        return s
    }

    /// Stops whatever is ringing and removes every one-off alarm, including ones the session
    /// lost track of. Main alarms are only stopped, so their weekly repeat survives.
    private func silenceAll(extra: [UUID] = []) {
        let mainIDs = Set(plans.map(\.id))
        let ids = Set(scheduler.scheduledAlarms().map(\.id)).union(extra)
        for id in ids {
            scheduler.stop(id: id)
            if !mainIDs.contains(id) { scheduler.cancel(id: id) }
        }
        store.saveOwners([:])
    }

    // MARK: Debug

    /// Test ring for `planID` (or the first alarm) in `seconds`.
    public func debugRing(inSeconds seconds: TimeInterval, planID: UUID? = nil, sound override: SoundChoice? = nil) async {
        guard let plan = plan(id: planID) ?? plans.first else {
            lastError = "Add an alarm first."
            return
        }
        let id = UUID()
        do {
            try await scheduler.scheduleOneOff(id: id, at: now().addingTimeInterval(seconds),
                                               title: plan.alarmTitle, sound: override ?? plan.sound)
            setOwner(plan.id, of: id)
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

    /// Panic button: silence and remove every one-off alarm (main alarms stay scheduled).
    public func debugStopAll() {
        silenceAll(extra: session?.followUpIDs ?? [])
        if var s = session {
            s.followUpIDs = []
            persist(s)
        }
    }

    public func debugScheduledAlarms() -> [ScheduledAlarm] { scheduler.scheduledAlarms() }

    // MARK: Helpers

    public func plan(id: UUID?) -> AlarmPlan? {
        guard let id else { return nil }
        return plans.first { $0.id == id }
    }

    /// Which alarm an AlarmKit alarm belongs to: a main alarm itself, or the owner of a
    /// follow-up / test ring. Falls back to the first alarm.
    private func owner(of alarmID: UUID?) -> AlarmPlan? {
        if let main = plan(id: alarmID) { return main }
        if let alarmID, let ownerID = store.loadOwners()[alarmID], let owner = plan(id: ownerID) { return owner }
        return plans.first
    }

    private func setOwner(_ planID: UUID, of alarmID: UUID) {
        var owners = store.loadOwners()
        owners[alarmID] = planID
        store.saveOwners(owners)
    }

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
        updateSound()
    }

    /// The alarm keeps sounding for exactly as long as a mission is due: starts the moment X
    /// is pressed, stops only on mission success or fail-safe. Uses the ringing alarm's tone.
    private func updateSound() {
        if needsMission {
            sound.start(activePlan?.sound ?? .classic)
        } else {
            sound.stop()
        }
    }
}
