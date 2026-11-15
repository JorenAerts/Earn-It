import AlarmEngine
import Coach
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
        #expect(seen.firstIndex(of: .building)! > seen.firstIndex(of: .sound)!, "alarm is built after it's configured")
    }

    @Test func accountSkippedWhenUnavailableOrSignedIn() {
        let noAccounts = OnboardingContext(accountsAvailable: false, isSignedIn: false, isPro: false)
        #expect(OnboardingFlow.next(after: .inviteFriend, noAccounts) == .building)
        let signedIn = OnboardingContext(accountsAvailable: true, isSignedIn: true, isPro: false)
        #expect(OnboardingFlow.next(after: .inviteFriend, signedIn) == .building)
    }

    @Test func paywallSkippedForPro() {
        let pro = OnboardingContext(accountsAvailable: true, isSignedIn: false, isPro: true)
        #expect(OnboardingFlow.next(after: .summary, pro) == nil, "onboarding ends")
        #expect(!OnboardingFlow.visibleSteps(pro).contains(.paywall))
    }

    @Test func inviteSkippedOnceUnlocked() {
        let unlocked = OnboardingContext(accountsAvailable: true, isSignedIn: false, isPro: false, bonusSoundUnlocked: true)
        #expect(OnboardingFlow.next(after: .sound, unlocked) == .account)
        #expect(OnboardingFlow.previous(before: .account, unlocked) == .sound)
    }

    @Test func backNavigation() {
        #expect(OnboardingFlow.previous(before: .welcome, full) == nil)
        #expect(OnboardingFlow.previous(before: .name, full) == .welcome)
        #expect(OnboardingFlow.previous(before: .building, full) == nil, "the alarm is being made")
        #expect(OnboardingFlow.previous(before: .summary, full) == nil)
        #expect(OnboardingFlow.previous(before: .paywall, full) == .summary, "never back into building")
        // Every step's next → previous round-trips (outside the finale).
        for step in OnboardingStep.allCases where ![.welcome, .building, .summary].contains(step) {
            if let prev = OnboardingFlow.previous(before: step, full), prev != .building {
                #expect(OnboardingFlow.next(after: prev, full) == step)
            }
        }
    }

    @Test func progressFraction() {
        #expect(OnboardingFlow.fraction(at: .welcome, full) == 0)
        #expect(OnboardingFlow.fraction(at: .paywall, full) == 1)
        #expect(OnboardingFlow.fraction(at: .mission, full) > OnboardingFlow.fraction(at: .goal, full))
    }

    @Test func oldStepNamesStillLoad() throws {
        for (old, new) in [("howItWorks", OnboardingStep.whyItWorks), ("goals", .struggles), ("firstAlarm", .mission),
                           ("permissions", .permissions), ("nonsense", .welcome)] {
            let decoded = try JSONDecoder().decode(OnboardingStep.self, from: Data("\"\(old)\"".utf8))
            #expect(decoded == new)
        }
    }
}

@Suite struct OnboardingAnswersTests {
    @Test func firstAlarmUsesAnswers() {
        var answers = OnboardingAnswers()
        answers.hour = 6
        answers.minute = 45
        answers.weekdays = [2, 4]
        answers.getUpTime = .overHour
        answers.missions = [MissionConfig(kind: .math, difficulty: .hard, target: 5)]
        answers.sound = .builtIn(.reveille)
        let plan = answers.firstAlarm()
        #expect(plan.hour == 6 && plan.minute == 45 && plan.weekdays == [2, 4] && plan.isEnabled)
        #expect(plan.missions.count == 1 && plan.missions[0].difficulty == .hard && plan.missions[0].target == 5)
        #expect(plan.sound == .builtIn(.reveille))
        #expect(plan.reArmMinutes == 1, "long lingerers get short re-rings")
        #expect(plan.isReady)
    }

    @Test func suggestionWhenNothingChosen() {
        var answers = OnboardingAnswers()
        #expect(answers.suggestedMissions == [.math])
        answers.struggles = [.stayInBed]
        #expect(answers.suggestedMission == .shake)
        #expect(answers.firstAlarm().missions.map(\.kind) == [.shake])
    }

    @Test func unregisteredScanFallsBackToMath() {
        var answers = OnboardingAnswers()
        answers.missions = [MissionConfig(kind: .qr)]  // no code registered
        #expect(answers.firstAlarm().missions.map(\.kind) == [.math])
    }

    @Test func replayUpdatesTheSameAlarm() {
        var answers = OnboardingAnswers()
        let id = UUID()
        answers.createdPlanID = id
        #expect(answers.firstAlarm().id == id)
    }

