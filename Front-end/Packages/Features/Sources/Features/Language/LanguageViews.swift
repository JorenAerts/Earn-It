import Localization
import SwiftUI
import Telemetry

/// Applies the chosen language to everything below: `Text("…")` lookups, date/number formats and
/// right-to-left layout for Arabic and Hebrew.
struct LanguageEnvironment: ViewModifier {
    let language: AppLanguage

    func body(content: Content) -> some View {
        content
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

/// Searchable list of languages, each in its own name. Tapping switches the app instantly.
struct LanguagePickerView: View {
    @Bindable var settings: LanguageSettings
    var onDone: () -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        row(code: nil, title: L10n.tr("Automatic"),
                            subtitle: L10n.tr("iPhone language: \(settings.automaticLanguage.nativeName)"),
                            flag: "🌐", selected: settings.isAutomatic)
                    }
                }
                Section {
                    ForEach(filtered) { language in
                        row(code: language.code, title: language.nativeName,
                            subtitle: englishSubtitle(language), flag: language.flag,
                            selected: !settings.isAutomatic && settings.current == language)
                    }
                } footer: {
                    Text("Translations are made with care, but may not be perfect yet. Spotted a mistake? Let us know via Help & feedback.")
                }
            }
            .searchable(text: $query, prompt: Text("Search languages"))
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDone) }
            }
        }
        .trackScreen("Language")
    }

    private var filtered: [AppLanguage] {
        let all = settings.languages.sorted { a, b in
            a.code == "en" ? true : b.code == "en" ? false : a.englishName < b.englishName
        }
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.nativeName.localizedCaseInsensitiveContains(query) || $0.englishName.localizedCaseInsensitiveContains(query)
                || $0.code.localizedCaseInsensitiveContains(query)
        }
    }

    /// The English name, plus the name in the current language when that's different
    /// ("Dutch · Nederlands" reads oddly, so only one extra name is shown).
    private func englishSubtitle(_ language: AppLanguage) -> String? {
        let inCurrent = L10n.locale.localizedString(forIdentifier: language.code)
        if let inCurrent, inCurrent.caseInsensitiveCompare(language.nativeName) != .orderedSame { return inCurrent }
        return language.englishName == language.nativeName ? nil : language.englishName
    }

    private func row(code: String?, title: String, subtitle: String?, flag: String, selected: Bool) -> some View {
        Button {
            let from = settings.current.code
            if settings.select(code) {
                Telemetry.shared.send(.action(.languageChanged(from: from, to: settings.current.code,
                                                               automatic: code == nil, source: settings.pickerSource)))
            }
        } label: {
            HStack(spacing: 14) {
                Text(flag).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).foregroundStyle(.primary)
                    if let subtitle { Text(verbatim: subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if selected { Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.orange) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 🌐 + current flag, for the onboarding welcome screen.
struct LanguageButton: View {
    let settings: LanguageSettings

    var body: some View {
        Button { settings.presentPicker(source: "onboarding") } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(verbatim: settings.current.flag)
            }
            .font(.headline)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.regularMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Language: \(settings.current.nativeName)"))
    }
}
