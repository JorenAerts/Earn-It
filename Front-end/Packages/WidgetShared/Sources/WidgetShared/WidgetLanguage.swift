import Foundation
import Localization

/// The widget extension runs in its own process: it follows the language the app last used
/// (shared through the App Group), or the iPhone's language when that isn't available.
public enum WidgetLanguage {
    /// Applies the language to `L10n` and returns the locale for `.environment(\.locale, …)`.
    @discardableResult
    public static func apply(bundle: Bundle = .main) -> Locale {
        let code = LanguageSettings.sharedLanguageCode(bundle: bundle)
            ?? AppLanguage.bestMatch(for: Locale.preferredLanguages, among: AppLanguage.available(in: bundle)).code
        if code != L10n.languageCode { L10n.setLanguage(code, in: bundle) }
        return Locale(identifier: code)
    }
}
