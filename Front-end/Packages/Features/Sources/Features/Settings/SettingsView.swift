import Account
import AlarmEngine
import Coach
import Core
import Permissions
import Purchases
import StoreKit
import SwiftData
import SwiftUI
import Telemetry

/// Settings tab: a short home of grouped rows; each opens its own page.
/// The Developer page only appears after 7 taps on Version (see `DeveloperAccess`).
struct SettingsView: View {
    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    var onReplayOnboarding: () -> Void = {}

    @Query private var logs: [DayLog]
    @State private var coach = CoachModel.shared
    @State private var permissions = PermissionCenter.shared
    @State private var developer = DeveloperMode.shared
    @State private var profile = ProfileName.shared
    @State private var taps = TapUnlock()
    @Environment(BuddiesModel.self) private var buddiesModel
    @State private var tapHint: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if auth.isAvailable {
                        NavigationLink { AccountView(auth: auth) } label: { header }
                    } else {
                        header
                    }
                }

                Section {
                    NavigationLink { SubscriptionSettingsView(store: store) } label: {
                        row("Gloop Pro", symbol: "sun.max.fill", tint: .orange, value: store.entitlement.shortText)
                    }
                }

                Section("Alarms") {
                    NavigationLink { PauseAlarmsView(coordinator: coordinator) } label: {
                        row("Pause all alarms", symbol: "pause.circle.fill", tint: .indigo,
                            value: coordinator.activePause.map(\.shortText) ?? "Off")
                    }
                    NavigationLink { PermissionsSettingsView() } label: {
                        let summary = PermissionSummary.make(permissions.status)
                        row("Permissions", symbol: "checkmark.shield.fill", tint: .green, value: summary.text,
                            valueTint: summary == .allSet ? nil : .orange)
                    }
                }

                if buddiesModel.service.isAvailable {
                    Section("Buddies") {
                        NavigationLink { BuddiesSettingsView(auth: auth) } label: {
                            row("Buddies", symbol: "person.3.fill", tint: .pink, value: "Privacy & blocked")
                        }
                    }
                }

                Section(CoachIdentity.name) {
                    NavigationLink { CoachSettingsView(coordinator: coordinator) } label: {
                        row("Coach", symbol: "drop.fill", tint: .orange, value: coachSummary)
                    }
                }

                Section("Look & feel") {
                    NavigationLink { AppearanceView() } label: {
                        row("Appearance", symbol: "paintbrush.fill", tint: .purple,
                            value: AppearanceSettings.shared.preference.title)
                    }
                }

                Section("Privacy") {
                    NavigationLink { PrivacySettingsView() } label: {
                        row("Privacy", symbol: "hand.raised.fill", tint: .blue,
                            value: Telemetry.shared.isEnabled ? "Stats on" : "Stats off")
                    }
                }

                Section("Support") {
                    NavigationLink { HelpView(auth: auth) } label: {
                        row("Help & feedback", symbol: "questionmark.bubble.fill", tint: .blue)
                    }
                    Button { requestReview(); Telemetry.shared.send(.action(.rateRequested)) } label: {
                        row("Rate Gloop", symbol: "star.fill", tint: .yellow)
                    }
                    .foregroundStyle(.primary)
                    if let url = auth.config.shareURL {
                        ShareLink(item: url, message: Text(HelpView.shareMessage)) {
                            row("Share Gloop", symbol: "square.and.arrow.up.fill", tint: .teal)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section {
                    Button("Terms of Use") { openURL(auth.config.termsURL) }
                    Button("Privacy Policy") { openURL(auth.config.privacyURL) }
                    NavigationLink("Sound credits") { SoundCreditsView() }
                    Button(action: versionTapped) {
                        LabeledContent("Version", value: Self.version).foregroundStyle(.primary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    if let tapHint { Text(tapHint) }
                }

                if developer.isOn {
                    Section {
                        NavigationLink {
                            DeveloperView(coordinator: coordinator, auth: auth, store: store,
                                          onReplayOnboarding: onReplayOnboarding)
                        } label: {
                            row("Developer tools", symbol: "hammer.fill", tint: .gray)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        .trackScreen("Settings")
            .task { await permissions.refresh() }
            .onChange(of: auth.user?.id, initial: true) { _, id in developer.validate(userID: id) }
        }
    }

    private var header: some View {
        let history = logs.map(DaySummary.init(log:))
        let streak = StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
        return ProfileHeader(name: profile.displayName(for: auth.user),
                             signedIn: auth.user != nil, accountsAvailable: auth.isAvailable,
                             rank: XPRules.progress(history).rank, streak: streak,
                             isPro: store.entitlement.isPro)
    }

    private var coachSummary: String {
        let tone = coach.intensity.displayName
        guard coach.notifications.enabled else { return tone }
        return tone + " · " + String(format: "%02d:%02d", coach.notifications.eveningHour, coach.notifications.eveningMinute)
    }

    private func row(_ title: String, symbol: String, tint: Color, value: String? = nil,
                     valueTint: Color? = nil) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: symbol, tint: tint)
            Text(title).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let value {
                Text(value).foregroundStyle(valueTint ?? .secondary).lineLimit(1)
            }
        }
    }

    private func versionTapped() {
        let allowed = DeveloperAccess.canUnlock(isDebugBuild: DeveloperAccess.isDebugBuild, userID: auth.user?.id,
                                                allowlist: DeveloperAccess.bundledAllowlist())
        guard allowed, !developer.isOn else { return }  // others: nothing happens, no hint
        switch taps.tap(at: .now) {
        case .nothing: tapHint = nil
        case .hint(let remaining): tapHint = "\(remaining) more tap\(remaining == 1 ? "" : "s") to open developer tools"
        case .unlocked:
            tapHint = nil
            withAnimation { developer.unlock(userID: auth.user?.id) }
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// iOS-Settings style rounded square icon.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint.gradient, in: .rect(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}

extension EntitlementState {
    /// "Free", "Trial until 16 Nov, 13:08", "Pro until 13 Dec", "Pro (lifetime)".
    var statusText: String {
        switch self {
        case .free: "Free"
        case .trial(let until): until.map { "Trial until " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "Trial"
        case .pro(let until): until.map { "Pro until " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "Pro (lifetime)"
        }
    }

    /// Settings home: "Free", "Trial", "Active", "Lifetime".
    var shortText: String {
        switch self {
        case .free: "Free"
        case .trial: "Trial"
        case .pro(let until): until == nil ? "Lifetime" : "Active"
        }
    }
}

extension AlarmPause {
    /// "Until Mon 18 Nov" / "Until resumed".
    var shortText: String {
        guard let until else { return "Until resumed" }
        return "Back " + until.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
