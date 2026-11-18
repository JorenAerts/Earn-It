import Core
import Foundation
import Localization
import Observation
import os

private let log = Logger(subsystem: "be.gloop.app", category: "alarm")

/// Owns the wake-up loop for all alarms: schedule → ring → re-arm until mission done → cancel.
/// Called by the UI and by the App Intent attached to the alarm's X control.
///
/// Every ring cycle belongs to one alarm (`SessionState.planID`): that alarm's missions,
/// sound and re-ring settings apply until the cycle finishes.
/// Moments in the wake-up loop, for analytics (forwarded by the app; the engine stays dependency-free).
public enum AlarmLoopEvent: Equatable, Sendable {
    case rang
    case stopped(attempt: Int)
    case failSafe(rings: Int)
}

@MainActor
@Observable
public final class AlarmCoordinator {
    public private(set) var plans: [AlarmPlan]
    public private(set) var session: SessionState?
    public private(set) var lastError: String?
    /// Analytics hook: ring, stop (X) and fail-safe.
    @ObservationIgnored public var onEvent: (@MainActor (AlarmLoopEvent) -> Void)?
    @ObservationIgnored private var lastRingingID: UUID?

    /// "Pause all alarms". Stays set until resumed or (for a dated pause) until it runs out.
    public private(set) var pause: AlarmPause?

    private let store: KeyValueStore
    private let scheduler: any AlarmScheduling
    private let sound: any AlarmSounding
    private let now: @Sendable () -> Date
    /// Part of each alarm's signature: an app update re-registers alarms once (new layout / sound).
    private let appVersion: String
    /// The scheduling pass in progress. Passes run one after another: AlarmKit refuses a second
    /// schedule of an id that a concurrent pass just added ("duplicate ID").
    @ObservationIgnored private var pass: Task<Void, Never>?
    /// Pause before retrying a failed schedule (tests use zero).
    @ObservationIgnored public var retryDelay: Duration = .milliseconds(500)

    public init(store: KeyValueStore, scheduler: any AlarmScheduling, sound: any AlarmSounding,
                now: @escaping @Sendable () -> Date = { Date() },
                appVersion: String = AlarmCoordinator.bundleVersion) {
        self.store = store
        self.scheduler = scheduler
        self.sound = sound
        self.now = now
        self.appVersion = appVersion
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
            if ringing.id != lastRingingID {
                lastRingingID = ringing.id
                onEvent?(.rang)
            }
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
        await serialized { await self.rescheduleAll() }
        log.notice("alarms paused until \(newPause.until?.description ?? "resumed", privacy: .public)")
    }

    public func resumeAll() async {
        pause = nil
        store.savePause(nil)
        await serialized { await self.rescheduleAll() }
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
        await serialized { await self.schedule(plan, force: true) }
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
        setSignature(nil, for: id)
    }

    /// Re-register enabled alarms so they pick up the current alarm layout / sound after an app
    /// update. Skips alarms that are ringing or counting down right now.
    public func refreshAlarms() async {
        if PausePolicy.isExpired(pause, at: now()) {
            pause = nil
            store.savePause(nil)
        }
        await serialized {
            await self.rescheduleAll()
            self.cancelOrphans()
            self.clearErrorIfAllPresent()
        }
    }

    /// Repeating alarms that AlarmKit no longer holds (e.g. the one-off "first ring after a pause"
    /// just finished) get their weekly schedule back.
    public func restoreMissingAlarms() async {
        await resumeIfPauseExpired()
        guard activePause == nil else { return }
        await serialized {
            // Checked inside the pass: a pass that just ran may have added them already.
            let known = Set(self.scheduler.scheduledAlarms().map(\.id))
            for plan in self.plans where plan.isEnabled && !plan.weekdays.isEmpty && !known.contains(plan.id) {
                await self.schedule(plan, force: true)
            }
            self.clearErrorIfAllPresent()
        }
    }

    /// Runs scheduling work one pass at a time, in call order. Never call it from inside a pass.
    private func serialized(_ work: @escaping @MainActor () async -> Void) async {
        let previous = pass
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        pass = task
        await task.value
    }

    private func rescheduleAll() async {
        let alarms = scheduler.scheduledAlarms()
        let busy = Set(alarms.filter { $0.isAlerting || $0.isCountingDown }.map(\.id))
        for plan in plans where plan.isEnabled && !busy.contains(plan.id) {
            await schedule(plan, force: false)
        }
    }

