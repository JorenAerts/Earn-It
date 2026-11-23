import Coach
import Core
import Foundation
import Testing
import WidgetShared
import UIKit

struct MoodEngineTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private func date(_ d: Int, _ h: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    private func input(now: Date, due: Bool = false, session: SessionState? = nil,
                       history: [DaySummary] = [], alarm: Bool = true) -> CoachInput {
        CoachInput(now: now, missionDue: due, session: session, history: history,
                   nextAlarm: alarm ? now.addingTimeInterval(3600) : nil)
    }

    @Test func ringingWithoutReRingsIsSuspicious() {
        let s = MoodEngine.evaluate(input(now: date(13), due: true, session: SessionState(day: date(13, 0))), calendar: cal)
        #expect(s.mood == .suspicious && s.context == .ringing)
    }

    @Test func angerGrowsWithReRings() {
        let two = MoodEngine.evaluate(input(now: date(13), due: true, session: SessionState(day: date(13, 0), reArmCount: 2)), calendar: cal)
        let five = MoodEngine.evaluate(input(now: date(13), due: true, session: SessionState(day: date(13, 0), reArmCount: 9)), calendar: cal)
        #expect(two.mood == .angry && two.anger > 0 && two.anger < 1)
        #expect(five.anger == 1, "capped")
    }

    @Test func firstTrySuccessIsProud() {
        let session = SessionState(day: date(13, 0), firstEndedAt: date(13, 7), missionCompletedAt: date(13, 7))
        let s = MoodEngine.evaluate(input(now: date(13), session: session), calendar: cal)
        #expect(s == CoachState(mood: .proud, context: .firstTry))
    }

    @Test func streakMilestoneBeatsFirstTry() {
        let history = (11...13).map { DaySummary(day: date($0, 7), completed: true, reArms: 0, failSafe: false) }
        let session = SessionState(day: date(13, 0), missionCompletedAt: date(13, 7))
        let s = MoodEngine.evaluate(input(now: date(13), session: session, history: history), calendar: cal)
        #expect(s.context == .streakMilestone)
    }

    @Test func failSafeIsDisappointed() {
        let session = SessionState(day: date(13, 0), reArmCount: 15, failSafeTriggered: true)
        #expect(MoodEngine.evaluate(input(now: date(13), session: session), calendar: cal).context == .failSafe)
    }

    @Test func brokenStreakIsDisappointedForAWhile() {
        let history = [DaySummary(day: date(9, 7), completed: true, reArms: 0, failSafe: false),
                       DaySummary(day: date(10, 7), completed: true, reArms: 0, failSafe: false)]
        #expect(MoodEngine.evaluate(input(now: date(13), history: history), calendar: cal).context == .streakBroken)
        #expect(MoodEngine.evaluate(input(now: date(25), history: history), calendar: cal).mood == .calm, "forgiven after a week")
    }

    @Test func calmContexts() {
        #expect(MoodEngine.evaluate(input(now: date(13, 23)), calendar: cal).context == .night)
        #expect(MoodEngine.evaluate(input(now: date(13, 14)), calendar: cal).context == .idle)
        #expect(MoodEngine.evaluate(input(now: date(13, 14), alarm: false), calendar: cal).context == .noAlarm)
    }
}

struct CoachLinesTests {
    @Test func everyContextAndToneHasLines() {
        let lines = CoachLines.load()
        for context in CoachContext.allCases {
            for tone in CoachIntensity.allCases {
                #expect(lines.lines(for: context, intensity: tone).count >= 3, "\(context) / \(tone)")
            }
        }
    }

    @Test func placeholdersAreFilledAndPickIsStable() {
        let lines = CoachLines(table: ["reRing": ["savage": ["Ring {rings}!", "Again: {rings}"]]])
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let a = lines.line(for: .reRing, intensity: .savage, day: day, values: ["rings": "4"])
        let b = lines.line(for: .reRing, intensity: .savage, day: day, values: ["rings": "4"])
        #expect(a == b)
        #expect(a.contains("4"))
        #expect(a.contains("{") == false)
        #expect(lines.line(for: .idle, intensity: .gentle, day: day).isEmpty, "missing context is safe")
    }

    @Test func everyMoodLooksDifferent() {
        // The slime is drawn in code: each mood must give a distinct face at the same vitality.
        let faces = CoachMood.allCases.map {
            let pose = SlimeLook.make(vitality: 0.6, state: CoachState(mood: $0, context: .idle, anger: 0.8)).pose
            return "\(pose.eyes)-\(pose.mouth)-\(pose.redness > 0)"
        }
        #expect(Set(faces).count == CoachMood.allCases.count, "\(faces)")
    }

