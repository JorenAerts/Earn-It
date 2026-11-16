import Foundation
import Observation

/// The user's language choice. `nil` = Automatic (the iPhone's language when Gloop has it,
/// otherwise English). Stored in `gloop.language` and copied to the App Group so widgets follow.
@MainActor @Observable
public final class LanguageSettings {
    public static let shared = LanguageSettings()
    public nonisolated static let key = "gloop.language"
    /// The iPhone's languages, remembered while on Automatic: once a language is chosen we also set
    /// `AppleLanguages`, after which `Locale.preferredLanguages` no longer shows the iPhone's own.
    nonisolated static let deviceKey = "gloop.language.device"

    /// Shows the picker sheet (presented once, at the root, so it survives the redraw on a switch).
    public var isPickerPresented = false
    /// Where the picker was opened from (telemetry): "onboarding" / "settings".
    public var pickerSource = "settings"

    public func presentPicker(source: String) {
        pickerSource = source
        isPickerPresented = true
    }

    private let defaults: UserDefaults
    private let groupDefaults: UserDefaults?
    private let preferred: () -> [String]
    private let available: [AppLanguage]
    private let apply: (String) -> Void

    /// The explicit choice, nil = Automatic.
    public private(set) var choice: String?
    /// The language the app shows right now.
    public private(set) var current: AppLanguage

    public init(defaults: UserDefaults = .standard,
                groupDefaults: UserDefaults? = LanguageSettings.appGroupDefaults(),
                preferred: @escaping () -> [String] = { Locale.preferredLanguages },
                available: [AppLanguage] = AppLanguage.available(),
                apply: @escaping (String) -> Void = { L10n.setLanguage($0) }) {
        self.defaults = defaults
        self.groupDefaults = groupDefaults
        self.preferred = preferred
        self.available = available
        self.apply = apply
        let stored = defaults.string(forKey: Self.key)
        let choice = stored.flatMap { code in available.contains { $0.code == code } ? code : nil }
        self.choice = choice
        if choice == nil { defaults.set(preferred(), forKey: Self.deviceKey) }
        self.current = Self.resolve(choice: choice, preferred: preferred(), available: available)
        apply(current.code)
        groupDefaults?.set(current.code, forKey: Self.key)
    }

    public var languages: [AppLanguage] { available }
    public var isAutomatic: Bool { choice == nil }

    /// What Automatic would pick.
    public var automaticLanguage: AppLanguage {
        Self.resolve(choice: nil, preferred: devicePreferred, available: available)
    }

    private var devicePreferred: [String] {
        defaults.stringArray(forKey: Self.deviceKey) ?? preferred()
    }

    /// Pick a language (nil = Automatic). Returns true when the shown language changed.
    @discardableResult
    public func select(_ code: String?, persist: Bool = true) -> Bool {
        let valid = code.flatMap { c in available.contains { $0.code == c } ? c : nil }
        choice = valid
        if !persist {
            // Screenshot runs (-language): this launch only.
        } else if let valid {
            defaults.set(valid, forKey: Self.key)
            // System texts (permission prompts, share sheet) follow from the next launch on.
            defaults.set([valid], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: Self.key)
            defaults.removeObject(forKey: "AppleLanguages")
        }
        let next = Self.resolve(choice: valid, preferred: devicePreferred, available: available)
        groupDefaults?.set(next.code, forKey: Self.key)
        guard next != current else { return false }
        current = next
        apply(next.code)
        return true
    }

    public nonisolated static func resolve(choice: String?, preferred: [String], available: [AppLanguage]) -> AppLanguage {
        if let choice, let hit = available.first(where: { $0.code == choice }) { return hit }
        return AppLanguage.bestMatch(for: preferred, among: available)
    }

    public nonisolated static func appGroupDefaults(bundle: Bundle = .main) -> UserDefaults? {
        guard let group = bundle.object(forInfoDictionaryKey: "GloopAppGroup") as? String, !group.isEmpty,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil
        else { return nil }
        return UserDefaults(suiteName: group)
    }

    /// For the widget extension: the language the app last used.
    public nonisolated static func sharedLanguageCode(bundle: Bundle = .main) -> String? {
        appGroupDefaults(bundle: bundle)?.string(forKey: key)
    }
}
