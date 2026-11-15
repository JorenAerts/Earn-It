import Account
import AlarmEngine
import Coach
import Core
import Purchases
import SwiftUI
import UIKit
import WidgetShared

/// Settings › Developer tools. Only reachable after 7 taps on Version (see `DeveloperAccess`).
struct DeveloperView: View {
    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    var onReplayOnboarding: () -> Void

    @State private var developer = DeveloperMode.shared
    @State private var previewMood: CoachMood = .angry
    @State private var previewAnger = 0.6
    @State private var previewVitality = 0.75
    @State private var showPaywall = false
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            DebugSection(coordinator: coordinator)

            Section("Sound") {
                Button("Test: own sound via alarm in 10 s") {
                    // Spike: does AlarmKit find files in Library/Sounds? Copies Rising Siren under a custom name;
                    // if the alarm plays the siren, own sounds ring natively.
                    let id = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!
                    let target = CustomSoundLibrary.url(for: id)
                    try? FileManager.default.createDirectory(at: CustomSoundLibrary.directory, withIntermediateDirectories: true)
                    if !FileManager.default.fileExists(atPath: target.path()),
                       let siren = Bundle.main.url(forResource: AlarmSound.siren.resourceName, withExtension: "caf") {
                        try? FileManager.default.copyItem(at: siren, to: target)
                    }
                    Task { await coordinator.debugRing(inSeconds: 10, sound: .custom(id: id, name: "Spike")) }
                }
            }

            Section("Coach") {
                VStack(spacing: 10) {
                    CoachAvatarView(state: CoachState(mood: previewMood, context: .idle, anger: previewAnger), size: 140,
                                    vitality: previewVitality)
                    Slider(value: $previewVitality, in: 0...1) { Text("Vitality") }
                    Text("Vitality \(Int(previewVitality * 100))% (yours: \(Int(CoachModel.shared.vitality * 100))%)")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Mood", selection: $previewMood) {
                        ForEach(CoachMood.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if previewMood == .angry {
                        Slider(value: $previewAnger, in: 0...1) { Text("Anger") }
                    }
                }
                .padding(.vertical, 4)
                NavigationLink("Slime gallery") { SlimeGallery() }
                Button("Send test reminder in 5 seconds") {
                    Task { await CoachNotifier.shared.sendTest() }
                }
            }

            Section("Store & onboarding") {
                Button("Show paywall") { showPaywall = true }
                Button("Reset cached plan status") { store.debugResetCache() }
                Button("Replay onboarding", action: onReplayOnboarding)
            }

            Section("Previews") {
                NavigationLink("Widget previews") { WidgetPreviewsView(coordinator: coordinator, store: store) }
            }

            Section {
                if let user = auth.user {
                    Button {
                        UIPasteboard.general.string = user.id.uuidString
                        copied = true
                    } label: {
                        LabeledContent("User ID", value: String(user.id.uuidString.prefix(8)) + "…")
                    }
                    .foregroundStyle(.primary)
                } else {
                    LabeledContent("User ID", value: "Signed out")
                }
                LabeledContent("Build", value: "\(SettingsView.version) · \(DeveloperAccess.isDebugBuild ? "Debug" : "Release")")
                LabeledContent("Accounts", value: auth.isAvailable ? "Supabase configured" : "Not configured")
                LabeledContent("App Group", value: SnapshotStore.shared.isAvailable ? "Available" : "Unavailable")
                LabeledContent("Entitlement", value: store.entitlement.statusText)
                LabeledContent("Pause", value: coordinator.pause.map(\.shortText) ?? "None")
            } header: {
                Text("Info")
            } footer: {
                Text(copied ? "User ID copied. Add it to Config/Developer.json to unlock these tools in TestFlight builds."
                            : "Tap the user ID to copy it.")
            }

            Section {
                Button("Lock developer tools", role: .destructive) {
                    developer.lock()
                    dismiss()
                }
            } footer: {
                Text("Tap Version 7 times to open them again.")
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .paywallSheet(isPresented: $showPaywall)
    }
}

/// Alarm loop tools: test rings, panic stop, session reset, what AlarmKit holds.
struct DebugSection: View {
    let coordinator: AlarmCoordinator
    @State private var alarms: [ScheduledAlarm] = []

    var body: some View {
        Section("Alarms") {
            Button("Ring in 1 minute (first alarm)") { Task { await coordinator.debugRing(inSeconds: 60); refresh() } }
            Button("Ring in 10 seconds (first alarm)") { Task { await coordinator.debugRing(inSeconds: 10); refresh() } }
            Button("Stop all alarms", role: .destructive) { coordinator.debugStopAll(); refresh() }
            Button("Reset today's session", role: .destructive) { coordinator.debugResetSession(); refresh() }
            if let s = coordinator.session {
                LabeledContent("Re-arms", value: "\(s.reArmCount)")
                LabeledContent("Follow-ups pending", value: "\(s.followUpIDs.count)")
                LabeledContent("Mission done", value: s.missionDone ? "yes" : "no")
            }
            if let error = coordinator.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        Section("AlarmKit alarms (\(alarms.count))") {
            ForEach(alarms) { alarm in
                LabeledContent(coordinator.plan(id: alarm.id).map { "Main " + $0.timeText } ?? String(alarm.id.uuidString.prefix(8)),
                               value: alarm.state)
            }
            Button("Refresh", action: refresh)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() { alarms = coordinator.debugScheduledAlarms() }
}
