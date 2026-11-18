import Coach
import Core
import Features
import Foundation
import Testing
import WidgetShared

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Brussels")!
    return c
}()

private func day(_ d: Int, _ h: Int = 7) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
}

private func done(_ d: Int, reArms: Int = 0) -> DaySummary {
    DaySummary(day: day(d), completed: true, reArms: reArms, failSafe: false)
}

struct SlimeVitalityTests {
    let now = day(15, 12)

    @Test func newUserStartsHealthy() {
        #expect(SlimeVitality.compute(history: [], now: now, calendar: cal) == SlimeVitality.start)
        #expect(SlimeVitality.compute(history: [], now: now, calendar: cal) { _ in true } == SlimeVitality.start,
                "no history yet = nothing counts as missed")
    }

    @Test func firstRingMorningsPerkHimUp() {
        let history = (8...15).map { done($0) }
        let v = SlimeVitality.compute(history: history, now: now, calendar: cal) { _ in true }
        #expect(v > 0.9 && v <= 1)
    }

    @Test func missesMeltHim() {
        let history = [done(1), DaySummary(day: day(13), completed: false, reArms: 5, failSafe: true),
                       DaySummary(day: day(14), completed: false, reArms: 5, failSafe: true)]
        let v = SlimeVitality.compute(history: history, now: now, calendar: cal) { _ in true }
        #expect(v < 0.35)
    }

    @Test func daysWithoutAlarmDontCount() {
        let history = [done(10), done(15)]
        let alarmEveryDay = SlimeVitality.compute(history: history, now: now, calendar: cal) { _ in true }
        let noOtherAlarms = SlimeVitality.compute(history: history, now: now, calendar: cal) { _ in false }
        #expect(noOtherAlarms > alarmEveryDay, "unlogged days only hurt when an alarm should have rung")
        #expect(noOtherAlarms > 0.8)
    }

    @Test func recentDaysWeighMore() {
        let goodRecently = [DaySummary(day: day(5), completed: false, reArms: 0, failSafe: true), done(15)]
        let badRecently = [done(5), DaySummary(day: day(15), completed: false, reArms: 0, failSafe: true)]
        #expect(SlimeVitality.compute(history: goodRecently, now: now, calendar: cal)
                > SlimeVitality.compute(history: badRecently, now: now, calendar: cal))
    }

    @Test func reRingsCostALittle() {
        #expect(SlimeVitality.score(done(1)) == 1)
        #expect(abs(SlimeVitality.score(done(1, reArms: 3)) - 0.7) < 0.0001)
        #expect(SlimeVitality.score(done(1, reArms: 9)) == 0.5)
    }

    @Test func alwaysInRange() {
        let perfect = (1...15).map { done($0) }
        #expect(SlimeVitality.compute(history: perfect, now: now, calendar: cal) <= 1)
        let awful = (1...15).map { DaySummary(day: day($0), completed: false, reArms: 9, failSafe: true) }
        #expect(SlimeVitality.compute(history: awful, now: now, calendar: cal) >= 0)
    }
}

struct SlimeLookTests {
    @Test func droopFollowsVitality() {
        let calm = CoachState(mood: .calm, context: .idle)
        let happy = SlimeLook.make(vitality: 1, state: calm)
        let melted = SlimeLook.make(vitality: 0.1, state: calm)
        #expect(happy.pose.droop < 0.05 && happy.pose.drips == 0 && happy.pose.sparkle)
        #expect(melted.pose.droop > 0.85 && melted.pose.drips == 3 && melted.pose.eyes == .teary)
        #expect(melted.pose.saturation < happy.pose.saturation)
    }

    @Test func angerMeltsAndReddens() {
        let mild = SlimeLook.make(vitality: 0.8, state: CoachState(mood: .angry, context: .reRing, anger: 0.2))
        let furious = SlimeLook.make(vitality: 0.8, state: CoachState(mood: .angry, context: .reRing, anger: 1))
        #expect(furious.pose.droop > mild.pose.droop)
        #expect(furious.pose.redness > mild.pose.redness)
        #expect(furious.pose.steam)
        #expect(mild.pose.steam == false)
        #expect(furious.tremble == 1)
    }

    @Test func successPuffsHimUp() {
        let sad = SlimeLook.make(vitality: 0.2, state: CoachState(mood: .calm, context: .idle))
        let proud = SlimeLook.make(vitality: 0.2, state: CoachState(mood: .proud, context: .missionSuccess))
        #expect(proud.pose.droop < sad.pose.droop)
        #expect(proud.pose.eyes == .sparkly && proud.pose.mouth == .grin)
    }
}

@MainActor struct AppearanceTests {
    @Test func lightByDefaultAndRemembered() {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = AppearanceSettings(defaults: d)
        #expect(settings.preference == .light)
        #expect(AppearancePreference.light.colorScheme == .light && AppearancePreference.system.colorScheme == nil)
        settings.preference = .dark
        #expect(AppearanceSettings(defaults: d).preference == .dark)
    }

