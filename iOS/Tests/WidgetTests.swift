import Coach
import Foundation
import Testing
import WidgetShared

struct WidgetSnapshotTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private func at(_ d: Int, _ h: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    private func history(_ days: [Int], failed: [Int] = []) -> [DaySummary] {
        days.map { DaySummary(day: at($0, 0), completed: true, reArms: 0, failSafe: false, completedAt: at($0, 7)) }
        + failed.map { DaySummary(day: at($0, 0), completed: false, reArms: 15, failSafe: true) }
    }

    private func snapshot(_ h: [DaySummary], now: Date) -> WidgetSnapshot {
        WidgetSnapshot.make(history: h, now: now, state: CoachState(mood: .calm, context: .idle), line: "x",
                            isPro: false, nextAlarm: nil, calendar: cal)
    }

    @Test func buildsStreakXPAndStrip() {
        let s = snapshot(history([11, 12, 13], failed: [10]), now: at(13))
        #expect(s.streak == 3 && s.bestStreak == 3 && s.xp > 0)
        #expect(s.lastDays.count == 14)
        #expect(Array(s.lastDays.suffix(4)) == [.failed, .done, .done, .done])
        #expect(s.recentMedals.contains(Medal.streak3.rawValue))
    }

    @Test func streakSurvivesUntilTheEndOfTheNextDayThenResets() {
        let s = snapshot(history([12, 13]), now: at(13))
        #expect(s.completedToday(at: at(13), calendar: cal))
        #expect(s.streak(at: at(14, 23), calendar: cal) == 2, "still alive tomorrow, today pending")
        #expect(s.completedToday(at: at(14), calendar: cal) == false)
        #expect(s.streak(at: at(15, 0), calendar: cal) == 0, "missed the 14th: gone at midnight")
    }

    @Test func dayStripShiftsWithTheDate() {
        let s = snapshot(history([13]), now: at(13))
        #expect(s.days(at: at(13), calendar: cal).last == .done)
        let next = s.days(at: at(14), calendar: cal)
        #expect(next.count == 14 && next.last == WidgetSnapshot.DayMark.none && next[12] == .done)
    }

    @Test func emptyHistory() {
        let s = snapshot([], now: at(13))
        #expect(s.streak(at: at(13), calendar: cal) == 0 && s.xp == 0 && s.recentMedals.isEmpty)
    }

    @Test func storeRoundTripsInAContainerDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = SnapshotStore(directory: dir)
        #expect(store.load() == nil)
        let s = snapshot(history([12, 13]), now: at(13))
        #expect(store.save(s))
        #expect(store.load() == s)
        #expect(SnapshotStore(directory: nil).save(s) == false, "no App Group: nothing written")
    }
}
