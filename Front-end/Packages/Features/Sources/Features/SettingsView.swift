import Account
import AlarmEngine
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
            Button("Show paywall") { showPaywall = true }
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
