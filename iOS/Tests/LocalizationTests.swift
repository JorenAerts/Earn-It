import Coach
import Core
import Features
import Foundation
import Localization
import Testing

struct L10nTests {
    @Test func resolvesTheChosenLanguageNotTheIPhones() {
        L10n.$override.withValue("nl") {
            #expect(L10n.tr("Math problems") == "Rekensommen")
            #expect(MissionKind.math.displayName == "Rekensommen")
        }
        L10n.$override.withValue("en") { #expect(L10n.tr("Math problems") == "Math problems") }
    }

    @Test func pluralsAndInterpolation() {
        L10n.$override.withValue("nl") { pluralsInDutch() }
    }

    private func pluralsInDutch() {
        let one = 1, many = 5
        #expect(L10n.tr("\(one)-day streak") == "Reeks van 1 dag")
        #expect(L10n.tr("\(many)-day streak") == "Reeks van 5 dagen")
    }

    @Test func missingTranslationFallsBackToEnglish() {
        L10n.$override.withValue("nl") {
            #expect(L10n.tr("This key does not exist anywhere") == "This key does not exist anywhere")
        }
    }
}

struct AppLanguageTests {
    @Test func bestMatch() {
        #expect(AppLanguage.bestMatch(for: ["nl-BE"]).code == "nl")
        #expect(AppLanguage.bestMatch(for: ["pt-BR"]).code == "pt-BR")
        #expect(AppLanguage.bestMatch(for: ["pt-AO"]).code == "pt-PT")
        #expect(AppLanguage.bestMatch(for: ["zh-Hant-HK"]).code == "zh-Hant")
        #expect(AppLanguage.bestMatch(for: ["zh-HK"]).code == "zh-Hant")
        #expect(AppLanguage.bestMatch(for: ["zh-CN"]).code == "zh-Hans")
        #expect(AppLanguage.bestMatch(for: ["no-NO"]).code == "nb")
        #expect(AppLanguage.bestMatch(for: ["xx", "fr-CA"]).code == "fr")
        #expect(AppLanguage.bestMatch(for: ["xx"]).code == "en")
        #expect(AppLanguage.bestMatch(for: ["de"], among: [.english]).code == "en")
    }

    @Test func rightToLeft() {
        #expect(AppLanguage.with(code: "ar")?.isRightToLeft == true)
        #expect(AppLanguage.with(code: "he")?.isRightToLeft == true)
        #expect(AppLanguage.with(code: "nl")?.isRightToLeft == false)
    }

    @Test func codesAreUnique() {
        #expect(Set(AppLanguage.all.map(\.code)).count == AppLanguage.all.count)
    }
}

@MainActor struct LanguageSettingsTests {
    private func make(stored: String? = nil, preferred: [String] = ["de-DE"]) -> (LanguageSettings, UserDefaults, UserDefaults) {
        let d = UserDefaults(suiteName: "l10n-\(UUID())")!, g = UserDefaults(suiteName: "l10n-g-\(UUID())")!
        if let stored { d.set(stored, forKey: LanguageSettings.key) }
        let langs = AppLanguage.all.filter { ["en", "nl", "de"].contains($0.code) }
        return (LanguageSettings(defaults: d, groupDefaults: g, preferred: { preferred }, available: langs, apply: { _ in }), d, g)
    }

    @Test func automaticFollowsTheIPhone() {
        let (s, _, g) = make()
        #expect(s.isAutomatic && s.current.code == "de")
        #expect(g.string(forKey: LanguageSettings.key) == "de")
    }

    @Test func choiceOverridesAndPersists() {
        let (s, d, g) = make()
        #expect(s.select("nl"))
        #expect(s.current.code == "nl")
        #expect(d.string(forKey: LanguageSettings.key) == "nl" && g.string(forKey: LanguageSettings.key) == "nl")
        #expect(s.select("nl") == false)
        s.select(nil)
        #expect(s.isAutomatic && s.current.code == "de" && d.string(forKey: LanguageSettings.key) == nil)
    }

