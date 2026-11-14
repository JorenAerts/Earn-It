import Account
import AlarmEngine
import Coach
import Core
import Purchases
import StoreKit
import SwiftUI
import UIKit

/// Settings tab: account, subscription, permissions, about & legal (+ developer tools in DEBUG).
struct SettingsView: View {
    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    var onReplayOnboarding: () -> Void = {}

    @State private var showSignIn = false
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var confirmDelete = false
    @State private var busy = false
    @State private var message: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                accountSection
                coachSection
                subscriptionSection
                permissionsSection
                aboutSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Settings")
            .paywallSheet(isPresented: $showPaywall)
            .manageSubscriptionsSheet(isPresented: $showManage)
            .sheet(isPresented: $showSignIn) {
                AccountStepView(auth: auth, skipTitle: "Not now") { showSignIn = false }
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: auth.user) { _, user in if user != nil { showSignIn = false } }
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { deleteAccount() }
            } message: {
                Text("Your account and profile are permanently deleted. Your alarms stay on this iPhone. An active subscription is not cancelled — manage it in Apple ID settings.")
            }
        }
    }

    // MARK: Account

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if !auth.isAvailable {
                Text("Accounts aren't available in this build.").foregroundStyle(.secondary)
            } else if let user = auth.user {
                LabeledContent("Signed in as", value: user.email ?? "your account")
                Button("Sign out") {
                    Task { await auth.signOut() }
                }
                Button("Delete account", role: .destructive) { confirmDelete = true }
                    .disabled(busy)
            } else {
                Button {
                    showSignIn = true
                } label: {
                    Label("Sign in or create account", systemImage: "person.crop.circle.badge.plus")
                }
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Account")
        } footer: {
            if auth.isAvailable, auth.user == nil {
                Text("Optional. Your alarms work without an account.")
            }
        }
    }

    private func deleteAccount() {
        busy = true
        Task {
            do {
                try await auth.deleteAccount()
                message = "Your account was deleted."
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }

    // MARK: Coach

    @State private var coach = CoachModel.shared
    #if DEBUG
    @State private var previewMood: CoachMood = .angry
    @State private var previewAnger = 0.6
    #endif

    private var coachSection: some View {
        Section {
            Picker("Tone", selection: $coach.intensity) {
                ForEach(CoachIntensity.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Coach reminders", isOn: Binding(
                get: { coach.notifications.enabled },
                set: { on in setReminders(on) }))
            if coach.notifications.enabled {
                DatePicker("Evening reminder", selection: eveningTime, displayedComponents: .hourAndMinute)
            }
            if remindersDenied {
                Text("Notifications are off for Earn It. Turn them on in iPhone Settings.")
                    .font(.footnote).foregroundStyle(.red)
            }
            let sample = CoachState(mood: .angry, context: .reRing, anger: 0.6)
            CoachCard(state: sample,
                      line: coach.lines.line(for: .reRing, intensity: coach.intensity, day: .now,
                                             values: ["rings": "3"]),
                      avatarSize: 56)
            #if DEBUG
            VStack(spacing: 10) {
                CoachAvatarView(state: CoachState(mood: previewMood, context: .idle, anger: previewAnger), size: 120)
                Picker("Mood", selection: $previewMood) {
                    ForEach(CoachMood.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                if previewMood == .angry {
                    Slider(value: $previewAnger, in: 0...1) { Text("Anger") }
                }
                Button("Send test reminder in 5 seconds") {
                    Task { await CoachNotifier.shared.sendTest() }
                }
            }
            .padding(.vertical, 4)
            #endif
        } header: {
            Text("Sergeant Rise")
        } footer: {
            Text("How harsh your coach talks when you snooze or miss a morning. Reminders: the evening before each alarm, and a word from him after a missed morning.")
        }
    }

    @State private var remindersDenied = false

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
                let allowed = await CoachNotifier.shared.requestAuthorization()
                remindersDenied = !allowed
                coach.notifications.enabled = allowed
            } else {
                coach.notifications.enabled = false
                remindersDenied = false
            }
            await CoachNotifier.shared.refresh(coordinator: coordinator)
        }
    }

    // MARK: Subscription

    private var subscriptionSection: some View {
        Section("Subscription") {
            LabeledContent("Plan") {
                HStack(spacing: 6) {
                    Text(store.entitlement.statusText)
                    if store.entitlement.isPro { ProBadge() }
                }
            }
            if !store.entitlement.isPro {
                Button { showPaywall = true } label: {
                    Label("Unlock Earn It Pro", systemImage: "sun.max.fill")
                }
            } else if !store.entitlement.isLifetime {
                Button("Manage subscription") { showManage = true }
            }
            Button(busy ? "Restoring…" : "Restore purchases") {
                busy = true
                Task {
                    await store.restore()
                    message = store.entitlement.isPro ? "Purchases restored." : "No purchases found for this Apple ID."
                    busy = false
                }
            }
            .disabled(busy)
        }
    }

    // MARK: Permissions

    private var permissionsSection: some View {
        Section {
            LabeledContent("Alarms") {
                switch coordinator.authorization {
                case .authorized: Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .denied: Label("Off", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                case .notDetermined: Text("Not asked").foregroundStyle(.secondary)
                }
            }
            Button("Open iPhone Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Camera access is asked the first time you use the scan-a-code mission.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            Button("Terms of Use") { openURL(auth.config.termsURL) }
            Button("Privacy Policy") { openURL(auth.config.privacyURL) }
            LabeledContent("Version", value: Self.version)
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    // MARK: Developer

    #if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        DebugSection(coordinator: coordinator)
        Section("Developer") {
            NavigationLink("Widget previews") { WidgetPreviewsView(coordinator: coordinator, store: store) }
            Button("Show paywall") { showPaywall = true }
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
            Button("Replay onboarding", action: onReplayOnboarding)
            Button("Reset cached plan status") { store.debugResetCache() }
            if let user = auth.user {
                LabeledContent("User ID", value: String(user.id.uuidString.prefix(8)))
            }
        }
    }
    #endif
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
}
