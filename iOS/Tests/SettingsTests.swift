import Account
import AlarmEngine
import Coach
import Core
import Features
import Foundation
import Permissions
import Testing

private let brussels: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Brussels")!
    return c
}()

private func day(_ d: Int, _ h: Int = 0, _ m: Int = 0, month: Int = 11, calendar: Calendar = brussels) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: h, minute: m))!
}

// MARK: - Developer access

struct DeveloperAccessTests {
    let me = UUID()

    @Test func debugBuildsAlwaysUnlock() {
        #expect(DeveloperAccess.canUnlock(isDebugBuild: true, userID: nil, allowlist: []))
    }

    @Test func releaseBuildsOnlyForAllowlistedAccounts() {
        #expect(DeveloperAccess.canUnlock(isDebugBuild: false, userID: nil, allowlist: [me]) == false)
        #expect(DeveloperAccess.canUnlock(isDebugBuild: false, userID: UUID(), allowlist: [me]) == false)
        #expect(DeveloperAccess.canUnlock(isDebugBuild: false, userID: me, allowlist: [me]))
    }

    @Test func allowlistParsingIgnoresBadEntries() {
        let json = #"{"developerUserIDs": ["\#(me.uuidString)", "not-a-uuid"]}"#
        #expect(DeveloperAccess.allowlist(from: Data(json.utf8)) == [me])
        #expect(DeveloperAccess.allowlist(from: Data("{}".utf8)).isEmpty)
        #expect(DeveloperAccess.allowlist(from: nil).isEmpty)
    }

    @Test func sevenQuickTapsUnlockWithHints() {
        var taps = TapUnlock()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let results = (0..<7).map { taps.tap(at: t0.addingTimeInterval(Double($0) * 0.5)) }
        #expect(results.prefix(3).allSatisfy { $0 == .nothing })
        #expect(results[3] == .hint(remaining: 3))
        #expect(results[5] == .hint(remaining: 1))
        #expect(results[6] == .unlocked)
    }

    @Test func slowTapsStartOver() {
        var taps = TapUnlock(window: 3)
        let t0 = Date(timeIntervalSince1970: 1_000)
        for i in 0..<6 { _ = taps.tap(at: t0.addingTimeInterval(Double(i))) }
        #expect(taps.tap(at: t0.addingTimeInterval(20)) == .nothing, "pause > window resets the count")
        #expect(taps.count == 1)
    }

    @Test @MainActor func releaseModeLocksForOtherAccounts() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let mode = DeveloperMode(defaults: defaults)
        mode.unlock(userID: me)
        mode.validate(userID: me, isDebugBuild: false, allowlist: [me])
        #expect(mode.isOn)
        mode.validate(userID: UUID(), isDebugBuild: false, allowlist: [me])
        #expect(mode.isOn == false, "someone else signed in")
        mode.unlock(userID: nil)
        mode.validate(userID: nil, isDebugBuild: true, allowlist: [])
        #expect(mode.isOn, "Xcode builds never lock by themselves")
        #expect(DeveloperMode(defaults: defaults).isOn, "persisted")
    }
}

// MARK: - Pause policy

struct PausePolicyTests {
    // 2026-11-13 is a Friday.
    let now = day(13, 12)

    @Test func dayOptionsResumeAtStartOfDay() {
        #expect(PausePolicy.pause(.days(1), now: now, calendar: brussels).until == day(15), "skip tomorrow (Sat)")
        #expect(PausePolicy.pause(.days(7), now: now, calendar: brussels).until == day(21))
        #expect(PausePolicy.pause(.indefinitely, now: now, calendar: brussels).until == nil)
    }

    @Test func untilDayIsAtLeastTomorrow() {
        #expect(PausePolicy.pause(.untilDay(day(20, 15)), now: now, calendar: brussels).until == day(20))
        #expect(PausePolicy.pause(.untilDay(day(10)), now: now, calendar: brussels).until == day(14))
    }

    @Test func pausedAndExpired() {
        let pause = AlarmPause(until: day(15))
        #expect(PausePolicy.isPaused(pause, at: now))
        #expect(PausePolicy.isExpired(pause, at: now) == false)
        #expect(PausePolicy.isPaused(pause, at: day(15, 0, 1)) == false)
        #expect(PausePolicy.isExpired(pause, at: day(15)))
        #expect(PausePolicy.isPaused(AlarmPause(until: nil), at: now))
        #expect(PausePolicy.isExpired(AlarmPause(until: nil), at: day(30)) == false)
        #expect(PausePolicy.isPaused(nil, at: now) == false)
    }

