import Foundation

/// A language Gloop is translated into. `code` = the Apple localization id (the `.lproj` name).
public struct AppLanguage: Hashable, Identifiable, Sendable, Codable {
    public let code: String
    /// Name in the language itself ("Nederlands", "日本語").
    public let nativeName: String
    /// Name in English (shown under the native name, used for search).
    public let englishName: String
    public let flag: String

    public var id: String { code }
    public var locale: Locale { Locale(identifier: code) }
    public var isRightToLeft: Bool { Locale.Language(identifier: code).characterDirection == .rightToLeft }

    public init(code: String, nativeName: String, englishName: String, flag: String) {
        self.code = code
        self.nativeName = nativeName
        self.englishName = englishName
        self.flag = flag
    }

    public static let english = AppLanguage(code: "en", nativeName: "English", englishName: "English", flag: "🇬🇧")

    /// Every language the app ships. Keep in sync with `CFBundleLocalizations` (project.yml) and the
    /// catalogs (a test checks every language has every string).
    public static let all: [AppLanguage] = [
        english,
        AppLanguage(code: "ar", nativeName: "العربية", englishName: "Arabic", flag: "🇸🇦"),
        AppLanguage(code: "ca", nativeName: "Català", englishName: "Catalan", flag: "🇦🇩"),
        AppLanguage(code: "zh-Hans", nativeName: "简体中文", englishName: "Chinese (Simplified)", flag: "🇨🇳"),
        AppLanguage(code: "zh-Hant", nativeName: "繁體中文", englishName: "Chinese (Traditional)", flag: "🇹🇼"),
        AppLanguage(code: "hr", nativeName: "Hrvatski", englishName: "Croatian", flag: "🇭🇷"),
        AppLanguage(code: "cs", nativeName: "Čeština", englishName: "Czech", flag: "🇨🇿"),
        AppLanguage(code: "da", nativeName: "Dansk", englishName: "Danish", flag: "🇩🇰"),
        AppLanguage(code: "nl", nativeName: "Nederlands", englishName: "Dutch", flag: "🇳🇱"),
        AppLanguage(code: "fi", nativeName: "Suomi", englishName: "Finnish", flag: "🇫🇮"),
        AppLanguage(code: "fr", nativeName: "Français", englishName: "French", flag: "🇫🇷"),
        AppLanguage(code: "de", nativeName: "Deutsch", englishName: "German", flag: "🇩🇪"),
        AppLanguage(code: "el", nativeName: "Ελληνικά", englishName: "Greek", flag: "🇬🇷"),
        AppLanguage(code: "he", nativeName: "עברית", englishName: "Hebrew", flag: "🇮🇱"),
        AppLanguage(code: "hi", nativeName: "हिन्दी", englishName: "Hindi", flag: "🇮🇳"),
        AppLanguage(code: "hu", nativeName: "Magyar", englishName: "Hungarian", flag: "🇭🇺"),
        AppLanguage(code: "id", nativeName: "Bahasa Indonesia", englishName: "Indonesian", flag: "🇮🇩"),
        AppLanguage(code: "it", nativeName: "Italiano", englishName: "Italian", flag: "🇮🇹"),
        AppLanguage(code: "ja", nativeName: "日本語", englishName: "Japanese", flag: "🇯🇵"),
        AppLanguage(code: "ko", nativeName: "한국어", englishName: "Korean", flag: "🇰🇷"),
        AppLanguage(code: "ms", nativeName: "Bahasa Melayu", englishName: "Malay", flag: "🇲🇾"),
        AppLanguage(code: "nb", nativeName: "Norsk bokmål", englishName: "Norwegian", flag: "🇳🇴"),
        AppLanguage(code: "pl", nativeName: "Polski", englishName: "Polish", flag: "🇵🇱"),
        AppLanguage(code: "pt-BR", nativeName: "Português (Brasil)", englishName: "Portuguese (Brazil)", flag: "🇧🇷"),
        AppLanguage(code: "pt-PT", nativeName: "Português (Portugal)", englishName: "Portuguese (Portugal)", flag: "🇵🇹"),
        AppLanguage(code: "ro", nativeName: "Română", englishName: "Romanian", flag: "🇷🇴"),
        AppLanguage(code: "ru", nativeName: "Русский", englishName: "Russian", flag: "🇷🇺"),
        AppLanguage(code: "sk", nativeName: "Slovenčina", englishName: "Slovak", flag: "🇸🇰"),
        AppLanguage(code: "es", nativeName: "Español", englishName: "Spanish", flag: "🇪🇸"),
        AppLanguage(code: "sv", nativeName: "Svenska", englishName: "Swedish", flag: "🇸🇪"),
        AppLanguage(code: "th", nativeName: "ไทย", englishName: "Thai", flag: "🇹🇭"),
        AppLanguage(code: "tr", nativeName: "Türkçe", englishName: "Turkish", flag: "🇹🇷"),
        AppLanguage(code: "uk", nativeName: "Українська", englishName: "Ukrainian", flag: "🇺🇦"),
        AppLanguage(code: "vi", nativeName: "Tiếng Việt", englishName: "Vietnamese", flag: "🇻🇳"),
    ]

    /// Languages that are actually translated in this build (others are hidden from the picker
    /// until their wave lands). Order: English first, then alphabetical by English name.
    public static func available(in bundle: Bundle = .main) -> [AppLanguage] {
        let shipped = Set(bundle.localizations)
        return all.filter { $0.code == "en" || shipped.contains($0.code) }
    }

    public static func with(code: String) -> AppLanguage? { all.first { $0.code == code } }

    /// Best supported language for a list of preferred languages (e.g. `Locale.preferredLanguages`),
    /// English when nothing matches. "pt" → pt-PT, "pt-BR" → pt-BR, "zh-Hant-HK" → zh-Hant, "no" → nb.
    public static func bestMatch(for preferred: [String], among languages: [AppLanguage] = all) -> AppLanguage {
        let codes = languages.map(\.code)
        for raw in preferred {
            let lang = Locale.Language(identifier: raw)
            guard var base = lang.languageCode?.identifier else { continue }
            if base == "no" || base == "nn" { base = "nb" }
            var candidates: [String] = []
            if let script = lang.script?.identifier { candidates.append("\(base)-\(script)") }
            if let region = lang.region?.identifier { candidates.append("\(base)-\(region)") }
            if base == "zh" {
                // Chinese without a script: Taiwan/Hong Kong/Macau use Traditional.
                let region = lang.region?.identifier ?? ""
                candidates.append(["TW", "HK", "MO"].contains(region) ? "zh-Hant" : "zh-Hans")
            }
            if base == "pt" { candidates.append(lang.region?.identifier == "BR" ? "pt-BR" : "pt-PT") }
            candidates.append(base)
            if let hit = candidates.first(where: codes.contains) { return languages.first { $0.code == hit }! }
        }
        return languages.first { $0.code == "en" } ?? .english
    }
}
