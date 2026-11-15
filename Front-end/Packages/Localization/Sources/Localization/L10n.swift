import Foundation
import Synchronization

/// Translates text in the language chosen in the app (not necessarily the iPhone's language).
///
/// SwiftUI `Text("literal")` follows the `\.locale` environment set at the root. Everything else
/// (model names, notifications, alarm titles, `String` values) goes through `L10n.tr("…")`.
/// All strings live in the app's `Localizable.xcstrings` (Bundle.main); keys are the English text.
/// `scripts/l10n/extract.py` collects every `Text`/`L10n.tr` literal from all packages into it.
public enum L10n {
    private struct State: Sendable {
        var code: String
        var bundle: Bundle
    }

    private static let state = Mutex(State(code: "en", bundle: lprojBundle("en", in: .main) ?? .main))
    private static let bundles = Mutex([String: Bundle]())

    /// Overrides the language for the current task only (tests run in parallel, so they must not
    /// switch the app-wide language): `L10n.$override.withValue("nl") { … }`.
    @TaskLocal public static var override: String?

    /// The language code text is currently resolved in.
    public static var languageCode: String { override ?? state.withLock { $0.code } }
    public static var locale: Locale { Locale(identifier: languageCode) }

    /// The `.lproj` bundle of the current language (Bundle.main when not found).
    public static var bundle: Bundle {
        guard let code = override else { return state.withLock { $0.bundle } }
        return bundles.withLock { cache in
            if let b = cache[code] { return b }
            let b = lprojBundle(code, in: .main) ?? .main
            cache[code] = b
            return b
        }
    }

    /// Switches the language (called by `LanguageSettings`).
    public static func setLanguage(_ code: String, in base: Bundle = .main) {
        let bundle = lprojBundle(code, in: base) ?? base
        state.withLock { $0 = State(code: code, bundle: bundle) }
    }

    static func lprojBundle(_ code: String, in base: Bundle) -> Bundle? {
        let candidates = [code, code.lowercased(), code.replacingOccurrences(of: "-", with: "_")]
        for name in candidates {
            if let path = base.path(forResource: name, ofType: "lproj"), let b = Bundle(path: path) { return b }
        }
        return nil
    }

    /// Translates a literal (with interpolations and plural variants) into the chosen language.
    /// Missing translations fall back to the English text in the code.
    public static func tr(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle, locale: locale)
    }

    /// Translates a key that's only known at runtime (e.g. a name from a JSON file). Returns the key
    /// itself when there is no translation.
    public static func dynamic(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Same as `tr`, for APIs that want a resource (notification content, App Intents).
    public static func resource(_ value: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: tr(value))
    }
}

extension Date {
    /// `formatted(date:time:)` in the app's language.
    public func localized(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time, locale: L10n.locale))
    }

    /// `formatted(.dateTime…)` in the app's language.
    public func localized(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(L10n.locale))
    }
}

extension L10n {
    /// Codes to try for a translated content file, most specific first: "pt-BR" → ["pt-BR", "pt"].
    public static func contentCodes(for code: String = languageCode) -> [String] {
        guard code != "en" else { return [] }
        let base = String(code.split(separator: "-").first ?? Substring(code))
        return base == code ? [code] : [code, base]
    }

    /// A translated content file: `<name>.<code>.<ext>` in `subdirectory` (e.g. `Translations/CoachLines.nl.json`,
    /// `Legal/privacy.nl.md`). nil when the current language has none (callers fall back to English).
    public static func translatedResource(_ name: String, ext: String, subdirectories: [String?],
                                          code: String = languageCode, in bundle: Bundle = .main) -> URL? {
        for c in contentCodes(for: code) {
            for dir in subdirectories {
                if let url = bundle.url(forResource: "\(name).\(c)", withExtension: ext, subdirectory: dir) { return url }
            }
        }
        return nil
    }
}

extension L10n {
    /// A name used mid-sentence ("Find your toothbrush"): lowercased, except in German, where nouns
    /// keep their capital.
    public static func inSentence(_ name: String) -> String {
        languageCode == "de" ? name : name.lowercased(with: locale)
    }
}