    @Test func unknownStoredLanguageMeansAutomatic() {
        let (s, _, _) = make(stored: "xx", preferred: ["fr"])
        #expect(s.isAutomatic && s.current.code == "en")
    }
}

// MARK: - Catalog and content completeness (every shipped language)

private let front = TestPaths.ios
private let shared = TestPaths.shared

fileprivate struct Catalog {
    let strings: [String: [String: Any]]

    static func load(_ name: String = "Localizable") throws -> Catalog {
        let data = try Data(contentsOf: front.appending(path: "App/\(name).xcstrings"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any], "\(name).xcstrings is not a JSON object")
        return Catalog(strings: try #require(json["strings"] as? [String: [String: Any]], "\(name).xcstrings has no strings"))
    }

    var languages: Set<String> {
        Set(strings.values.flatMap { (($0["localizations"] as? [String: Any]) ?? [:]).keys })
    }

    /// Every value for a language (all plural forms).
    func values(_ key: String, _ code: String) -> [String] {
        guard let loc = (strings[key]?["localizations"] as? [String: Any])?[code] as? [String: Any] else { return [] }
        if let unit = loc["stringUnit"] as? [String: Any] { return [unit["value"] as? String ?? ""] }
        let plural = ((loc["variations"] as? [String: Any])?["plural"] as? [String: Any]) ?? [:]
        return plural.values.compactMap { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    func translatable(_ key: String) -> Bool { strings[key]?["shouldTranslate"] as? Bool ?? true }
}

private func placeholders(_ s: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: "%(?:\\d\\$)?(?:lld|ld|d|@|lf|f)")
    return regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }.sorted()
}

/// Languages that ship a translation (English is the source).
private let shipped = (Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String] ?? []).filter { $0 != "en" }

struct CatalogTests {
    fileprivate let catalog: Catalog

    init() throws {
        try #require(shipped.isEmpty == false, "CFBundleLocalizations missing from the test host")
        catalog = try Catalog.load()
    }

    @Test func infoPlistLanguagesMatchTheCatalog() {
        #expect(Set(shipped) == catalog.languages.subtracting(["en"]),
                "CFBundleLocalizations in project.yml must list exactly the translated languages")
        #expect(Set(shipped).isSubset(of: Set(AppLanguage.all.map(\.code))))
    }

    @Test func everyKeyIsTranslatedInEveryShippedLanguage() {
        for code in shipped {
            let missing = catalog.strings.keys.filter { catalog.translatable($0) && catalog.values($0, code).isEmpty }
            #expect(missing.isEmpty, "\(code) is missing \(missing.count) strings, e.g. \(missing.sorted().prefix(5))")
        }
    }

    @Test func placeholdersMatch() {
        for code in shipped + ["en"] {
            for key in catalog.strings.keys {
                for value in catalog.values(key, code) {
                    #expect(value.trimmingCharacters(in: .whitespaces).isEmpty == key.trimmingCharacters(in: .whitespaces).isEmpty,
                            "\(code): empty value for \(key)")
                    let expected = placeholders(key), got = placeholders(value)
                    // A singular form may drop the number ("every day").
                    #expect(got == expected || Set(got).isSubset(of: Set(expected)) && got.count < expected.count,
                            "\(code): placeholders differ for \(key) → \(value)")
                }
            }
        }
    }

    @Test func infoPlistStringsAreTranslated() throws {
        let info = try Catalog.load("InfoPlist")
        for code in shipped {
            for key in info.strings.keys where info.translatable(key) { #expect(info.values(key, code).isEmpty == false, "InfoPlist \(key) missing in \(code)") }
        }
    }
}

struct TranslatedContentTests {
    init() throws {
        try #require(shipped.isEmpty == false, "CFBundleLocalizations missing from the test host")
    }

    private func json(_ path: String) -> Any? {
        (try? Data(contentsOf: shared.appending(path: path))).flatMap { try? JSONSerialization.jsonObject(with: $0) }
    }

