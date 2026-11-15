import Account
import Buddies
import Core
import Purchases
import SwiftData
import SwiftUI
import Telemetry

/// Buddies tab: your clubs, plus create / join / discover. Needs an account.
struct BuddiesView: View {
    let auth: any AuthService
    let store: StoreService
    @Environment(BuddiesModel.self) private var model
    @Query private var logs: [DayLog]

    @State private var showSignIn = false
    @State private var sheet: Sheet?
    @State private var showPaywall = false
    @State private var path: [Club] = []

    enum Sheet: Identifiable {
        case create, join(String?), share
        var id: String {
            switch self {
            case .create: "create"
            case .join: "join"
            case .share: "share"
            }
        }
    }

    private var missionDoneToday: Bool {
        logs.contains { $0.missionCompletedAt.map(Calendar.current.isDateInToday) ?? false }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !model.service.isAvailable {
                    ContentUnavailableView("Buddies isn't available", systemImage: "person.3",
                                           description: Text("This build has no account server configured."))
                } else if !model.isSignedIn(auth.user?.id) {
                    signedOut
                } else if !model.rulesAccepted {
                    CommunityRulesView { model.acceptRules() }
                } else if model.clubs.isEmpty {
                    if model.loaded { empty } else { ProgressView() }
                } else {
                    clubList
                }
            }
            .navigationTitle("Buddies")
        .trackScreen("Buddies")
            .navigationDestination(for: Club.self) { club in
                ClubView(clubID: club.id, auth: auth)
            }
            .toolbar {
                if model.isSignedIn(auth.user?.id), model.rulesAccepted, !model.clubs.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button { startCreate() } label: { Label("Create a club", systemImage: "plus") }
                            Button { sheet = .join(nil) } label: { Label("Join with a code", systemImage: "number") }
                            NavigationLink { DiscoverClubsView() } label: { Label("Discover clubs", systemImage: "magnifyingglass") }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add a club")
                    }
                }
            }
        }
        .task(id: auth.user?.id) {
            await model.refresh(signedIn: model.isSignedIn(auth.user?.id))
            // Screenshot helper: -buddiesSample -buddiesClub opens the first club.
            if model.sampleMode, CommandLine.arguments.contains("-buddiesClub"), let first = model.clubs.first {
                path = [first]
            }
        }
        .refreshable { await model.refresh(signedIn: model.isSignedIn(auth.user?.id)) }
        .onChange(of: model.pendingJoinCode, initial: true) { _, code in openPendingJoin(code) }
        .onChange(of: model.rulesAccepted) { openPendingJoin(model.pendingJoinCode) }
        .onChange(of: auth.user) { _, user in
            if user != nil { showSignIn = false }
            openPendingJoin(model.pendingJoinCode)
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create:
                CreateClubView(existing: nil) { id in open(id) }
            case .join(let code):
                JoinClubView(initialCode: code ?? "") { id in open(id) }
            case .share:
                ShareMorningView()
            }
        }
        .sheet(isPresented: $showSignIn) {
            AccountStepView(auth: auth, skipTitle: "Not now") { showSignIn = false }
                .presentationDragIndicator(.visible)
        }
        .paywallSheet(isPresented: $showPaywall, source: .createClub)
    }

    // MARK: States

    private var signedOut: some View {
        ScrollView {
            VStack(spacing: 22) {
                BuddiesHero()
                VStack(alignment: .leading, spacing: 14) {
                    feature("person.3.fill", "Clubs", "Make a club with friends, family or your gym, or join a public one.")
                    feature("trophy.fill", "Weekly ranking", "Earn points every morning. The board resets on Monday.")
                    feature("camera.fill", "Morning face", "Share a selfie after your mission. Gone after 24 hours.")
                }
                .padding(.horizontal, 8)
                Button {
                    showSignIn = true
                } label: {
                    Text("Sign in to join your buddies").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Your alarms keep working without an account.").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var empty: some View {
        ScrollView {
            VStack(spacing: 18) {
                BuddiesHero()
                ActionCard(symbol: "plus.circle.fill", tint: .orange, title: "Create a club",
                           subtitle: "Invite friends with a code or link.") { startCreate() }
                ActionCard(symbol: "number.circle.fill", tint: .blue, title: "Join with a code",
                           subtitle: "Got an invite? Enter the 8-character code.") { sheet = .join(nil) }
                NavigationLink {
                    DiscoverClubsView()
                } label: {
                    ActionCardLabel(symbol: "magnifyingglass.circle.fill", tint: .green, title: "Discover clubs",
                                    subtitle: "Find public clubs like the 5 AM Club.")
                }
                .buttonStyle(.plain)
                if let error = model.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var clubList: some View {
        List {
            if model.shouldPromptPhoto(missionDoneToday: missionDoneToday) {
                Section {
                    Button { sheet = .share } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill").font(.title2).foregroundStyle(.white)
                                .frame(width: 48, height: 48).background(Color.orange.gradient, in: .circle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share your morning face").font(.headline).foregroundStyle(.primary)
                                Text("Post or skip to see your buddies' photos").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            Section {
                ForEach(model.clubs) { club in
                    NavigationLink(value: club) { ClubCard(club: club) }
                }
            } header: {
                Text("Your clubs")
            }
            if let error = model.error {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }
        }
    }

    // MARK: Actions

    private func startCreate() {
        if ClubRules.canCreate(ownedCount: model.ownedClubCount, isPro: store.entitlement.isPro) {
            sheet = .create
        } else {
            showPaywall = true
        }
    }

    private func open(_ id: UUID) {
        Task {
            await model.refresh(signedIn: model.isSignedIn(auth.user?.id))
            if let club = model.clubs.first(where: { $0.id == id }) { path = [club] }
        }
    }

    private func openPendingJoin(_ code: String?) {
        guard let code else { return }
        if !model.isSignedIn(auth.user?.id) {
            showSignIn = model.service.isAvailable
            return
        }
        guard model.rulesAccepted else { return }
        model.pendingJoinCode = nil
        sheet = .join(code)
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.orange).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Pieces

struct BuddiesHero: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: -14) {
                ForEach(Array(["🌅", "💪", "⏰"].enumerated()), id: \.offset) { index, emoji in
                    Text(emoji).font(.system(size: 34))
                        .frame(width: 68, height: 68)
                        .background(Color.orange.opacity(0.15 + Double(index) * 0.08), in: .circle)
                        .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 3))
                }
            }
            .accessibilityHidden(true)
            Text("Wake up together").font(.title.bold())
            Text("Keep each other honest. Who's up, who's still snoozing, and who's leading this week.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}

struct ActionCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionCardLabel(symbol: symbol, tint: tint, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

struct ActionCardLabel: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(tint).frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .contentShape(.rect)
    }
}

struct ClubCard: View {
    let club: Club

    var body: some View {
        HStack(spacing: 14) {
            Text(club.emoji).font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Color.orange.opacity(0.15), in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(club.name).font(.headline).lineLimit(1)
                    if club.isPublic {
                        Image(systemName: "globe").font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel("Public")
                    }
                }
                Text("\(club.upToday)/\(club.memberCount) up today")
                    .font(.subheadline).foregroundStyle(club.upToday > 0 ? .orange : .secondary)
                ProgressView(value: Double(club.upToday), total: Double(max(1, club.memberCount)))
                    .tint(.orange)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
