import Account
import Buddies
import SwiftUI
import Telemetry

/// Settings › Buddies: wake-up time privacy, blocked people, community rules.
struct BuddiesSettingsView: View {
    let auth: any AuthService
    @Environment(BuddiesModel.self) private var model
    @State private var sharesTime = true
    @State private var blocked: [BlockedUser] = []
    @State private var loaded = false

    var body: some View {
        List {
            if auth.user == nil {
                Section {
                    Text("Sign in to use Buddies.").foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Toggle("Show my wake-up time", isOn: Binding(get: { sharesTime }, set: { setShare($0) }))
                        .disabled(!loaded)
                } footer: {
                    Text("Off: your clubs only see that you're up, not when. Points and streak still count.")
                }
                Section {
                    if blocked.isEmpty {
                        Text("Nobody blocked.").foregroundStyle(.secondary)
                    }
                    ForEach(blocked) { user in
                        HStack {
                            BuddyAvatar(name: user.displayName, size: 30)
                            Text(buddyName(user.displayName))
                            Spacer()
                            Button("Unblock") { unblock(user) }.buttonStyle(.bordered)
                        }
                    }
                } header: {
                    Text("Blocked")
                } footer: {
                    Text("Blocked people can't see your photos, time or ranking, and you don't see theirs.")
                }
            }
            Section {
                NavigationLink("Community rules") {
                    CommunityRulesView(showsAgree: false) {}.navigationBarTitleDisplayMode(.inline)
                }
            }
            if let error = model.error {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Buddies")
        .trackScreen("Settings.Buddies")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: auth.user?.id) { await load() }
    }

    private func load() async {
        guard auth.user != nil else { return }
        await model.perform {
            sharesTime = try await model.service.shareWakeTime()
            blocked = try await model.service.blockedUsers()
        }
        loaded = true
    }

    private func setShare(_ on: Bool) {
        sharesTime = on
        Task {
            if !(await model.perform { try await model.service.setShareWakeTime(on) }) { sharesTime = !on }
        }
    }

    private func unblock(_ user: BlockedUser) {
        Task {
            if await model.perform({ try await model.service.unblock(user.userID) }) {
                blocked.removeAll { $0.id == user.id }
            }
        }
    }
}