    @Test func intensityDefaultsToToughLoveAndPersists() {
        let prefs = CoachPreferences(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        #expect(prefs.intensity == .toughLove)
        prefs.intensity = .savage
        #expect(prefs.intensity == .savage)
    }
}

struct ProgressionTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private func day(_ d: Int, reArms: Int = 0, done: Bool = true, hour: Int = 7) -> DaySummary {
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
        return DaySummary(day: date, completed: done, reArms: reArms, failSafe: !done, completedAt: done ? date : nil)
    }

    @Test func xpPerMorning() {
        #expect(XPRules.xp(for: day(1), streak: 1) == 50 + 25 + 5)
        #expect(XPRules.xp(for: day(1, reArms: 2), streak: 3) == 40 + 15)
        #expect(XPRules.xp(for: day(1, reArms: 20), streak: 1) == 10 + 5, "minimum when done")
        #expect(XPRules.xp(for: day(1, done: false), streak: 0) == 0)
    }

    @Test func streakBonusResetsAfterAGap() {
        let continuous = XPRules.totalXP([day(1), day(2), day(3)], calendar: cal)
        let gapped = XPRules.totalXP([day(1), day(2), day(5)], calendar: cal)
        #expect(continuous == 80 + 85 + 90)
        #expect(gapped == 80 + 85 + 80)
    }

    @Test func ranksFollowThresholds() {
        #expect(Rank.forXP(0) == .droplet)
        #expect(Rank.forXP(99) == .droplet && Rank.forXP(100) == .blob)
        #expect(Rank.forXP(10_000) == .kingGloop && RankProgress(xp: 20_000).fraction == 1)
        let p = RankProgress(xp: 200)
        #expect(p.next == .jelly && p.xpToNext == 100 && p.fraction == 0.5)
        #expect(Rank.allCases.map(\.threshold) == Rank.allCases.map(\.threshold).sorted())
    }

    @Test func medals() {
        #expect(MedalRules.earned([], calendar: cal).isEmpty)
        let week = (1...7).map { day($0) }
        let earned = MedalRules.earned(week, calendar: cal)
        #expect(earned.isSuperset(of: [.firstMission, .firstTry, .streak3, .streak7, .hatTrick, .perfectWeek]))
        #expect(earned.contains(.streak30) == false)
        #expect(earned.contains(.comeback) == false)
        #expect(MedalRules.earned([day(1), day(5)], calendar: cal).contains(.comeback))
        #expect(MedalRules.earned([day(1, reArms: 6)], calendar: cal).contains(.ironWill))
        #expect(MedalRules.earned([day(1, hour: 5)], calendar: cal).contains(.earlyBird))
    }

    @Test func morningReportDetectsPromotionAndNewMedals() {
        let history = [day(1), day(2)]
        let report = MorningReport.make(history: history, day: day(2).day, calendar: cal)
        #expect(report.xpGained == 85)
        #expect(report.before.rank == .droplet && report.after.rank == .blob && report.promoted)
        #expect(report.newMedals.isEmpty, "first mission / first try were earned on day 1")
        let first = MorningReport.make(history: [day(1)], day: day(1).day, calendar: cal)
        #expect(first.newMedals == [.firstMission, .firstTry])
    }
}

