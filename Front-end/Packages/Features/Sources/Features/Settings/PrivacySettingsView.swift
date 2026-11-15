import SwiftUI
import Telemetry

/// Settings › Privacy: anonymous usage statistics (on by default, opt-out).
struct PrivacySettingsView: View {
    @State private var telemetry = Telemetry.shared

    var body: some View {
        List {
            Section {
                Toggle("Share anonymous usage stats", isOn: Binding(
                    get: { telemetry.isEnabled },
                    set: { on in telemetry.setEnabled(on, testMode: DeveloperAccess.isDebugBuild) }))
            } footer: {
                Text("Helps us see which screens and features work and where people get stuck, so we can make Gloop better. Anonymous: a random ID that isn't linked to your account, and never your name, email, alarm names, photos or what you type. Turning it off stops it immediately and forgets the ID.")
            }
            Section("What's collected") {
                Label("Which screens and features you use", systemImage: "square.grid.2x2")
                Label("How onboarding and the paywall go", systemImage: "list.bullet.rectangle")
                Label("How mornings go: rings, missions, streaks", systemImage: "alarm")
                Label("App version, iOS version, device type", systemImage: "iphone")
            }
            .font(.subheadline)
            Section {
                Text("Processed by TelemetryDeck (Germany, EU). No ads, no tracking across apps, nothing sold.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("Settings.Privacy")
    }
}
