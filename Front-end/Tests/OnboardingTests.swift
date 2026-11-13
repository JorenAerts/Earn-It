import Core
import Features
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