    @Test func oldProgressStillDecodes() throws {
        // Saved by the previous onboarding: only hour, minute, weekdays, struggles (incl. a removed case).
        let json = #"{"hour":6,"minute":15,"weekdays":[2,3],"struggles":["snooze","fallBackAsleep","gone"]}"#
        let answers = try JSONDecoder().decode(OnboardingAnswers.self, from: Data(json.utf8))
        #expect(answers.hour == 6 && answers.minute == 15 && answers.weekdays == [2, 3])
        #expect(answers.struggles == [.snooze, .fallBackAsleep])
        #expect(answers.name.isEmpty && answers.sound == .classic && answers.missions == nil)
        let progress = try JSONDecoder().decode(OnboardingProgress.self,
                                                from: Data(#"{"step":"goals","answers":{"hour":8},"completed":false}"#.utf8))
        #expect(progress.step == .struggles && progress.answers.hour == 8)
    }
}

@Suite struct OnboardingPersonalizationTests {
    @Test func toneFromReaction() {
        #expect(OnboardingPersonalization.suggestedTone(.imUp) == .gentle)
        #expect(OnboardingPersonalization.suggestedTone(.fiveMore) == .toughLove)
        #expect(OnboardingPersonalization.suggestedTone(.whySoEarly) == .savage)
        #expect(OnboardingPersonalization.suggestedTone(nil) == .toughLove)
    }

    @Test func reRingFromGetUpTime() {
        #expect(OnboardingPersonalization.reArmMinutes(.under10) == 3)
        #expect(OnboardingPersonalization.reArmMinutes(.thirtyTo60) == 2)
        #expect(OnboardingPersonalization.reArmMinutes(.overHour) == 1)
    }

    @Test func hoursBack() {
        let weekdays: Set<Int> = Set(2...6)
        #expect(OnboardingPersonalization.hoursBackPerWeek(.tenTo30, weekdays: weekdays) == 1.5, "20 × 5 = 100 min")
        #expect(OnboardingPersonalization.hoursBackPerWeek(.overHour, weekdays: Set(1...7)) == 8.5, "75 × 7 = 525 min")
        #expect(OnboardingPersonalization.hoursBackPerWeek(.under10, weekdays: weekdays) == nil, "25 min isn't worth it")
        #expect(OnboardingPersonalization.hoursBackPerWeek(nil, weekdays: weekdays) == nil)
        #expect(OnboardingPersonalization.hoursBackText(1.5) == "That's about 1½ hours back every week.")
        #expect(OnboardingPersonalization.hoursBackText(1) == "That's about 1 hour back every week.")
    }

    @Test func coachUsesTheName() {
        var answers = OnboardingAnswers()
        answers.reaction = .whySoEarly
        #expect(OnboardingPersonalization.coachReaction(to: .alarmReaction, answers: answers)?.contains("recruit") == true)
        answers.name = "Joren"
        #expect(OnboardingPersonalization.coachReaction(to: .alarmReaction, answers: answers)?.contains("Joren") == true)
        #expect(OnboardingPersonalization.coachReaction(to: .wakeTime, answers: answers)?.contains("07:00") == true)
        #expect(OnboardingPersonalization.goalLine(.quietTime) == "Quiet time that's all yours")
    }

    @Test func socialProofOnlyWhenReal() {
        #expect(SocialProof.decode(nil) == .empty)
        let bundled = SocialProof.decode(try? Data(contentsOf: URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Config/SocialProof.json")))
        #expect(bundled.stats.isEmpty && bundled.reviews.isEmpty, "ship empty until there are real numbers")
        let json = #"{"stats":[{"value":"1K+","label":"mornings"}],"reviews":[{"name":"A","text":"ok","stars":9}]}"#
        let proof = SocialProof.decode(Data(json.utf8))
        #expect(proof.stats.count == 1 && proof.reviews.isEmpty, "invalid star counts dropped")
    }
}

@Suite struct CoachNamePlaceholderTests {
    @Test func nameFallsBackToSoldier() {
        let lines = CoachLines(table: ["idle": ["toughLove": ["Lights out, {name}."]]])
        #expect(lines.line(for: .idle, intensity: .toughLove, day: .now) == "Lights out, soldier.")
        #expect(lines.line(for: .idle, intensity: .toughLove, day: .now, values: ["name": "Joren"]) == "Lights out, Joren.")
        #expect(lines.line(for: .idle, intensity: .toughLove, day: .now, values: ["name": " "]) == "Lights out, soldier.")
    }
}

@Suite struct BonusSoundTests {
    @Test func inviteSoundUnlocksForFree() {
        let free = FeatureGate(isPro: false)
        #expect(free.isLocked(BonusUnlocks.inviteSound))
        let bonus = FeatureGate(isPro: false, bonusSounds: [BonusUnlocks.inviteSound])
        #expect(!bonus.isLocked(BonusUnlocks.inviteSound))
        #expect(bonus.isLocked(AlarmSound.siren), "only the bonus sound")
        let plan = AlarmPlan(sound: .builtIn(BonusUnlocks.inviteSound), isEnabled: true)
        #expect(DowngradePolicy.apply(to: [plan], gate: bonus).changes.isEmpty, "kept after Pro ends")
        #expect(!DowngradePolicy.apply(to: [plan], gate: free).changes.isEmpty)
    }

    @Test func unlockPersists() {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        #expect(BonusUnlocks.sounds(d).isEmpty)
        BonusUnlocks.unlock(d)
        #expect(BonusUnlocks.sounds(d) == [BonusUnlocks.inviteSound])
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
        progress.answers.name = "Sam"
        progress.answers.goal = .workout
        store.save(progress)
        let resumed = OnboardingStore(defaults: d).load()
        #expect(resumed.step == .permissions && resumed.answers.hour == 5)
        #expect(resumed.answers.name == "Sam" && resumed.answers.goal == .workout)
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