struct NotificationPlannerTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()
    let lines = CoachLines(table: ["night": ["toughLove": ["Lights out. {time} sharp."]],
                                   "failSafe": ["toughLove": ["Unacceptable."]],
                                   "setAlarm": ["toughLove": ["No alarm tomorrow, {name}."]]])

    private func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    private func plan(now: Date, alarms: [Date], enabled: Bool = true, noAlarm: Bool = false,
                      evening: Int = 22, eveningMinute: Int = 0, streak: Int = 0,
                      session: SessionState? = nil, roasted: Bool = false, pause: AlarmPause? = nil,
                      onboarded: Bool = true, name: String = "Sam") -> [CoachNotification] {
        NotificationPlanner.plan(now: now, upcomingAlarms: alarms,
                                 settings: CoachNotificationSettings(enabled: enabled, remindNoAlarm: noAlarm,
                                                                     eveningHour: evening, eveningMinute: eveningMinute),
                                 streak: streak, session: session, alreadyRoastedToday: roasted,
                                 intensity: .toughLove, lines: lines, pause: pause, onboarded: onboarded,
                                 name: name, calendar: cal)
    }

    private func setAlarmDays(_ result: [CoachNotification]) -> [String] {
        result.filter { $0.id.hasPrefix("coach.setAlarm.") }.map { String($0.id.dropFirst("coach.setAlarm.".count)) }
    }

    @Test func eveningBeforeEachAlarmDay() {
        let result = plan(now: at(13, 12), alarms: [at(14, 7), at(15, 7), at(15, 9)])
        #expect(result.map(\.date) == [at(13, 22), at(14, 22)], "one per alarm day")
        #expect(result[0].body == "Lights out. 07:00 sharp.")
        #expect(result[0].id == "coach.evening.2026-11-14")
    }

    @Test func skipsPastOrTooCloseReminders() {
        #expect(plan(now: at(13, 23), alarms: [at(14, 7)]).isEmpty, "evening already passed")
        #expect(plan(now: at(13, 12), alarms: [at(13, 22, 15)], evening: 22).isEmpty, "alarm too soon after reminder")
    }

    @Test func streakOnTheLine() {
        let body = plan(now: at(13, 12), alarms: [at(14, 7)], streak: 5).first?.body ?? ""
        #expect(body.hasSuffix("Your 5-day streak is on the line."))
    }

    @Test func roastOnceAfterFailSafe() {
        let failed = SessionState(day: at(13, 0), reArmCount: 15, failSafeTriggered: true)
        let roast = plan(now: at(13, 8), alarms: [], session: failed)
        #expect(roast.count == 1 && roast[0].id == "coach.roast.2026-11-13" && roast[0].body == "Unacceptable.")
        #expect(plan(now: at(13, 8), alarms: [], session: failed, roasted: true).isEmpty)
    }

    @Test func disabledMeansNothing() {
        #expect(plan(now: at(13, 12), alarms: [at(14, 7)], enabled: false).isEmpty)
        #expect(plan(now: at(13, 12), alarms: [], enabled: false, noAlarm: false).isEmpty, "both reminders off")
    }

    // MARK: "Set your alarm" (13 Nov 2026 is a Friday)

    @Test func remindsWhenTomorrowHasNoAlarm() throws {
        let result = plan(now: at(13, 12), alarms: [at(15, 7)], enabled: false, noAlarm: true)
        // Horizon = 20 Nov 12:00, so the last full target day is the 19th.
        #expect(setAlarmDays(result) == ["2026-11-14", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19"])
        let first = try #require(result.first)
        #expect(first.date == at(13, 22) && first.route == .setAlarm)
        #expect(first.body == "No alarm tomorrow, Sam.")
        #expect(!result.contains { $0.id.hasPrefix("coach.evening.") }, "Coach reminders are off")
    }

    @Test func alarmTomorrowGetsTheNormalEveningReminderInstead() {
        let ids = plan(now: at(13, 12), alarms: [at(14, 7)], noAlarm: true).map(\.id)
        #expect(ids.contains("coach.evening.2026-11-14"))
        #expect(!ids.contains("coach.setAlarm.2026-11-14"))
        #expect(ids.contains("coach.setAlarm.2026-11-15"))
    }

    @Test func weekdaySchedulePromptsBeforeTheWeekend() {
        let weekdays = [17, 18, 19, 20, 23].map { at($0, 7) }  // Tue–Fri + next Monday
        let result = plan(now: at(16, 12), alarms: weekdays, enabled: false, noAlarm: true)
        #expect(setAlarmDays(result) == ["2026-11-21", "2026-11-22"])
        #expect(result.map(\.date) == [at(20, 22), at(21, 22)], "Friday and Saturday evening")
    }

    @Test func nothingWhilePaused() {
        let dated = AlarmPause(until: at(16, 0))
        let rings = [16, 17, 18, 19].map { at($0, 7) }
        #expect(setAlarmDays(plan(now: at(13, 12), alarms: rings, enabled: false, noAlarm: true, pause: dated)).isEmpty)
        let forever = AlarmPause(until: nil)
        #expect(plan(now: at(13, 12), alarms: rings, enabled: false, noAlarm: true, pause: forever).isEmpty)
    }

    @Test func afterMidnightTimeRemindsAboutThatDay() {
        let result = plan(now: at(13, 12), alarms: [], enabled: false, noAlarm: true, evening: 0, eveningMinute: 30)
        #expect(result.first?.date == at(14, 0, 30))
        #expect(setAlarmDays(result).first == "2026-11-14")
    }

    @Test func pastEveningAndBeforeOnboardingAreSkipped() {
        #expect(setAlarmDays(plan(now: at(13, 23), alarms: [], enabled: false, noAlarm: true)).first == "2026-11-15")
        #expect(plan(now: at(13, 12), alarms: [], enabled: false, noAlarm: true, onboarded: false).isEmpty)
    }

    @Test func missingNameFallsBackToFriend() {
        let body = plan(now: at(13, 12), alarms: [], enabled: false, noAlarm: true, name: " ").first?.body
        #expect(body == "No alarm tomorrow, friend.")
    }

    // MARK: Reminder time vs. target day (device bug: a 10:35 test reminder looked at today)

    @Test func daytimeReminderTimeLooksAtTomorrow() {
        let withAlarm = plan(now: at(13, 10, 30), alarms: [at(14, 7)], noAlarm: true, evening: 10, eveningMinute: 35)
        #expect(!setAlarmDays(withAlarm).contains("2026-11-14"), "tomorrow has an alarm")
        #expect(withAlarm.first { $0.id == "coach.evening.2026-11-14" }?.date == at(13, 10, 35))
        let without = plan(now: at(13, 10, 30), alarms: [], enabled: false, noAlarm: true, evening: 10, eveningMinute: 35)
        #expect(without.first?.id == "coach.setAlarm.2026-11-14" && without.first?.date == at(13, 10, 35))
    }

    @Test func onlyTimesBeforeSixAreAboutTheSameMorning() {
        let early = plan(now: at(13, 12), alarms: [], enabled: false, noAlarm: true, evening: 5, eveningMinute: 30)
        #expect(early.first?.date == at(14, 5, 30) && setAlarmDays(early).first == "2026-11-14")
        let six = plan(now: at(13, 12), alarms: [], enabled: false, noAlarm: true, evening: 6)
        #expect(six.first?.date == at(14, 6) && setAlarmDays(six).first == "2026-11-15")
        #expect(NotificationPlanner.targetDay(forReminderAt: at(13, 23, 59), calendar: cal) == at(14, 0))
        #expect(NotificationPlanner.targetDay(forReminderAt: at(14, 0, 30), calendar: cal) == at(14, 0))
    }

    @Test func eveningReminderUsesTheSameCutoff() {
        // 05:30 reminder for a 07:00 alarm the same morning; a 10:35 one goes the day before.
        #expect(plan(now: at(13, 12), alarms: [at(14, 7)], evening: 5, eveningMinute: 30).map(\.date) == [at(14, 5, 30)])
        #expect(plan(now: at(13, 9), alarms: [at(14, 7)], evening: 10, eveningMinute: 35).map(\.date) == [at(13, 10, 35)])
    }

    // MARK: End to end with real alarms (upcomingRings → plan). 13 Nov 2026 = Friday; weekday 1 = Sunday.

    private func setAlarmDays(now: Date? = nil, plans: [AlarmPlan], evening: Int = 22, minute: Int = 0) -> [String] {
        let now = now ?? at(13, 12)
        let rings = NotificationPlanner.upcomingRings(plans: plans, from: now, calendar: cal)
        return setAlarmDays(plan(now: now, alarms: rings, enabled: false, noAlarm: true, evening: evening, eveningMinute: minute))
    }

    @Test func realPlans() {
        let all = ["2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19"]
        let daily = AlarmPlan(hour: 7, isEnabled: true)
        #expect(setAlarmDays(plans: [daily]).isEmpty, "today's 07:00 has passed, tomorrow rings")
        #expect(setAlarmDays(plans: [AlarmPlan(hour: 7, weekdays: Set(2...6), isEnabled: true)]) == ["2026-11-14", "2026-11-15"],
                "Mon–Fri: weekend evenings remind")
        #expect(setAlarmDays(plans: [AlarmPlan(hour: 7, isEnabled: false)]) == all, "disabled alarms don't count")
        #expect(setAlarmDays(plans: [AlarmPlan(hour: 9, weekdays: [7], isEnabled: true), AlarmPlan(hour: 7, isEnabled: false)])
                == Array(all.dropFirst()), "only the enabled Saturday alarm counts")
        #expect(setAlarmDays(plans: []) == all)
    }

    @Test func oneOffAlarmCountsOnlyForItsOwnDay() {
        let once = AlarmPlan(hour: 7, weekdays: [], isEnabled: true)
        #expect(NotificationPlanner.upcomingRings(plans: [once], from: at(13, 12), calendar: cal) == [at(14, 7)])
        #expect(setAlarmDays(plans: [once]) == ["2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19"])
    }

    @Test func deviceReproWithRealPlan() {
        // 10:30, reminder at 10:35, daily 07:00 alarm → tomorrow is covered: no "set your alarm".
        #expect(setAlarmDays(now: at(13, 10, 30), plans: [AlarmPlan(hour: 7, isEnabled: true)], evening: 10, minute: 35).isEmpty)
    }

    @Test func noAlarmReminderIsOnByDefaultAndPersists() {
        let prefs = CoachPreferences(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        #expect(prefs.notifications.remindNoAlarm)
        #expect(!prefs.notifications.enabled)
        prefs.notifications.remindNoAlarm = false
        #expect(!prefs.notifications.remindNoAlarm)
    }
}
