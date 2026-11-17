import AlarmEngine
import Core
import Foundation
import Testing

/// Keeping AlarmKit in step with the alarm list. Regression for the device bug of 17 Nov 2026:
/// two passes on app open (launch refresh + foreground restore) both re-added the same alarm id,
/// AlarmKit refused the second ("duplicate ID") and Home showed "Could not schedule alarm".
@Suite @MainActor struct AlarmSchedulingTests {
    private let sound = FakeAlarmSound()

    private func make(_ plans: [AlarmPlan] = [AlarmPlan(isEnabled: true)], version: String = "1.0.0 (1)",
                      store: KeyValueStore? = nil) -> (AlarmCoordinator, FakeScheduler, KeyValueStore) {
        let store = store ?? KeyValueStore(defaults: UserDefaults(suiteName: "sched-\(UUID().uuidString)")!)
        store.savePlans(plans)
        let scheduler = FakeScheduler()
        scheduler.rejectDuplicates = true  // like AlarmKit
        let c = AlarmCoordinator(store: store, scheduler: scheduler, sound: sound, appVersion: version)
        c.retryDelay = .zero
        return (c, scheduler, store)
    }

    @Test func concurrentPassesOnAppOpenScheduleOnceWithoutError() async {
        let plan = AlarmPlan(isEnabled: true)
        let (c, scheduler, _) = make([plan])
        async let launch: Void = c.refreshAlarms()
        async let foreground: Void = c.restoreMissingAlarms()
        _ = await (launch, foreground)
        #expect(scheduler.scheduleCalls[plan.id] == 1, "the second pass sees the alarm the first one made")
        #expect(scheduler.mainPlans[plan.id] != nil)
        #expect(c.lastError == nil)
    }

    @Test func unchangedAlarmsAreKeptOnRefresh() async {
        let plan = AlarmPlan(hour: 7, minute: 15, isEnabled: true)
        let (c, scheduler, _) = make([plan])
        await c.refreshAlarms()
        await c.refreshAlarms()
        await c.restoreMissingAlarms()
        #expect(scheduler.scheduleCalls[plan.id] == 1)
        #expect(scheduler.cancelled.isEmpty)
    }

    @Test func changesAndAppUpdatesReschedule() async {
        var plan = AlarmPlan(hour: 7, minute: 15, isEnabled: true)
        let store = KeyValueStore(defaults: UserDefaults(suiteName: "sched-\(UUID().uuidString)")!)
        let (c, scheduler, _) = make([plan], store: store)
        await c.refreshAlarms()
        plan.minute = 30
        await c.save(plan)                       // edited → always re-registered
        #expect(scheduler.scheduleCalls[plan.id] == 2)
        #expect(scheduler.mainPlans[plan.id]?.minute == 30)
        // Same alarm, new app version: refreshed once (new layout / sound).
        let (updated, scheduler2, _) = make([plan], version: "1.0.0 (2)", store: store)
        await updated.refreshAlarms()
        #expect(scheduler2.scheduleCalls[plan.id] == 1)
    }

    @Test func errorButAlarmPresentCountsAsScheduled() async {
        let plan = AlarmPlan(isEnabled: true)
        let (c, scheduler, _) = make([plan])
        await c.refreshAlarms()
        // AlarmKit refuses (duplicate) but the alarm is there: no error shown.
        await c.save(plan)
        #expect(c.lastError == nil)
        #expect(scheduler.mainPlans[plan.id] != nil)
    }

    @Test func oneFailureIsRetried() async {
        let plan = AlarmPlan(isEnabled: true)
        let (c, scheduler, _) = make([plan])
        scheduler.failNext[plan.id] = 1
        await c.refreshAlarms()
        #expect(scheduler.mainPlans[plan.id] != nil)
        #expect(c.lastError == nil)
        #expect(scheduler.scheduleCalls[plan.id] == 2)
    }

    @Test func persistentFailureIsShownThenClearedWhenResolved() async {
        let plan = AlarmPlan(isEnabled: true)
        let (c, scheduler, _) = make([plan])
        scheduler.failNext[plan.id] = 2
        await c.refreshAlarms()
        #expect(c.lastError != nil)
        #expect(scheduler.mainPlans[plan.id] == nil)
        await c.restoreMissingAlarms()           // next foreground: scheduled now
        #expect(scheduler.mainPlans[plan.id] != nil)
        #expect(c.lastError == nil)
    }

    @Test func orphanAlarmsAreRemovedButRingingOnesKept() async {
        let plan = AlarmPlan(isEnabled: true)
        let (c, scheduler, _) = make([plan])
        let stale = scheduler.injectOrphan()      // e.g. an old alarm id from an earlier version
        let ringing = scheduler.injectOrphan()
        scheduler.alerting = [ringing]
        await c.refreshAlarms()
        #expect(scheduler.cancelled.contains(stale))
        #expect(!scheduler.cancelled.contains(ringing))
        #expect(!scheduler.cancelled.contains(plan.id))
    }

    @Test func policyDecisions() {
        typealias P = ReschedulePolicy
        #expect(P.decide(enabled: true, busy: false, present: true, signatureMatches: true, force: false) == .skip)
        #expect(P.decide(enabled: true, busy: false, present: false, signatureMatches: true, force: false) == .schedule)
        #expect(P.decide(enabled: true, busy: false, present: true, signatureMatches: false, force: false) == .schedule)
        #expect(P.decide(enabled: true, busy: true, present: false, signatureMatches: false, force: false) == .skip)
        #expect(P.decide(enabled: false, busy: false, present: false, signatureMatches: false, force: true) == .skip)
        #expect(P.decide(enabled: true, busy: false, present: true, signatureMatches: true, force: true) == .schedule)
        let plan = AlarmPlan(hour: 7, minute: 15)
        let weekly = P.signature(for: plan, pauseFirstRing: nil, paused: false, appVersion: "1")
        #expect(weekly != P.signature(for: plan, pauseFirstRing: nil, paused: true, appVersion: "1"))
        #expect(weekly != P.signature(for: plan, pauseFirstRing: nil, paused: false, appVersion: "2"))
        var later = plan; later.minute = 16
        #expect(weekly != P.signature(for: later, pauseFirstRing: nil, paused: false, appVersion: "1"))
    }
}
