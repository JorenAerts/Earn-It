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
