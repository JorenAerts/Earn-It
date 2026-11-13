import Coach
import Core
import Foundation
import Testing
import UIKit

@Suite struct MoodEngineTests {
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

@Suite struct CoachLinesTests {
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
        #expect(a == b && a.contains("4") && !a.contains("{"))
        #expect(lines.line(for: .idle, intensity: .gentle, day: day).isEmpty, "missing context is safe")
    }

    @Test func everyMoodHasAnImage() {
        for mood in CoachMood.allCases {
            #expect(UIImage(named: mood.imageName) != nil, "missing asset \(mood.imageName)")
        }
    }

    @Test func intensityDefaultsToToughLoveAndPersists() {
        let prefs = CoachPreferences(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        #expect(prefs.intensity == .toughLove)
        prefs.intensity = .savage
        #expect(prefs.intensity == .savage)
    }
}

@Suite struct ProgressionTests {
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
        #expect(Rank.forXP(0) == .recruit)
        #expect(Rank.forXP(99) == .recruit && Rank.forXP(100) == .privateSoldier)
        #expect(Rank.forXP(10_000) == .general && RankProgress(xp: 20_000).fraction == 1)
        let p = RankProgress(xp: 200)
        #expect(p.next == .privateFirstClass && p.xpToNext == 100 && p.fraction == 0.5)
        #expect(Rank.allCases.map(\.threshold) == Rank.allCases.map(\.threshold).sorted())
    }

    @Test func medals() {
        #expect(MedalRules.earned([], calendar: cal).isEmpty)
        let week = (1...7).map { day($0) }
        let earned = MedalRules.earned(week, calendar: cal)
        #expect(earned.isSuperset(of: [.firstMission, .firstTry, .streak3, .streak7, .hatTrick, .perfectWeek]))
        #expect(!earned.contains(.streak30) && !earned.contains(.comeback))
        #expect(MedalRules.earned([day(1), day(5)], calendar: cal).contains(.comeback))
        #expect(MedalRules.earned([day(1, reArms: 6)], calendar: cal).contains(.ironWill))
        #expect(MedalRules.earned([day(1, hour: 5)], calendar: cal).contains(.earlyBird))
    }

    @Test func morningReportDetectsPromotionAndNewMedals() {
        let history = [day(1), day(2)]
        let report = MorningReport.make(history: history, day: day(2).day, calendar: cal)
        #expect(report.xpGained == 85)
        #expect(report.before.rank == .recruit && report.after.rank == .privateSoldier && report.promoted)
        #expect(report.newMedals.isEmpty, "first mission / first try were earned on day 1")
        let first = MorningReport.make(history: [day(1)], day: day(1).day, calendar: cal)
        #expect(first.newMedals == [.firstMission, .firstTry])
    }
}
