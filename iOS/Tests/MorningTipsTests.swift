import Coach
import Foundation
import Localization
import Testing

private let shippedLanguages = (Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String] ?? [])

@Suite("Morning tips")
struct MorningTipsTests {
    init() throws {
        try #require(shippedLanguages.isEmpty == false, "CFBundleLocalizations missing from the test host")
    }

    @Test func everyLanguageHasTheFullTranslatedList() throws {
        let english = MorningTips.load(from: .main, language: "en")
        #expect(english.count >= 40)
        #expect(Set(english.map(\.id)).count == english.count, "duplicate ids")
        for code in shippedLanguages {
            let tips = MorningTips.load(from: .main, language: code)
            #expect(tips.map(\.id) == english.map(\.id), "\(code)")
            for tip in tips {
                #expect(tip.text.trimmingCharacters(in: .whitespaces).isEmpty == false, "\(code) \(tip.id)")
                if tip.kind == .quote { #expect((tip.author ?? "").isEmpty == false, "\(code) \(tip.id) needs an author") }
            }
            if code != "en" {
                // A translation file exists for this language (not silently English).
                let translated = zip(tips, english).filter { $0.text != $1.text }.count
                #expect(translated > english.count / 2, "\(code) looks untranslated")
            }
        }
    }

    @Test func sameTipAllDayAndAnotherTomorrow() throws {
        let tips = MorningTips.load(from: .main, language: "en")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 7)))
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 22)))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: morning))
        #expect(MorningTips.pick(from: tips, day: morning, calendar: calendar)
                == MorningTips.pick(from: tips, day: evening, calendar: calendar))
        #expect(MorningTips.pick(from: tips, day: morning, calendar: calendar)
                != MorningTips.pick(from: tips, day: tomorrow, calendar: calendar))
    }

    @Test func noRepeatsUntilTheWholeListWasShown() throws {
        let tips = MorningTips.load(from: .main, language: "en")
        let calendar = Calendar(identifier: .gregorian)
        let start = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 20)))  // crosses the epoch
        let shown = (0..<tips.count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).flatMap { MorningTips.pick(from: tips, day: $0, calendar: calendar) }
        }
        #expect(Set(shown.map(\.id)).count == tips.count)
        #expect(MorningTips.pick(from: [], day: .now) == nil)
    }
}
