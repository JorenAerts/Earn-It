import AlarmEngine
import Core
import Features
import Purchases
import Foundation
import Testing

@Suite struct OnboardingFlowTests {
    let full = OnboardingContext(accountsAvailable: true, isSignedIn: false, isPro: false)

    @Test func walksAllStepsInOrder() {
        var step: OnboardingStep? = .welcome
        var seen: [OnboardingStep] = []
        while let current = step {
            seen.append(current)
            step = OnboardingFlow.next(after: current, full)
        }
        #expect(seen == OnboardingStep.allCases)
    }

    @Test func accountSkippedWhenUnavailableOrSignedIn() {
        let noAccounts = OnboardingContext(accountsAvailable: false, isSignedIn: false, isPro: false)
        #expect(OnboardingFlow.next(after: .goals, noAccounts) == .permissions)
        let signedIn = OnboardingContext(accountsAvailable: true, isSignedIn: true, isPro: false)
        #expect(OnboardingFlow.next(after: .goals, signedIn) == .permissions)
        #expect(OnboardingFlow.previous(before: .permissions, signedIn) == .goals)
    }

    @Test func paywallSkippedForPro() {
        let pro = OnboardingContext(accountsAvailable: true, isSignedIn: false, isPro: true)
        #expect(OnboardingFlow.next(after: .firstAlarm, pro) == nil, "onboarding ends")
        #expect(!OnboardingFlow.visibleSteps(pro).contains(.paywall))
    }

    @Test func noBackFromWelcome() {
        #expect(OnboardingFlow.previous(before: .welcome, full) == nil)
    }
}

@Suite struct OnboardingAnswersTests {
    @Test func firstAlarmUsesAnswers() {
        var answers = OnboardingAnswers()
        answers.hour = 6
        answers.minute = 45
        answers.weekdays = [2, 4]
        answers.struggles = [.snooze, .fallBackAsleep]
        let plan = answers.firstAlarm()
        #expect(plan.hour == 6 && plan.minute == 45 && plan.weekdays == [2, 4] && plan.isEnabled)
        #expect(plan.missions.map(\.kind) == [.math, .shake])
        #expect(plan.isReady)
    }

    @Test func noStrugglesMeansMath() {
        #expect(OnboardingAnswers().suggestedMissions == [.math])
    }
}

@Suite struct OnboardingStoreTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "test-\(UUID().uuidString)")! }

    @Test func progressResumes() {
        let d = defaults()
        let store = OnboardingStore(defaults: d)
        var progress = store.load()
        #expect(progress.step == .welcome && !progress.completed)
        progress.step = .permissions
        progress.answers.hour = 5
        store.save(progress)
        let resumed = OnboardingStore(defaults: d).load()
        #expect(resumed.step == .permissions && resumed.answers.hour == 5)
    }

    @Test func existingUsersSkipOnboarding() {
        let d = defaults()
        d.set(true, forKey: "earnit.onboarded")
        #expect(OnboardingStore(defaults: d).load().completed)
    }

    @Test func resetReplaysButKeepsAnswers() {
        let d = defaults()
        let store = OnboardingStore(defaults: d)
        var progress = store.load()
        progress.completed = true
        progress.answers.hour = 9
        store.save(progress)
        store.reset()
        let again = store.load()
        #expect(!again.completed && again.step == .welcome && again.answers.hour == 9)
    }
}

@Suite @MainActor struct TierEnforcementTests {
    private func coordinator(with plans: [AlarmPlan]) async -> (AlarmCoordinator, FakeScheduler) {
        let store = KeyValueStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let scheduler = FakeScheduler()
        let c = AlarmCoordinator(store: store, scheduler: scheduler, sound: FakeAlarmSound())
        for plan in plans { await c.save(plan) }
        return (c, scheduler)
    }

    @Test func freeTierSwitchesExtraAlarmsOffAndReschedules() async {
        let first = AlarmPlan(sound: .siren, hour: 6, missions: [MissionConfig(kind: .shake)], isEnabled: true)
        let second = AlarmPlan(hour: 8, isEnabled: true)
        let (c, scheduler) = await coordinator(with: [first, second])
        let changes = await TierEnforcement.enforce(on: c, gate: FeatureGate(isPro: false))
        #expect(changes.count == 3)
        #expect(c.plans[0].sound == .classic && c.plans[0].missions.map(\.kind) == [.math])
        #expect(!c.plans[1].isEnabled)
        #expect(scheduler.mainPlans[second.id] == nil, "switched-off alarm is unscheduled")
        #expect(scheduler.mainPlans[first.id]?.sound == .classic, "kept alarm rescheduled with new sound")
        let again = await TierEnforcement.enforce(on: c, gate: FeatureGate(isPro: false))
        #expect(again.isEmpty, "idempotent")
    }

    @Test func proIsLeftAlone() async {
        let (c, _) = await coordinator(with: [AlarmPlan(sound: .siren, isEnabled: true), AlarmPlan(isEnabled: true)])
        let changes = await TierEnforcement.enforce(on: c, gate: FeatureGate(isPro: true))
        #expect(changes.isEmpty)
        let allEnabled = c.plans.allSatisfy { $0.isEnabled }
        #expect(allEnabled)
    }

    @Test func neverDuringARingingMission() async {
        let (c, _) = await coordinator(with: [AlarmPlan(isEnabled: true), AlarmPlan(isEnabled: true)])
        await c.alarmEnded(id: c.plans[0].id)   // mission due
        let changes = await TierEnforcement.enforce(on: c, gate: FeatureGate(isPro: false))
        #expect(changes.isEmpty)
    }

    @Test func noticesPersistAndDedupe() {
        let notices = DowngradeNotices(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        notices.add(["a", "b"])
        notices.add(["b", "c"])
        #expect(notices.messages == ["a", "b", "c"])
        notices.clear()
        #expect(notices.messages.isEmpty)
    }

    @Test func enableGate() {
        let free = FeatureGate(isPro: false)
        #expect(free.canEnableAlarm(enabledCount: 0) && !free.canEnableAlarm(enabledCount: 1))
        #expect(FeatureGate(isPro: true).canEnableAlarm(enabledCount: 9))
    }
}
