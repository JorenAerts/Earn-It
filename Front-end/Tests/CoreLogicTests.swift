import AlarmEngine
import Core
import Foundation
import Missions
import Testing

private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Brussels")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

@Suite struct AlarmPlanTests {
    @Test func nextFireLaterToday() {
        let plan = AlarmPlan(hour: 7, minute: 30)
        #expect(plan.nextFireDate(after: date(2026, 11, 13, 6, 0), calendar: calendar) == date(2026, 11, 13, 7, 30))
    }

    @Test func nextFireTomorrowWhenPassed() {
        let plan = AlarmPlan(hour: 7, minute: 30)
        #expect(plan.nextFireDate(after: date(2026, 11, 13, 8, 0), calendar: calendar) == date(2026, 11, 14, 7, 30))
    }

    @Test func nextFireRespectsWeekdays() {
        // 2026-11-13 is a Friday; weekdays only Monday (2).
        let plan = AlarmPlan(hour: 7, minute: 0, weekdays: [2])
        #expect(plan.nextFireDate(after: date(2026, 11, 13, 8, 0), calendar: calendar) == date(2026, 11, 16, 7, 0))
    }
}

@Suite struct AlarmTitleTests {
    @Test func singleMission() {
        #expect(AlarmPlan(missions: [MissionConfig(kind: .math)]).alarmTitle == "Earn It - Math Problem")
    }

    @Test func combinedMissions() {
        let plan = AlarmPlan(missions: [MissionConfig(kind: .math), MissionConfig(kind: .shake)])
        #expect(plan.alarmTitle == "Earn It - Math Problem + Shake It")
    }
}

@Suite struct ReArmPolicyTests {
    let plan = AlarmPlan(reArmMinutes: 2, maxReArms: 3)
    let now = date(2026, 11, 13, 7, 0)

    @Test func reArmsWhenMissionOutstanding() {
        let s = SessionState(day: date(2026, 11, 13), reArmCount: 0)
        #expect(ReArmPolicy.decide(session: s, plan: plan, now: now) == .reArm(at: now.addingTimeInterval(120), attempt: 1))
    }

    @Test func doneAfterMission() {
        let s = SessionState(day: date(2026, 11, 13), missionCompletedAt: now)
        #expect(ReArmPolicy.decide(session: s, plan: plan, now: now) == .done)
    }

    @Test func failSafeAtLimit() {
        let s = SessionState(day: date(2026, 11, 13), reArmCount: 3)
        #expect(ReArmPolicy.decide(session: s, plan: plan, now: now) == .failSafe)
    }

    @Test func newRingAfterFinishedCycleStartsFresh() {
        let done = SessionState(day: date(2026, 11, 13), missionCompletedAt: date(2026, 11, 13, 6, 50), reArmCount: 1)
        #expect(ReArmPolicy.currentSession(done, now: now, newRing: true, calendar: calendar).missionDone == false)
        #expect(ReArmPolicy.currentSession(done, now: now, newRing: false, calendar: calendar) == done)
        let failSafe = SessionState(day: date(2026, 11, 13), reArmCount: 3, failSafeTriggered: true)
        #expect(ReArmPolicy.currentSession(failSafe, now: now, newRing: true, calendar: calendar).failSafeTriggered == false)
    }

    @Test func newRingDuringActiveCycleKeepsSession() {
        let active = SessionState(day: date(2026, 11, 13), firstEndedAt: date(2026, 11, 13, 6, 55), reArmCount: 2)
        #expect(ReArmPolicy.currentSession(active, now: now, newRing: true, calendar: calendar) == active)
    }

    @Test func newDayStartsFreshSession() {
        let old = SessionState(day: date(2026, 11, 12), missionCompletedAt: date(2026, 11, 12, 7, 5), reArmCount: 2)
        let s = ReArmPolicy.currentSession(old, now: now, calendar: calendar)
        #expect(s.reArmCount == 0 && !s.missionDone)
    }
}

@Suite @MainActor struct AlarmCoordinatorTests {
    private let sound = FakeAlarmSound()

