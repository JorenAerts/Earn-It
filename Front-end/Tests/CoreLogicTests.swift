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
        store.savePlans([plan])
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
        let (c, _) = makeCoordinator()
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
        var plan = c.plans[0]
        plan.isEnabled = true
        await c.save(plan)
        await c.alarmEnded(id: plan.id)
        #expect(fake.stopped.contains(plan.id))
        #expect(fake.mainPlans[plan.id] != nil)
    }

    @Test func missionSuccessSilencesEverythingButKeepsMain() async {
        let (c, fake) = makeCoordinator()
        var plan = c.plans[0]
        plan.isEnabled = true
        await c.save(plan)
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
        try await fake.scheduleOneOff(id: ringing, at: .now, title: "t", sound: .classic)
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
        try await fake.scheduleOneOff(id: ringing, at: .now, title: "t", sound: .classic)
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
        try await fake.scheduleOneOff(id: ringing, at: .now, title: "t", sound: .classic)
        fake.alerting.insert(ringing)
        c.reload()
        #expect(c.needsMission)
    }

    @Test func ringCycleUsesTheRingingAlarmsSettings() async {
        let (c, fake) = makeCoordinator()
        let gym = AlarmPlan(label: "Gym", sound: .siren, hour: 6, missions: [MissionConfig(kind: .qr, payload: "gym")],
                            reArmMinutes: 5, isEnabled: true)
        await c.save(gym)
        await c.alarmEnded(id: gym.id)                       // the gym alarm rang, X pressed
        #expect(c.session?.planID == gym.id)
        #expect(c.activePlan?.missions.first?.kind == .qr)
        #expect(Array(fake.followUpDurations.values) == [300], "gym alarm re-rings after its own 5 min")
        #expect(fake.sounds[c.session!.followUpIDs[0]] == .siren)
        #expect(sound.lastSound == .siren, "in-app sound matches the ringing alarm")
    }

    @Test func followUpRingKeepsOwnerAfterSessionLoss() async {
        let (c, _) = makeCoordinator()
        let second = AlarmPlan(label: "Second", sound: .chime, isEnabled: true)
        await c.save(second)
        await c.debugRing(inSeconds: 10, planID: second.id)
        let testRing = c.debugScheduledAlarms().map(\.id).first { c.plan(id: $0) == nil }!
        await c.alarmEnded(id: testRing)
        #expect(c.session?.planID == second.id)
    }

    @Test func deleteRemovesAlarmAndSchedule() async {
        let (c, fake) = makeCoordinator()
        let extra = AlarmPlan(isEnabled: true)
        await c.save(extra)
        #expect(c.plans.count == 2 && fake.mainPlans[extra.id] != nil)
        c.delete(id: extra.id)
        #expect(c.plans.count == 1 && fake.mainPlans[extra.id] == nil)
    }

    @Test func nextAlarmIsSoonestEnabled() async {
        let (c, _) = makeCoordinator()
        await c.save(AlarmPlan(hour: 23, minute: 59, isEnabled: true))
        let early = AlarmPlan(hour: 0, minute: 1, isEnabled: true)
        await c.save(early)
        await c.save(AlarmPlan(hour: 0, minute: 0, isEnabled: false))
        let next = c.nextAlarm!
        let laterCandidates = c.plans.filter(\.isEnabled).compactMap { c.nextFireDate(for: $0) }
        #expect(next.date == laterCandidates.min())
    }

    @Test func applyEnabledPlanSchedulesMain() async {
        let (c, fake) = makeCoordinator()
        var plan = c.plans[0]
        plan.isEnabled = true
        await c.save(plan)
        #expect(fake.mainPlans[plan.id] != nil)
        plan.isEnabled = false
        await c.save(plan)
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

    @Test func bestStreakFindsLongestRun() {
        let days = [date(2026, 11, 1, 7), date(2026, 11, 2, 7), date(2026, 11, 3, 7),
                    date(2026, 11, 5, 7), date(2026, 11, 6, 7), date(2026, 11, 6, 9)]
        #expect(StreakCalculator.bestStreak(completedDays: days, calendar: calendar) == 3)
        #expect(StreakCalculator.bestStreak(completedDays: [], calendar: calendar) == 0)
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

    @Test func titlesForNewMissions() {
        let plan = AlarmPlan(missions: [MissionConfig(kind: .qr, payload: "x"), MissionConfig(kind: .shake)])
        #expect(plan.alarmTitle == "Earn It - Scan Code + Shake It")
    }

    @Test func oldStoredMissionWithoutPayloadStillDecodes() throws {
        let json = #"{"id":"D4B30B83-E6F4-4241-ADA8-6C619FEA3C91","kind":"math","difficulty":"easy","target":1}"#
        let config = try JSONDecoder().decode(MissionConfig.self, from: Data(json.utf8))
        #expect(config.kind == .math && config.payload == nil)
    }
}

@Suite struct MultiAlarmStorageTests {
    @Test func legacySinglePlanMigratesToList() {
        let store = KeyValueStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let legacy = AlarmPlan(hour: 6, minute: 30, isEnabled: true)
        store.saveLegacyPlan(legacy)
        #expect(store.loadPlans() == [legacy])
        #expect(store.loadPlans() == [legacy], "migration is persisted")
    }

    @Test func removedMissionKindIsDroppedNotFatal() throws {
        let json = #"{"id":"FED23467-0B83-4401-8A74-82EB06908396","hour":7,"minute":0,"weekdays":[],"reArmMinutes":2,"maxReArms":15,"isEnabled":true,"missions":[{"id":"D4B30B83-E6F4-4241-ADA8-6C619FEA3C91","kind":"steps","difficulty":"medium","target":50},{"id":"D4B30B83-E6F4-4241-ADA8-6C619FEA3C92","kind":"math","difficulty":"easy","target":2}]}"#
        let plan = try JSONDecoder().decode(AlarmPlan.self, from: Data(json.utf8))
        #expect(plan.missions.map(\.kind) == [.math])
    }

    @Test func alarmLeftWithoutMissionsFallsBackToMath() throws {
        let json = #"{"id":"FED23467-0B83-4401-8A74-82EB06908396","hour":7,"minute":0,"weekdays":[],"reArmMinutes":2,"maxReArms":15,"isEnabled":true,"missions":[{"id":"D4B30B83-E6F4-4241-ADA8-6C619FEA3C91","kind":"steps","difficulty":"medium","target":50}]}"#
        let plan = try JSONDecoder().decode(AlarmPlan.self, from: Data(json.utf8))
        #expect(plan.missions.map(\.kind) == [.math])
    }

    @Test func oldPlanJSONWithoutLabelOrSoundDecodes() throws {
        let json = #"{"id":"FED23467-0B83-4401-8A74-82EB06908396","hour":11,"minute":53,"weekdays":[1,2],"missions":[],"reArmMinutes":2,"maxReArms":15,"isEnabled":true}"#
        let plan = try JSONDecoder().decode(AlarmPlan.self, from: Data(json.utf8))
        #expect(plan.sound == .classic && plan.label.isEmpty && plan.hour == 11)
        #expect(plan.missions.map(\.kind) == [.math])
    }

    @Test func repeatText() {
        #expect(AlarmPlan(weekdays: Set(1...7)).repeatText == "Every day")
        #expect(AlarmPlan(weekdays: Set(2...6)).repeatText == "Weekdays")
        #expect(AlarmPlan(weekdays: [1, 7]).repeatText == "Weekends")
        #expect(AlarmPlan(weekdays: []).repeatText == "Once")
    }

    @Test func everySoundHasAFile() {
        for sound in AlarmSound.allCases {
            #expect(Bundle.main.url(forResource: sound.resourceName, withExtension: "caf") != nil, "\(sound)")
        }
    }
}