    @Test func slimeMatchesTheIcon() {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = AppearanceSettings(defaults: d, currentIconName: "AppIcon-Grape")
        #expect(settings.icon == .grape && settings.slimeColor == .grape)
        settings.matchSlimeToIcon = false
        settings.customSlimeColor = .mint
        #expect(settings.slimeColor == .mint)
        #expect(AppearanceSettings(defaults: d, currentIconName: nil).icon == .slime)
    }

    @Test func everyIconHasItsAssets() throws {
        let assets = TestPaths.ios.appending(path: "App/Assets.xcassets")
        for choice in AppIconChoice.allCases {
            let set = choice.alternateIconName ?? "AppIcon"
            #expect(FileManager.default.fileExists(atPath: assets.appending(path: "\(set).appiconset/\(set).png").path()), "\(set)")
            #expect(FileManager.default.fileExists(atPath: assets.appending(path: "\(choice.previewImageName).imageset").path()))
        }
        let project = try String(contentsOf: assets.deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "project.yml"), encoding: .utf8)
        for name in AppIconChoice.allCases.compactMap(\.alternateIconName) {
            #expect(project.contains(name), "\(name) listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES")
        }
    }
}

struct GloopVoiceTests {
    @Test func noSergeantLeft() throws {
        let url = TestPaths.shared.appending(path: "CoachLines.json")
        let text = try String(contentsOf: url, encoding: .utf8)
        for word in ["Sergeant", "soldier", "private,", "megaphone", "direct order"] {
            #expect(text.contains(word) == false, "\(word)")
        }
        let table = try JSONDecoder().decode([String: [String: [String]]].self, from: Data(text.utf8))
        let missing = CoachContext.allCases.flatMap { context in
            CoachIntensity.allCases.compactMap { tone in
                (table[context.rawValue]?[tone.rawValue] ?? []).isEmpty ? "\(context.rawValue)/\(tone.rawValue)" : nil
            }
        }
        #expect(missing.isEmpty, "keys: \(table.keys.sorted())")
    }

    @Test func oldWidgetSnapshotsStillDecode() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WidgetSnapshot.placeholder)) as! [String: Any]
        json.removeValue(forKey: "vitality")
        json.removeValue(forKey: "slimeColor")
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(WidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(snapshot.vitality == SlimeVitality.start && snapshot.slimeColor == "orange")
    }
}

struct EvolutionTests {
    @Test func stagesKeepTheirThresholds() {
        #expect(Rank.allCases.map(\.threshold) == [0, 100, 300, 600, 1_000, 1_600, 2_500, 3_600, 5_000, 7_000, 10_000])
        #expect(Rank.forXP(0) == .droplet && Rank.forXP(10_000) == .kingGloop)
        #expect(Rank(rawValue: 4) == .bouncer, "raw values unchanged")
    }

    @Test func oldAndNewTitlesMap() {
        let legacy = ["Recruit", "Private", "Private First Class", "Corporal", "Sergeant", "Staff Sergeant",
                      "Lieutenant", "Captain", "Major", "Colonel", "General"]
        for (index, title) in legacy.enumerated() {
            #expect(Rank.from(title: title) == Rank(rawValue: index), "\(title)")
        }
        for rank in Rank.allCases { #expect(Rank.from(title: rank.title) == rank) }
        #expect(Rank.from(title: "Banana") == nil && Rank.from(title: nil) == nil)
    }

    @Test func everyStageHasItsOwnAccessory() {
        #expect(Rank.droplet.accessory == .none)
        let accessories = Rank.allCases.dropFirst().map(\.accessory)
        #expect(Set(accessories).count == accessories.count)
        #expect(accessories.contains(.none) == false)
        #expect(Rank.kingGloop.accessory == .crown)
        let look = SlimeLook.make(vitality: 0.9, state: CoachState(mood: .calm, context: .idle), accessory: .cap)
        #expect(look.pose.accessory == .cap)
    }

    @Test func stickersHaveNoArmyWords() {
        let army = ["duty", "centurion", "iron", "soldier", "rank", "medal"]
        for medal in Medal.allCases {
            #expect(army.contains { medal.title.lowercased().contains($0) } == false, "\(medal.title)")
        }
        #expect(Medal(rawValue: "firstMission") == .firstMission, "raw values unchanged (widget snapshots)")
    }

    @Test func noArmyTermsInConfig() throws {
        let config = TestPaths.shared
        let army = ["Sergeant", "soldier", "Recruit", "General", "promotion", "Promoted", "Service Record", "medal"]
        for file in ["CoachLines.json", "Help.json", "WhatsNew.json"] {
            let text = try String(contentsOf: config.appending(path: file), encoding: .utf8)
            for word in army { #expect(text.contains(word) == false, "\(file): \(word)") }
        }
    }
}
