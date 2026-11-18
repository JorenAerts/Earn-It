import Features
import Foundation
import Testing

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Brussels")!
    return c
}()
private func day(_ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 8))! }

struct RatingPolicyTests {
    let installed = RatingPolicy.State(installDate: day(1))

    @Test func asksAtHappyMoments() {
        #expect(RatingPolicy.moment(from: [.streak(7)], state: installed, now: day(10), appVersion: "1.0", failSafeToday: false, calendar: cal) == .streak(7))
        #expect(RatingPolicy.moment(from: [.firstRingMornings(3)], state: installed, now: day(10), appVersion: "1.0", failSafeToday: false, calendar: cal) == .firstRingMornings(3))
        #expect(RatingPolicy.moment(from: [.evolved, .streak(2)], state: installed, now: day(10), appVersion: "1.0", failSafeToday: false, calendar: cal) == .evolved)
    }

    @Test func notAtOrdinaryMoments() {
        #expect(RatingPolicy.moment(from: [.streak(5), .firstRingMornings(4)], state: installed, now: day(10),
                                    appVersion: "1.0", failSafeToday: false, calendar: cal) == nil)
    }

    @Test func neverAfterAFailSafeOrTooEarly() {
        #expect(RatingPolicy.moment(from: [.streak(7)], state: installed, now: day(10), appVersion: "1.0", failSafeToday: true, calendar: cal) == nil)
        #expect(RatingPolicy.moment(from: [.evolved], state: installed, now: day(3), appVersion: "1.0", failSafeToday: false, calendar: cal) == nil,
                "first 3 days after install")
    }

    @Test func cooldownAndOncePerVersion() {
        let recent = RatingPolicy.State(installDate: day(1), lastPrompt: day(5), lastPromptVersion: "0.9")
        #expect(RatingPolicy.moment(from: [.evolved], state: recent, now: day(20), appVersion: "1.0", failSafeToday: false, calendar: cal) == nil, "60-day cooldown")
        let sameVersion = RatingPolicy.State(installDate: day(1), lastPrompt: nil, lastPromptVersion: "1.0")
        #expect(RatingPolicy.moment(from: [.evolved], state: sameVersion, now: day(20), appVersion: "1.0", failSafeToday: false, calendar: cal) == nil)
    }
}

struct WhatsNewPolicyTests {
    @Test func onlyAfterAnUpdateWithNotes() {
        #expect(WhatsNewPolicy.versionToShow(current: "1.1", lastSeenVersion: nil, availableVersions: ["1.1"]) == nil, "fresh install")
        #expect(WhatsNewPolicy.versionToShow(current: "1.1", lastSeenVersion: "1.0", availableVersions: ["1.1", "1.0"]) == "1.1")
        #expect(WhatsNewPolicy.versionToShow(current: "1.1", lastSeenVersion: "1.1", availableVersions: ["1.1"]) == nil, "already seen")
        #expect(WhatsNewPolicy.versionToShow(current: "1.2", lastSeenVersion: "1.1", availableVersions: ["1.1"]) == nil, "no notes")
    }

    @Test @MainActor func storeRemembers() {
        let store = GrowthStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        #expect(store.whatsNewSeenVersion == nil && store.ratingState.lastPrompt == nil)
        store.markWhatsNewSeen("1.0")
        store.didPromptRating(version: "1.0", at: day(9))
        #expect(store.whatsNewSeenVersion == "1.0")
        #expect(store.ratingState.lastPromptVersion == "1.0" && store.ratingState.lastPrompt == day(9))
    }
}

struct AppStoreMetadataTests {
    static let root = TestPaths.ios

    private func text(_ locale: String, _ file: String) throws -> String {
        try String(contentsOf: Self.root.appending(path: "fastlane/metadata/\(locale)/\(file).txt"), encoding: .utf8)
    }

    @Test(arguments: ["en-US", "en-GB"])
    func withinAppStoreLimits(locale: String) throws {
        #expect(try text(locale, "name").count <= 30)
        #expect(try text(locale, "subtitle").count <= 30)
        #expect(try text(locale, "promotional_text").count <= 170)
        #expect(try text(locale, "description").count <= 4000)
        #expect(try text(locale, "release_notes").count <= 4000)
        let keywords = try text(locale, "keywords")
        #expect(keywords.utf8.count <= 100)
        #expect(keywords.contains(" ") == false)
        #expect(keywords.contains(",,") == false)
    }

    @Test func keywordsDontRepeatNameOrSubtitle() throws {
        let titleWords = Set((try text("en-US", "name") + " " + text("en-US", "subtitle"))
            .lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        let us = try text("en-US", "keywords").split(separator: ",").map(String.init)
        let uk = try text("en-GB", "keywords").split(separator: ",").map(String.init)
        for word in us + uk { #expect(titleWords.contains(word) == false, "\(word) is already in the name/subtitle") }
        #expect(Set(us).isDisjoint(with: Set(uk)), "US and UK fields should cover different words")
        #expect(Set(us).count == us.count && Set(uk).count == uk.count)
    }

    @Test func screenshotsHaveTheRequiredSizes() throws {
        let dir = Self.root.appending(path: "fastlane/screenshots/en-US")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path()).filter { $0.hasSuffix(".png") }
        #expect(files.filter { $0.hasSuffix("-6.9.png") }.count == 10)
        #expect(files.filter { $0.hasSuffix("-6.5.png") }.count == 10)
        for file in files {
            let data = try Data(contentsOf: dir.appending(path: file))
            // PNG IHDR: width at byte 16, height at byte 20 (big-endian).
            let w = data[16..<20].reduce(0) { $0 << 8 | Int($1) }
            let h = data[20..<24].reduce(0) { $0 << 8 | Int($1) }
            let expected = file.hasSuffix("-6.9.png") ? (1320, 2868) : (1284, 2778)
            #expect(w == expected.0 && h == expected.1, "\(file) is \(w)×\(h)")
        }
    }
}

@MainActor struct StreakCardTests {
    @Test func cardContent() {
        let content = StreakCardContent(streak: 12, rank: .bouncer, stickers: 4, vitality: 0.9)
        #expect(content.rank.accessory == .cap)
        #expect(content.streak == 12)
    }
}