    private func makeCoordinator(plan: AlarmPlan = AlarmPlan(reArmMinutes: 2, maxReArms: 2)) -> (AlarmCoordinator, FakeScheduler) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = KeyValueStore(defaults: defaults)
        store.savePlan(plan)
        let scheduler = FakeScheduler()
        return (AlarmCoordinator(store: store, scheduler: scheduler, sound: sound), scheduler)
    }

    @Test func soundPlaysFromXUntilMissionDone() async {
        let (c, _) = makeCoordinator()
        #expect(!sound.isPlaying)
        await c.alarmEnded(id: UUID())         // X pressed
        #expect(sound.isPlaying, "alarm continues in-app immediately")
        c.reload()                              // app foregrounded / relaunched
        #expect(sound.isPlaying)
        c.missionSucceeded()
        #expect(!sound.isPlaying)
    }

    @Test func soundStopsAtFailSafe() async {
        let (c, _) = makeCoordinator()
        for _ in 0..<3 { await c.alarmEnded(id: nil) }
        #expect(c.session?.failSafeTriggered == true)
        #expect(!sound.isPlaying)
    }

    @Test func stopWithoutMissionSchedulesFollowUp() async {
        let (c, fake) = makeCoordinator()
        await c.alarmEnded(id: nil)
        #expect(fake.oneOffs.count == 1)
        #expect(Array(fake.followUpDurations.values) == [120], "countdown follow-up after reArmMinutes")
        #expect(c.session?.reArmCount == 1)
        #expect(c.needsMission)
    }

    @Test func missionSuccessCancelsFollowUps() async {
        let (c, fake) = makeCoordinator()
        await c.alarmEnded(id: nil)
        let followUp = c.session!.followUpIDs[0]
        c.missionSucceeded()
        #expect(fake.cancelled.contains(followUp))
        #expect(fake.oneOffs.isEmpty)
        #expect(!c.needsMission)
        #expect(c.session?.missionDone == true)
    }

    @Test func failSafeStopsLoop() async {
        let (c, fake) = makeCoordinator()
        for _ in 0..<3 { await c.alarmEnded(id: nil) }
        #expect(c.session?.reArmCount == 2)
        #expect(c.session?.failSafeTriggered == true)
        #expect(!c.needsMission)
    }

    @Test func endingAlarmSilencesIt() async {
        let (c, fake) = makeCoordinator()
        let ringing = UUID()
        await c.alarmEnded(id: ringing)
        #expect(fake.stopped.contains(ringing))
        #expect(fake.cancelled.contains(ringing))
    }

    @Test func endingMainAlarmKeepsItScheduled() async {
        let (c, fake) = makeCoordinator()
        var plan = c.plan
        plan.isEnabled = true
        await c.apply(plan)
        await c.alarmEnded(id: plan.id)
        #expect(fake.stopped.contains(plan.id))
        #expect(fake.mainPlans[plan.id] != nil)
    }

    @Test func missionSuccessSilencesEverythingButKeepsMain() async {
        let (c, fake) = makeCoordinator()
        var plan = c.plan
        plan.isEnabled = true
        await c.apply(plan)
        await c.alarmEnded(id: plan.id)          // main rang, follow-up scheduled
        let orphan = fake.injectOrphan()          // untracked leftover alarm
        c.missionSucceeded()
        #expect(fake.oneOffs.isEmpty)
        #expect(fake.stopped.contains(orphan))
        #expect(fake.stopped.contains(plan.id))
        #expect(fake.mainPlans[plan.id] != nil, "weekly alarm survives for tomorrow")
    }

    @Test func failSafeSilencesEverything() async {
        let (c, fake) = makeCoordinator()
        for _ in 0..<2 { await c.alarmEnded(id: nil) }
        let orphan = fake.injectOrphan()
        await c.alarmEnded(id: nil)
        #expect(c.session?.failSafeTriggered == true)
        #expect(fake.oneOffs.isEmpty)
        #expect(fake.cancelled.contains(orphan))
    }

    @Test func startMissionKeepsAlarmRinging() async throws {
        let (c, fake) = makeCoordinator()
        let ringing = UUID()
        try await fake.scheduleOneOff(id: ringing, at: .now, title: "t")
        fake.alerting.insert(ringing)
        c.missionStarted(id: ringing)
        #expect(!fake.stopped.contains(ringing), "alarm must keep ringing during the mission")
        #expect(fake.oneOffs.count == 1, "no extra follow-up while still ringing")
        #expect(c.needsMission)
        c.missionSucceeded()
        #expect(fake.stopped.contains(ringing))
        #expect(fake.oneOffs.isEmpty)
    }

    @Test func openingAppWhileRingingShowsMission() async throws {
        let (c, fake) = makeCoordinator()
        let ringing = UUID()
        try await fake.scheduleOneOff(id: ringing, at: .now, title: "t")
        fake.alerting.insert(ringing)
        #expect(!c.needsMission)
        c.reload()
        #expect(c.needsMission)
    }

    @Test func reloadDuringReRingCountdownShowsMission() async {
        let (c, _) = makeCoordinator()
        await c.alarmEnded(id: UUID())      // X pressed: countdown follow-up running
        c.debugResetSessionKeepingAlarms()  // simulate fresh process with lost session state
        c.reload()
        #expect(c.needsMission)
    }

    @Test func secondRingSameDayAfterMissionOpensMissionAgain() async {
        let (c, fake) = makeCoordinator()
        await c.alarmEnded(id: UUID())
        c.missionSucceeded()
        #expect(!c.needsMission)
        await c.alarmEnded(id: UUID())          // e.g. debug alarm or 2nd alarm later today
        #expect(c.needsMission)
        #expect(c.session?.reArmCount == 1)
        #expect(fake.followUpDurations.count == 1)
    }

    @Test func ringingAfterFailSafeOpensMission() async throws {
        let (c, fake) = makeCoordinator()
        for _ in 0..<3 { await c.alarmEnded(id: nil) }
        #expect(c.session?.failSafeTriggered == true)
        let ringing = UUID()
        try await fake.scheduleOneOff(id: ringing, at: .now, title: "t")
        fake.alerting.insert(ringing)
        c.reload()
        #expect(c.needsMission)
    }

    @Test func applyEnabledPlanSchedulesMain() async {
        let (c, fake) = makeCoordinator()
        var plan = c.plan
        plan.isEnabled = true
        await c.apply(plan)
        #expect(fake.mainPlans[plan.id] != nil)
        plan.isEnabled = false
        await c.apply(plan)
        #expect(fake.mainPlans.isEmpty)
    }
}