    @Test func firstRingAfterPauseRespectsWeekdays() {
        let weekdays = AlarmPlan(hour: 7, minute: 0, weekdays: Set(2...6))  // Mon–Fri
        // Pause until Sunday 15th → first ring Monday 16th.
        #expect(PausePolicy.firstRing(of: weekdays, after: AlarmPause(until: day(15)), calendar: brussels) == day(16, 7))
        // Midnight alarm on the resume day itself still rings.
        let midnight = AlarmPlan(hour: 0, minute: 0)
        #expect(PausePolicy.firstRing(of: midnight, after: AlarmPause(until: day(15)), calendar: brussels) == day(15))
        #expect(PausePolicy.firstRing(of: weekdays, after: AlarmPause(until: nil), calendar: brussels) == nil)
    }

    @Test func firstRingAcrossDaylightSavingChange() {
        // Brussels leaves summer time on 25 Oct 2026; 07:00 local stays 07:00.
        let plan = AlarmPlan(hour: 7, minute: 0)
        let first = PausePolicy.firstRing(of: plan, after: AlarmPause(until: day(26, month: 10)), calendar: brussels)
        #expect(first == day(26, 7, month: 10))
    }

    @Test func filtersRingsInsidePause() {
        let rings = [day(14, 7), day(15, 7), day(16, 7)]
        #expect(PausePolicy.filter(rings, pause: AlarmPause(until: day(15)), now: now) == [day(15, 7), day(16, 7)])
        #expect(PausePolicy.filter(rings, pause: AlarmPause(until: nil), now: now).isEmpty)
        #expect(PausePolicy.filter(rings, pause: nil, now: now) == rings)
    }
}

// MARK: - Coordinator pause / resume

@MainActor struct AlarmPauseCoordinatorTests {
    final class Clock: @unchecked Sendable { var now: Date = .now }

    private func make(_ plans: [AlarmPlan], clock: Clock) -> (AlarmCoordinator, FakeScheduler, KeyValueStore) {
        let store = KeyValueStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        store.savePlans(plans)
        let scheduler = FakeScheduler()
        let c = AlarmCoordinator(store: store, scheduler: scheduler, sound: FakeAlarmSound(), now: { clock.now })
        return (c, scheduler, store)
    }

    private let cal = Calendar.current
    private func local(_ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    @Test func pauseSwapsWeeklyAlarmsForTheFirstRingAfter() async {
        let clock = Clock()
        clock.now = local(13, 12)
        let on = AlarmPlan(hour: 7, isEnabled: true)
        let off = AlarmPlan(hour: 8, isEnabled: false)
        let (c, scheduler, store) = make([on, off], clock: clock)
        await c.refreshAlarms()
        #expect(scheduler.mainPlans[on.id] != nil)

        await c.pauseAll(PausePolicy.pause(.days(1), now: clock.now))
        #expect(scheduler.mainPlans[on.id] == nil, "weekly repeat removed")
        #expect(scheduler.oneOffs[on.id]?.date == local(15, 7), "first ring after the pause, same id")
        #expect(scheduler.oneOffs[off.id] == nil, "disabled alarms stay off")
        #expect(store.loadPause() != nil)
        #expect(c.nextAlarm?.date == local(15, 7))
    }

    @Test func resumeRestoresWeekly() async {
        let clock = Clock()
        clock.now = local(13, 12)
        let plan = AlarmPlan(hour: 7, isEnabled: true)
        let (c, scheduler, store) = make([plan], clock: clock)
        await c.pauseAll(AlarmPause(until: nil))
        #expect(scheduler.mainPlans[plan.id] == nil && scheduler.oneOffs[plan.id] == nil, "indefinite: nothing rings")
        #expect(c.nextAlarm == nil)
        await c.resumeAll()
        #expect(scheduler.mainPlans[plan.id] != nil)
        #expect(store.loadPause() == nil && c.pause == nil)
    }

    @Test func expiredPauseClearsOnRefresh() async {
        let clock = Clock()
        clock.now = local(13, 12)
        let plan = AlarmPlan(hour: 7, isEnabled: true)
        let (c, scheduler, _) = make([plan], clock: clock)
        await c.pauseAll(PausePolicy.pause(.days(1), now: clock.now))
        clock.now = local(15, 9)
        #expect(c.activePause == nil, "ran out")
        await c.restoreMissingAlarms()
        #expect(c.pause == nil)
        #expect(scheduler.mainPlans[plan.id] != nil, "weekly repeat back")
    }

    @Test func ringingAlarmIsLeftAlone() async {
        let clock = Clock()
        clock.now = local(13, 7)
        let plan = AlarmPlan(hour: 7, isEnabled: true)
        let (c, scheduler, _) = make([plan], clock: clock)
        await c.refreshAlarms()
        scheduler.alerting = [plan.id]
        let before = scheduler.cancelled.count
        await c.pauseAll(AlarmPause(until: nil))
        #expect(scheduler.cancelled.count == before, "never cancel a ringing alarm")
        #expect(scheduler.mainPlans[plan.id] != nil)
    }

    @Test func savingWhilePausedRespectsThePause() async {
        let clock = Clock()
        clock.now = local(13, 12)
        let (c, scheduler, _) = make([], clock: clock)
        await c.pauseAll(PausePolicy.pause(.days(1), now: clock.now))
        let plan = AlarmPlan(hour: 6, isEnabled: true)
        await c.save(plan)
        #expect(scheduler.mainPlans[plan.id] == nil)
        #expect(scheduler.oneOffs[plan.id]?.date == local(15, 6))
    }
}

// MARK: - Coach reminders while paused

struct PausedNotificationTests {
    let lines = CoachLines(table: ["night": ["toughLove": ["Lights out. {time} sharp."]]])

