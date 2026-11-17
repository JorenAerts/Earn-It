import AlarmEngine
import Coach
import Core
import Localization
import Permissions
import Purchases
import StoreKit
import SwiftUI
import Telemetry

// MARK: - Gloop Pro

struct SubscriptionSettingsView: View {
    let store: StoreService
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var busy = false
    @State private var message: String?

    static let proFeatures: [(symbol: String, text: String)] = [
        ("alarm.waves.left.and.right.fill", L10n.tr("Unlimited alarms")),
        ("puzzlepiece.extension.fill", L10n.tr("Every mission: shake, scan a code, scan your item")),
        ("music.note", L10n.tr("All sounds, your own sounds and Apple Music")),
        ("square.grid.2x2.fill", L10n.tr("Medium and Large widgets")),
    ]

    var body: some View {
        List {
            if store.canTestAsFree || store.forceFree {
                // TestFlight testers only: their Pro is a test purchase (a Lifetime one can't be cancelled).
                Section {
                    Toggle("Test as Free plan", isOn: Binding(get: { store.forceFree }, set: { store.setForceFree($0) }))
                        .tint(.orange)
                } footer: {
                    Text("TestFlight only. Your test purchase stays; Gloop acts like the free plan until you turn this off.")
                }
            }
            Section {
                LabeledContent("Plan") {
                    HStack(spacing: 6) {
                        Text(store.entitlement.statusText)
                        if store.entitlement.isPro { ProBadge() }
                    }
                }
            }
            Section(store.entitlement.isPro ? L10n.tr("Included") : L10n.tr("With Pro")) {
                ForEach(Self.proFeatures, id: \.text) { feature in
                    Label(feature.text, systemImage: feature.symbol)
                        .foregroundStyle(store.entitlement.isPro ? .primary : .secondary)
                }
            }
            Section {
                if !store.entitlement.isPro {
                    Button { showPaywall = true } label: {
                        Label("Unlock Gloop Pro", systemImage: "sun.max.fill")
                    }
                } else if !store.entitlement.isLifetime {
                    Button("Manage subscription") { showManage = true }
                }
                Button(busy ? L10n.tr("Restoring…") : L10n.tr("Restore purchases")) {
                    busy = true
                    Task {
                        await store.restore()
                        message = RestoreMessage.text(purchases: store.activePurchases, catalog: store.catalog)
                        busy = false
                    }
                }
                .disabled(busy)
            } footer: {
                if let message { Text(message) }
            }
        }
        .navigationTitle("Gloop Pro")
        .navigationBarTitleDisplayMode(.inline)
        .paywallSheet(isPresented: $showPaywall, source: .settings)
        .manageSubscriptionsSheet(isPresented: $showManage)
    }
}

// MARK: - Permissions

struct PermissionsSettingsView: View {
    var body: some View {
        List {
            Section {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionRow(kind: kind)
                }
            } footer: {
                Text("Turned something off? \"Open Settings\" takes you to Gloop's page in iOS Settings; come back and it updates here.")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await PermissionCenter.shared.refresh() }
    }
}

// MARK: - Coach (Gloop)

struct CoachSettingsView: View {
    let coordinator: AlarmCoordinator
    @State private var coach = CoachModel.shared
    @State private var remindersDenied = false

    var body: some View {
        List {
            Section {
                SlimeHealthCard()
                let sample = CoachState(mood: .angry, context: .reRing, anger: 0.6)
                CoachCard(state: sample,
                          line: coach.lines.line(for: .reRing, intensity: coach.intensity, day: .now,
                                                 values: ["rings": "3"]),
                          avatarSize: 56)
                Picker("Tone", selection: $coach.intensity) {
                    ForEach(CoachIntensity.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: coach.intensity) { _, tone in Telemetry.shared.send(.action(.coachToneChanged(tone: tone.rawValue))) }
            } header: {
                Text("Tone")
            } footer: {
                Text("How harsh your coach talks when you snooze or miss a morning.")
            }

            Section {
                Toggle("Coach reminders", isOn: Binding(
                    get: { coach.notifications.enabled },
                    set: { on in setReminders(on) }))
                if coach.notifications.enabled {
                    DatePicker("Evening reminder", selection: eveningTime, displayedComponents: .hourAndMinute)
                }
                if remindersDenied || (coach.notifications.enabled && PermissionCenter.shared.status(.notifications) == .denied) {
                    PermissionBanner(kind: .notifications, message: L10n.tr("Notifications are off, so reminders can't arrive."))
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("The evening before each alarm, and a word from him after a missed morning. No reminders while alarms are paused.")
            }
        }
        .navigationTitle(CoachIdentity.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var eveningTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: coach.notifications.eveningHour,
                                      minute: coach.notifications.eveningMinute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                coach.notifications.eveningHour = c.hour ?? 22
                coach.notifications.eveningMinute = c.minute ?? 0
                Task { await CoachNotifier.shared.refresh(coordinator: coordinator) }
            })
    }

    private func setReminders(_ on: Bool) {
        Task {
            if on {
                let allowed = await PermissionCenter.shared.ensure(.notifications)  // denied → Settings prompt
                remindersDenied = !allowed
                coach.notifications.enabled = allowed
                Telemetry.shared.send(.action(.remindersToggled(on: allowed)))
            } else {
                coach.notifications.enabled = false
                remindersDenied = false
            }
            await CoachNotifier.shared.refresh(coordinator: coordinator)
        }
    }
}

// MARK: - Sound credits

struct SoundCreditsView: View {
    var body: some View {
        List {
            Section {
                ForEach(AlarmSound.allCases.filter { $0.credit != nil }) { sound in
                    LabeledContent(sound.displayName, value: sound.credit ?? "")
                }
            } header: {
                Text("Melodies")
            } footer: {
                Text("Public-domain compositions, performed by Gloop's own sound generator.")
            }
            Section {
                Text("Every other built-in sound was made for Gloop. Your own sounds and Apple Music songs stay yours and are never uploaded.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Sound credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