    /// (Re)registers `plan` in AlarmKit. Without `force`, an alarm that AlarmKit already holds
    /// with the same signature is left alone.
    private func schedule(_ plan: AlarmPlan, force: Bool) async {
        let signature = signature(for: plan)
        let alarms = scheduler.scheduledAlarms()
        let present = alarms.contains { $0.id == plan.id }
        let busy = alarms.contains { $0.id == plan.id && ($0.isAlerting || $0.isCountingDown) }
        if !plan.isEnabled {
            scheduler.cancel(id: plan.id)
            setSignature(nil, for: plan.id)
            return
        }
        let decision = ReschedulePolicy.decide(enabled: true, busy: busy && !force, present: present,
                                               signatureMatches: store.loadAlarmSignatures()[plan.id] == signature, force: force)
        guard decision == .schedule else {
            log.info("alarm \(plan.id, privacy: .public) unchanged, kept")
            return
        }
        if present { scheduler.cancel(id: plan.id) }  // replace; nothing to cancel otherwise
        do {
            try await register(plan)
            succeeded(plan, signature)
        } catch {
            // AlarmKit may already hold the id (e.g. it refused a duplicate): that's scheduled.
            if scheduler.scheduledAlarms().contains(where: { $0.id == plan.id }) {
                log.notice("alarm \(plan.id, privacy: .public): \(Self.describe(error), privacy: .public), but it is scheduled")
                succeeded(plan, signature)
                return
            }
            log.error("alarm \(plan.id, privacy: .public) failed: \(Self.describe(error), privacy: .public); retrying")
            try? await Task.sleep(for: retryDelay)
            if scheduler.scheduledAlarms().contains(where: { $0.id == plan.id }) { scheduler.cancel(id: plan.id) }
            do {
                try await register(plan)
                succeeded(plan, signature)
            } catch {
                if scheduler.scheduledAlarms().contains(where: { $0.id == plan.id }) {
                    succeeded(plan, signature)
                } else {
                    log.error("alarm \(plan.id, privacy: .public) failed again: \(Self.describe(error), privacy: .public)")
                    lastError = L10n.tr("Could not schedule alarm: \(error.localizedDescription)")
                }
            }
        }
    }

    private func register(_ plan: AlarmPlan) async throws {
        if let pause = activePause {
            // Paused: only the first ring after the pause, as a one-off with the plan's id.
            guard let first = PausePolicy.firstRing(of: plan, after: pause) else { return }
            try await scheduler.scheduleOneOff(id: plan.id, at: first, title: plan.alarmTitle, sound: plan.sound)
        } else {
            try await scheduler.scheduleMain(plan)
        }
    }

    private func succeeded(_ plan: AlarmPlan, _ signature: String) {
        setSignature(signature, for: plan.id)
        lastError = nil
        log.info("alarm \(plan.id, privacy: .public) scheduled")
    }

    private func signature(for plan: AlarmPlan) -> String {
        let pause = activePause
        return ReschedulePolicy.signature(for: plan, pauseFirstRing: pause.flatMap { PausePolicy.firstRing(of: plan, after: $0) },
                                          paused: pause != nil, appVersion: appVersion)
    }

    private func setSignature(_ signature: String?, for id: UUID) {
        var all = store.loadAlarmSignatures()
        all[id] = signature
        store.saveAlarmSignatures(all)
    }

    /// Removes idle AlarmKit alarms that no alarm, follow-up or test ring owns (left behind by
    /// earlier versions), so each alarm rings once, under its own id.
    private func cancelOrphans() {
        var known = Set(plans.map(\.id)).union(store.loadOwners().keys)
        known.formUnion(session?.followUpIDs ?? [])
        for id in ReschedulePolicy.orphans(scheduler.scheduledAlarms(), known: known) {
            log.notice("orphan alarm \(id, privacy: .public) cancelled")
            scheduler.cancel(id: id)
        }
    }

    /// A scheduling error that has since been resolved shouldn't stay on Home.
    private func clearErrorIfAllPresent() {
        guard lastError != nil, activePause == nil else { return }
        let present = Set(scheduler.scheduledAlarms().map(\.id))
        if plans.filter({ $0.isEnabled }).allSatisfy({ present.contains($0.id) }) { lastError = nil }
    }

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain) \(ns.code): \(error)"
    }

    /// "1.0.0 (2)" from the app bundle.
    public static var bundleVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
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
        lastRingingID = nil
        onEvent?(.stopped(attempt: s.reArmCount + 1))

        guard let plan = plan(id: s.planID) else {
            persist(s)
            return
        }
        var failSafeRings: Int?
        switch ReArmPolicy.decide(session: s, plan: plan, now: current) {
        case .done:
            break
        case .failSafe:
            s.failSafeTriggered = true
            failSafeRings = s.reArmCount + 1
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
                lastError = L10n.tr("Could not re-arm: \(error.localizedDescription)")
            }
        }
        persist(s)
        // After persisting, so listeners (the day log) read the finished session.
        if let failSafeRings { onEvent?(.failSafe(rings: failSafeRings)) }
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
            lastError = L10n.tr("Add an alarm first.")
            return
        }
        let id = UUID()
        do {
            try await scheduler.scheduleOneOff(id: id, at: now().addingTimeInterval(seconds),
                                               title: plan.alarmTitle, sound: override ?? plan.sound)
            setOwner(plan.id, of: id)
        } catch {
            lastError = L10n.tr("Could not schedule test alarm: \(error.localizedDescription)")
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