    @Test func noRemindersOnPausedDaysAndWelcomeBack() {
        let result = NotificationPlanner.plan(
            now: day(13, 12), upcomingAlarms: [day(14, 7), day(15, 7), day(16, 7)],
            settings: CoachNotificationSettings(enabled: true, remindNoAlarm: false), streak: 0, session: nil,
            alreadyRoastedToday: false, intensity: .toughLove, lines: lines,
            pause: AlarmPause(until: day(15)), calendar: brussels)
        #expect(result.map(\.date) == [day(14, 22), day(15, 22)])
        #expect(result[0].body.hasPrefix("Break's over"))
        #expect(result[1].body.hasPrefix("Break's over") == false)
    }
}

// MARK: - Settings bits

struct SettingsContentTests {
    @Test func permissionSummary() {
        #expect(PermissionSummary.make { _ in .granted } == .allSet)
        #expect(PermissionSummary.make { $0 == .camera ? .denied : .granted } == .allSet, "optional ones don't count")
        let summary = PermissionSummary.make { $0 == .alarms || $0 == .notifications ? .denied : .granted }
        #expect(summary == .needsAttention(2))
        #expect(summary.text == "2 need attention")
    }

    @Test func authConfigDecodesWithoutNewFields() throws {
        let json = #"{"redirectURL":"gloop://auth-callback"}"#
        let config = try JSONDecoder().decode(AuthConfig.self, from: Data(json.utf8))
        #expect(config.supportEmail == nil && config.shareURL == nil)
        let blank = #"{"redirectURL":"gloop://x","supportEmail":" "}"#
        #expect(try JSONDecoder().decode(AuthConfig.self, from: Data(blank.utf8)).supportEmail == nil)
    }

    @Test func bundledHelpFilesDecode() throws {
        let root = TestPaths.shared
        let help = try Data(contentsOf: root.appending(path: "Help.json"))
        let news = try Data(contentsOf: root.appending(path: "WhatsNew.json"))
        let content = HelpContent.decode(help: help, whatsNew: news)
        #expect(content.faq.count >= 5)
        #expect(content.releases.isEmpty == false)
        let dev = try Data(contentsOf: root.appending(path: "Developer.json"))
        #expect(DeveloperAccess.allowlist(from: dev).allSatisfy { _ in true }, "valid JSON")
    }

    @Test func supportMailIsPrefilled() throws {
        let url = try #require(HelpContent.supportMailURL(to: "help@gloop.app", appVersion: "1.0 (7)",
                                                          systemVersion: "26.1", model: "iPhone13,4"))
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.hasPrefix("mailto:help@gloop.app?subject=Gloop%20support"))
        #expect(url.absoluteString.contains("iPhone13,4"))
    }

    @Test func accountProviderNames() {
        #expect(AccountUser(id: UUID(), email: nil, provider: "azure").providerName == "Microsoft")
        #expect(AccountUser(id: UUID(), email: nil, provider: "email").usesPassword)
        #expect(AccountUser(id: UUID(), email: nil, provider: "google").providerName == "Google")
        #expect(AccountUser(id: UUID(), email: nil).providerName == nil)
    }
}

struct SetAlarmTapTests {
    @Test func tapOpensTheEditorOnlyWithoutAlarms() {
        #expect(SetAlarmTap.destination(plans: []) == .newAlarm)
        #expect(SetAlarmTap.destination(plans: [AlarmPlan()]) == .alarmsList, "free plan: a 2nd alarm would hit the paywall")
    }
}