    private func tokens(_ s: String) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: "\\{\\{?\\w+\\}?\\}")
        return Set(regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) })
    }

    @Test func coachLinesExistPerLanguageWithTheSamePlaceholders() throws {
        let english = try #require(json("CoachLines.json") as? [String: [String: [String]]])
        let englishTokens = Set(english.values.flatMap(\.values).flatMap { $0 }.flatMap(tokens))
        for code in shipped {
            let table = try #require(json("Translations/CoachLines.\(code).json") as? [String: [String: [String]]],
                                     "Translations/CoachLines.\(code).json missing")
            #expect(Set(table.keys) == Set(english.keys), "\(code): coach contexts differ")
            for (context, tones) in english {
                #expect(Set(table[context]?.keys.map { $0 } ?? []) == Set(tones.keys), "\(code): tones differ in \(context)")
            }
            let used = Set(table.values.flatMap(\.values).flatMap { $0 }.flatMap(tokens))
            #expect(used.isSubset(of: englishTokens), "\(code): unknown placeholders \(used.subtracting(englishTokens))")
        }
    }

    @Test func helpAndWhatsNewPerLanguage() throws {
        let faq = try #require((json("Help.json") as? [String: Any])?["faq"] as? [Any])
        let versions = try #require((json("WhatsNew.json") as? [String: Any])?["releases"] as? [[String: Any]]).compactMap { $0["version"] as? String }
        for code in shipped {
            let local = (json("Translations/Help.\(code).json") as? [String: Any])?["faq"] as? [Any]
            #expect(local?.count == faq.count, "\(code): Help FAQ must have \(faq.count) questions")
            let news = ((json("Translations/WhatsNew.\(code).json") as? [String: Any])?["releases"] as? [[String: Any]] ?? [])
                .compactMap { $0["version"] as? String }
            #expect(Set(news) == Set(versions), "\(code): What's New needs every version")
        }
    }

    @Test func legalDocumentsPerLanguageKeepStructureAndPlaceholders() throws {
        for kind in LegalDocumentKind.allCases {
            let english = try String(contentsOf: shared.appending(path: "Legal/\(kind.rawValue).md"), encoding: .utf8)
            for code in shipped {
                // "pt-BR" may use the shared "pt" document.
                let text = try #require(L10n.contentCodes(for: code).lazy.compactMap {
                    try? String(contentsOf: shared.appending(path: "Legal/\(kind.rawValue).\($0).md"), encoding: .utf8)
                }.first, "\(kind.rawValue).\(code).md missing")
                #expect(LegalDocument.parse(text).headings.count == LegalDocument.parse(english).headings.count,
                        "\(kind.rawValue).\(code): section count differs")
                #expect(tokens(text) == tokens(english), "\(kind.rawValue).\(code): {{placeholders}} differ")
            }
        }
    }
}

struct LocalizedRuntimeTests {
    @Test func dutchEndToEnd() {
        L10n.$override.withValue("nl") { dutch() }
    }

    private func dutch() {
        #expect(MissionKind.math.displayName == "Rekensommen")
        #expect(Rank.kingGloop.title == "Koning Gloop" && Rank.kingGloop.englishTitle == "King Gloop")
        #expect(Rank.from(title: "King Gloop") == .kingGloop && Rank.from(title: "Koning Gloop") == .kingGloop)
        #expect(MissionConfig(kind: .shake, target: 1).instruction == "Schud je telefoon één keer.")
        #expect(MissionConfig(kind: .shake, target: 30).instruction == "Schud je telefoon 30 keer.")
        let lines = CoachLines.load(language: "nl")
        #expect(lines.lines(for: .ringing, intensity: .gentle).first == "Goedemorgen! Laten we samen opstaan.")
        let help = HelpContent.load(language: "nl")
        #expect(help.faq.first?.question == "Waarom blijft de wekker afgaan?")
        let privacy = LegalDocument.load(.privacy, language: "nl")
        #expect(privacy.isTranslation && privacy.title == "Privacybeleid")
        #expect(LegalDocument.load(.privacy, english: true, language: "nl").isTranslation == false)
    }

    @Test func englishIsTheDefaultAndPluralised() {
        L10n.$override.withValue("en") { english() }
    }

    private func english() {
        #expect(MissionConfig(kind: .math, target: 1).instruction == "Solve 1 problem.")
        #expect(MissionConfig(kind: .math, target: 3).instruction == "Solve 3 problems in a row.")
        #expect(MissionKind.math.targetText(1) == "1 problem")
        #expect(LegalDocument.load(.privacy, language: "en").isTranslation == false)
    }

    @Test func legalValuesPerLanguage() {
        let values = LegalDocument.localizedValues(["country": "Belgium", "country.nl": "België", "x.pt": "p", "x": "base"],
                                                   language: "pt-BR")
        #expect(values["country"] == "Belgium" && values["x"] == "p")
        #expect(LegalDocument.localizedValues(["country": "Belgium", "country.nl": "België"], language: "nl")["country"] == "België")
    }
}