@Suite struct StreakTests {
    @Test func countsConsecutiveDays() {
        let days = [date(2026, 11, 11, 7), date(2026, 11, 12, 7), date(2026, 11, 13, 7)]
        #expect(StreakCalculator.currentStreak(completedDays: days, today: date(2026, 11, 13, 9), calendar: calendar) == 3)
    }

    @Test func todayPendingKeepsYesterdayStreak() {
        let days = [date(2026, 11, 11, 7), date(2026, 11, 12, 7)]
        #expect(StreakCalculator.currentStreak(completedDays: days, today: date(2026, 11, 13, 6), calendar: calendar) == 2)
    }

    @Test func gapBreaksStreak() {
        let days = [date(2026, 11, 10, 7), date(2026, 11, 12, 7)]
        #expect(StreakCalculator.currentStreak(completedDays: days, today: date(2026, 11, 13, 9), calendar: calendar) == 1)
    }
}

@Suite struct MissionLogicTests {
    @Test func mathNeedsCorrectInARow() {
        var s = MathSession(target: 2, difficulty: .medium, rng: SplitMix64(seed: 42))
        s.submit(s.problem.answer)
        #expect(s.correctInRow == 1)
        s.submit(s.problem.answer + 1)
        #expect(s.correctInRow == 0)
        s.submit(s.problem.answer)
        s.submit(s.problem.answer)
        #expect(s.isComplete)
    }

    @Test func shakeDetectorDebounces() {
        var d = ShakeDetector(threshold: 2.0, minInterval: 0.25)
        #expect(d.process(x: 0, y: 0, z: 1, timestamp: 0) == false)   // resting, 1g
        #expect(d.process(x: 2.5, y: 0, z: 0, timestamp: 0.1) == true)
        #expect(d.process(x: 2.5, y: 0, z: 0, timestamp: 0.2) == false) // too soon
        #expect(d.process(x: 0, y: 2.5, z: 0, timestamp: 0.5) == true)
        #expect(d.count == 2)
    }
}

@Suite struct NewMissionTests {
    @Test func qrMatchesTrimmedExactPayload() {
        #expect(CodeMatcher.matches(scanned: "earnit:ABC\n", expected: "earnit:ABC"))
        #expect(!CodeMatcher.matches(scanned: "earnit:ABD", expected: "earnit:ABC"))
        #expect(!CodeMatcher.matches(scanned: "", expected: ""))
        #expect(!CodeMatcher.matches(scanned: "x", expected: nil))
    }

    @Test func generatedPayloadsAreUnique() {
        let a = CodeMatcher.newPayload(), b = CodeMatcher.newPayload()
        #expect(a != b && a.hasPrefix(CodeMatcher.generatedPrefix))
    }

    @Test func qrMissionNeedsRegisteredCode() {
        var qr = MissionConfig(kind: .qr)
        #expect(!qr.isReady)
        #expect(!AlarmPlan(missions: [qr]).isReady)
        qr.payload = "earnit:X"
        #expect(qr.isReady)
        #expect(AlarmPlan(missions: [MissionConfig(kind: .math), qr]).isReady)
    }

    @Test func stepProgressNeverGoesBackwards() {
        var p = StepProgress(target: 50)
        p.update(cumulativeSteps: 30)
        p.update(cumulativeSteps: 20)
        #expect(p.steps == 30 && p.remaining == 20 && !p.isComplete)
        p.update(cumulativeSteps: 55)
        #expect(p.isComplete && p.fraction == 1)
    }

    @Test func titlesForNewMissions() {
        let plan = AlarmPlan(missions: [MissionConfig(kind: .qr, payload: "x"), MissionConfig(kind: .steps)])
        #expect(plan.alarmTitle == "Earn It - Scan Code + Walk Steps")
    }

    @Test func oldStoredMissionWithoutPayloadStillDecodes() throws {
        let json = #"{"id":"D4B30B83-E6F4-4241-ADA8-6C619FEA3C91","kind":"math","difficulty":"easy","target":1}"#
        let config = try JSONDecoder().decode(MissionConfig.self, from: Data(json.utf8))
        #expect(config.kind == .math && config.payload == nil)
    }
}
