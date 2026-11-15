import Account
import Coach
import Observation
import SwiftUI
import WidgetShared

/// The display name, kept on this iPhone (works signed out) and synced to the account's profile.
@MainActor
@Observable
final class ProfileName {
    static let shared = ProfileName()
    private static let key = "gloop.profile.name"
    @ObservationIgnored private let defaults: UserDefaults

    private(set) var name: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        name = defaults.string(forKey: Self.key) ?? ""
    }

    func set(_ value: String) {
        name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(name, forKey: Self.key)
    }

    /// Name, else the part of the email before the @, else "Your profile".
    func displayName(for user: AccountUser?) -> String {
        Self.displayName(name: name, email: user?.email)
    }

    nonisolated static func displayName(name: String, email: String?) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let local = email?.split(separator: "@").first, !local.isEmpty { return String(local) }
        return placeholder
    }

    nonisolated static let placeholder = "Your profile"
}

/// Top of Settings: initial, name, rank, streak, PRO.
struct ProfileHeader: View {
    let name: String
    let signedIn: Bool
    let accountsAvailable: Bool
    let rank: Rank
    let streak: Int
    let isPro: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.gradient)
                if name != ProfileName.placeholder {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.title.weight(.bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill").font(.title2).foregroundStyle(.white)
                }
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name).font(.title3.weight(.semibold)).lineLimit(1)
                    if isPro { ProBadge() }
                }
                HStack(spacing: 6) {
                    RankInsignia(rank: rank, size: 18)
                    Text(rank.title)
                    Text("·")
                    Text("\(Image(systemName: "flame.fill")) \(streak)-day streak")
                        .foregroundStyle(streak > 0 ? .orange : .secondary)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if accountsAvailable, !signedIn {
                    Text("Sign in to keep your progress safe")
                        .font(.caption).foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Settings › profile: name, sign-in method, password, sign out, delete account.
struct AccountView: View {
    let auth: any AuthService

    @State private var profile = ProfileName.shared
    @State private var name = ""
    @State private var showSignIn = false
    @State private var confirmDelete = false
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .onSubmit(saveName)
            } header: {
                Text("Name")
            } footer: {
                Text("How \(CoachIdentity.name) and your profile show you.")
            }

            if let user = auth.user {
                Section("Account") {
                    LabeledContent("Email", value: user.email ?? "—")
                    if let method = user.providerName {
                        LabeledContent("Signed in with", value: method)
                    }
                    if user.usesPassword, let email = user.email {
                        Button("Change password") { sendReset(to: email) }.disabled(busy)
                    }
                    Button("Sign out") { Task { await auth.signOut() } }
                }
                Section {
                    Button("Delete account", role: .destructive) { confirmDelete = true }.disabled(busy)
                } header: {
                    Text("Danger zone")
                } footer: {
                    Text("Deletes your account and profile permanently. Your alarms and progress stay on this iPhone.")
                }
            } else {
                Section {
                    Button {
                        showSignIn = true
                    } label: {
                        Label("Sign in or create account", systemImage: "person.crop.circle.badge.plus")
                    }
                } footer: {
                    Text("Optional. Your alarms work without an account.")
                }
            }

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = profile.name }
        .onDisappear(perform: saveName)
        .task(id: auth.user?.id) { await loadRemoteName() }
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

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != profile.name else { return }
        profile.set(trimmed)
        if auth.user != nil {
            Task { await auth.updateProfile(ProfileUpdate(displayName: trimmed.isEmpty ? nil : trimmed)) }
        }
    }

    /// After sign-in on a new iPhone: take the name from the account when none is set here.
    private func loadRemoteName() async {
        guard auth.user != nil, profile.name.isEmpty,
              let remote = await auth.loadProfile()?.displayName, !remote.isEmpty else { return }
        profile.set(remote)
        name = remote
    }

    private func sendReset(to email: String) {
        busy = true
        Task {
            do {
                try await auth.resetPassword(email: email)
                message = "We sent a link to \(email) to choose a new password."
            } catch {
                message = error.localizedDescription
            }
            busy = false
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
}
