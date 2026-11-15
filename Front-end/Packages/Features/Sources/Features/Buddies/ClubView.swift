import Account
import Buddies
import Coach
import CoreImage.CIFilterBuiltins
import SwiftUI
import WidgetShared

/// One club: who's up today + morning photos, the leaderboard, and members / invite.
struct ClubView: View {
    let clubID: UUID
    let auth: any AuthService
    @Environment(BuddiesModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case today = "Today", ranking = "Ranking", members = "Members"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .today
    @State private var members: [MemberToday] = []
    @State private var posts: [MorningPost] = []
    @State private var imageURLs: [String: URL] = [:]
    @State private var rows: [LeaderboardRow] = []
    @State private var period: LeaderboardRanking.Period = .week
    @State private var loading = true
    @State private var showShare = false
    @State private var editing = false
    @State private var reportTarget: ReportTarget?
    @State private var confirm: Confirm?
    @State private var viewing: MorningPost?

    struct ReportTarget: Identifiable {
        let kind: ReportKind
        let id: UUID
        let userID: UUID?
        let name: String
    }

    enum Confirm: Identifiable {
        case leave, delete, remove(MemberToday), newCode
        var id: String {
            switch self {
            case .leave: "leave"
            case .delete: "delete"
            case .remove(let m): "remove-\(m.userID)"
            case .newCode: "code"
            }
        }
    }

    private var club: Club? { model.clubs.first { $0.id == clubID } }

    var body: some View {
        List {
            if let club {
                Section {
                    header(club)
                    Picker("Section", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                }
                switch tab {
                case .today: todaySections
                case .ranking: rankingSections
                case .members: memberSections(club)
                }
                if let error = model.error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }
            } else if !loading {
                ContentUnavailableView("Club not found", systemImage: "person.3",
                                       description: Text("You may have left it, or it was deleted."))
            }
        }
        .navigationTitle(club?.name ?? "Club")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if loading && members.isEmpty { ProgressView() } }
        .task(id: tab) { await load() }
        .refreshable { await load() }
        .toolbar {
            if let club {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: InviteCode.link(club.inviteCode),
                              message: Text(InviteCode.shareText(club: club.name, code: club.inviteCode))) {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Invite")
                }
            }
        }
        .sheet(isPresented: $showShare, onDismiss: { Task { await load() } }) { ShareMorningView() }
        .sheet(isPresented: $editing, onDismiss: { Task { await model.refresh(signedIn: true) } }) {
            CreateClubView(existing: club)
        }
        .sheet(item: $viewing) { post in
            PhotoViewer(post: post, url: post.imagePath.flatMap { imageURLs[$0] }) { emoji in react(post, emoji) }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { await load() }
        }
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible, presenting: confirm) { item in
            switch item {
            case .leave:
                Button("Leave club", role: .destructive) { run { try await model.service.leaveClub(clubID) } then: { dismiss() } }
            case .delete:
                Button("Delete club", role: .destructive) { run { try await model.service.deleteClub(clubID) } then: { dismiss() } }
            case .remove(let member):
                Button("Remove \(buddyName(member.displayName))", role: .destructive) {
                    run { try await model.service.removeMember(member.userID, from: clubID) }
                }
            case .newCode:
                Button("Make a new code") { run { _ = try await model.service.regenerateInvite(clubID) } }
            }
        } message: { item in
            switch item {
            case .leave: Text(club?.isOwner == true ? "The longest-standing member becomes the owner." : "You can join again with the code.")
            case .delete: Text("The club, its ranking and photos are deleted for everyone.")
            case .remove: Text("They can only come back with a new invite.")
            case .newCode: Text("The old code and link stop working.")
            }
        }
    }

    private var confirmTitle: String {
        switch confirm {
        case .leave: "Leave this club?"
        case .delete: "Delete this club?"
        case .remove: "Remove member?"
        case .newCode: "New invite code?"
        case nil: ""
        }
    }

    private func header(_ club: Club) -> some View {
        HStack(spacing: 14) {
            Text(club.emoji).font(.system(size: 36))
                .frame(width: 64, height: 64)
                .background(Color.orange.opacity(0.15), in: .rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(club.name).font(.title3.bold())
                if !club.description.isEmpty {
                    Text(club.description).font(.subheadline).foregroundStyle(.secondary)
                }
                Label(club.isPublic ? "Public · \(club.memberCount) members" : "Private · \(club.memberCount) members",
                      systemImage: club.isPublic ? "globe" : "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Today

    @ViewBuilder
    private var todaySections: some View {
        let unlocked = FeedGate.isUnlocked(myPhotoState: model.myPhotoState)
        Section {
            if posts.isEmpty {
                Text("No morning faces yet today.").foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(posts) { post in
                            PhotoTile(post: post, url: post.imagePath.flatMap { imageURLs[$0] })
                                .onTapGesture { if !post.locked { viewing = post } else { showShare = true } }
                                .contextMenu { safetyMenu(userID: post.userID, name: post.displayName, isMe: post.isMe, post: post.id) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            if !unlocked {
                Button { showShare = true } label: {
                    Label(posts.isEmpty ? "Share your morning face" : "Post or skip to see their photos",
                          systemImage: "camera.fill")
                }
            }
        } header: {
            Text("Morning faces")
        } footer: {
            Text("Photos disappear after 24 hours.")
        }

        Section {
            ForEach(sortedMembers) { member in
                MemberTodayRow(member: member)
                    .contextMenu { safetyMenu(userID: member.userID, name: member.displayName, isMe: member.isMe, post: nil) }
            }
        } header: {
            let up = members.filter(\.isUp).count
            Text("\(up) of \(members.count) up")
        }
    }

    private var sortedMembers: [MemberToday] {
        members.sorted {
            switch ($0.completedAt, $1.completedAt) {
            case let (a?, b?): a < b
            case (_?, nil): true
            case (nil, _?): false
            default: buddyName($0.displayName) < buddyName($1.displayName)
            }
        }
    }

    // MARK: Ranking

    @ViewBuilder
    private var rankingSections: some View {
        let ranked = LeaderboardRanking.rank(rows, by: period)
        Section {
            Picker("Period", selection: $period) {
                ForEach(LeaderboardRanking.Period.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if ranked.count >= 2 {
                Podium(entries: Array(ranked.prefix(3)))
                    .listRowSeparator(.hidden)
            }
        } footer: {
            Text(period == .week ? "Points this week (XP from your mornings). Resets every Monday." : "All XP since joining Gloop.")
        }
        Section {
            ForEach(ranked) { entry in
                LeaderboardRowView(entry: entry)
                    .contextMenu { safetyMenu(userID: entry.row.userID, name: entry.row.displayName, isMe: entry.row.isMe, post: nil) }
            }
        }
    }

    // MARK: Members

    @ViewBuilder
    private func memberSections(_ club: Club) -> some View {
        Section {
            InviteCard(club: club)
        } header: {
            Text("Invite")
        }
        Section("Members") {
            ForEach(members.sorted { ($0.role == .owner ? 0 : 1, buddyName($0.displayName)) < ($1.role == .owner ? 0 : 1, buddyName($1.displayName)) }) { member in
                HStack {
                    BuddyAvatar(name: member.displayName, size: 34)
                    Text(buddyName(member.displayName) + (member.isMe ? " (you)" : ""))
                    Spacer()
                    if member.role == .owner {
                        Text("Owner").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
                .swipeActions {
                    if club.isOwner && !member.isMe {
                        Button("Remove", role: .destructive) { confirm = .remove(member) }
                    }
                }
                .contextMenu {
                    if club.isOwner && !member.isMe {
                        Button("Remove from club", systemImage: "person.fill.xmark", role: .destructive) { confirm = .remove(member) }
                    }
                    safetyMenu(userID: member.userID, name: member.displayName, isMe: member.isMe, post: nil)
                }
            }
        }
        if club.isOwner {
            Section("Owner") {
                Button("Edit club") { editing = true }
                Button("New invite code") { confirm = .newCode }
                Button("Delete club", role: .destructive) { confirm = .delete }
            }
        }
        Section {
            Button("Leave club", role: .destructive) { confirm = .leave }
            if !club.isOwner {
                Button("Report club", role: .destructive) {
                    reportTarget = ReportTarget(kind: .club, id: club.id, userID: nil, name: club.name)
                }
            }
        }
    }

    @ViewBuilder
    private func safetyMenu(userID: UUID, name: String?, isMe: Bool, post: UUID?) -> some View {
        if !isMe {
            if let post {
                Button("Report photo", systemImage: "flag") {
                    reportTarget = ReportTarget(kind: .post, id: post, userID: userID, name: buddyName(name))
                }
            }
            Button("Report \(buddyName(name))", systemImage: "exclamationmark.bubble") {
                reportTarget = ReportTarget(kind: .user, id: userID, userID: userID, name: buddyName(name))
            }
            Button("Block \(buddyName(name))", systemImage: "hand.raised", role: .destructive) {
                run { try await model.service.block(userID) }
            }
        }
    }

    // MARK: Data

    private func load() async {
        loading = true
        defer { loading = false }
        await model.refresh(signedIn: model.isSignedIn(auth.user?.id))
        guard club != nil else { return }
        await model.perform {
            switch tab {
            case .today, .members:
                members = try await model.service.today(club: clubID, day: model.today)
                if tab == .today {
                    posts = try await model.service.feed(club: clubID, day: model.today)
                    imageURLs = try await model.service.imageURLs(posts.compactMap(\.imagePath))
                }
            case .ranking:
                rows = try await model.service.leaderboard(club: clubID, weekStart: model.weekStart)
            }
        }
    }

    private func react(_ post: MorningPost, _ emoji: String?) {
        run { try await model.service.react(to: post.id, emoji: emoji) }
    }

    private func run(_ work: @escaping () async throws -> Void, then: @escaping () -> Void = {}) {
        Task {
            if await model.perform(work) {
                await load()
                then()
            }
        }
    }
}

// MARK: - Rows & tiles

struct BuddyAvatar: View {
    let name: String?
    var size: CGFloat = 40

    var body: some View {
        let text = buddyName(name)
        Text(String(text.prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Self.color(for: text).gradient, in: .circle)
            .accessibilityHidden(true)
    }

    static func color(for name: String) -> Color {
        let palette: [Color] = [.orange, .blue, .green, .purple, .pink, .teal, .indigo, .red]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

struct MemberTodayRow: View {
    let member: MemberToday

    var body: some View {
        HStack(spacing: 12) {
            BuddyAvatar(name: member.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(buddyName(member.displayName) + (member.isMe ? " (you)" : "")).font(.body.weight(.semibold))
                Text(status).font(.subheadline).foregroundStyle(member.isUp ? .primary : .secondary)
            }
            Spacer()
            if member.streak > 0 {
                Text("\(Image(systemName: "flame.fill")) \(member.streak)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                    .accessibilityLabel("\(member.streak)-day streak")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        guard let done = member.completedAt else { return "Still sleeping 😴" }
        guard member.sharesTime else { return "Up ✓" }
        var text = "Up at " + done.formatted(date: .omitted, time: .shortened)
        if let rings = member.rings {
            text += rings <= 1 ? " · first ring 🔥" : " · \(rings) rings"
        }
        return text
    }
}

struct PhotoTile: View {
    let post: MorningPost
    let url: URL?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.15))
                if post.locked {
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.title2)
                        Text("Post to see").font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.orange)
                } else if let url {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 146)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                if let top = post.reactions.max(by: { $0.value < $1.value }) {
                    Text("\(top.key) \(post.reactions.values.reduce(0, +))")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(6)
                }
            }
            Text(buddyName(post.displayName) + (post.isMe ? " (you)" : "")).font(.caption).lineLimit(1)
        }
        .frame(width: 110)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.locked ? "Locked photo from \(buddyName(post.displayName))"
                                        : "Morning photo from \(buddyName(post.displayName))")
    }
}

struct PhotoViewer: View {
    let post: MorningPost
    let url: URL?
    let onReact: (String?) -> Void
    @State private var mine: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                BuddyAvatar(name: post.displayName, size: 34)
                VStack(alignment: .leading) {
                    Text(buddyName(post.displayName)).font(.headline)
                    Text(post.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
            .clipShape(.rect(cornerRadius: 20))
            if !post.isMe {
                HStack(spacing: 10) {
                    ForEach(MorningPost.reactionChoices, id: \.self) { emoji in
                        Button {
                            mine = mine == emoji ? nil : emoji
                            onReact(mine)
                        } label: {
                            Text(emoji).font(.system(size: 30))
                                .frame(width: 54, height: 54)
                                .background(mine == emoji ? Color.orange.opacity(0.3) : Color(.secondarySystemBackground), in: .circle)
                        }
                        .accessibilityLabel("React \(emoji)")
                    }
                }
            } else if !post.reactions.isEmpty {
                Text(post.reactions.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: "   "))
                    .font(.title3)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .onAppear { mine = post.myReaction }
        .presentationDragIndicator(.visible)
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardRanking.Entry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.position)").font(.headline.monospacedDigit()).frame(width: 28)
                .foregroundStyle(entry.position <= 3 ? .orange : .secondary)
            BuddyAvatar(name: entry.row.displayName, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(buddyName(entry.row.displayName) + (entry.row.isMe ? " (you)" : ""))
                    .font(.body.weight(entry.row.isMe ? .bold : .regular))
                HStack(spacing: 4) {
                    if let rank = entry.row.coachRank {
                        RankInsignia(rank: rank, size: 14)
                        Text(rank.title)
                    }
                    if entry.row.streak > 0 {
                        Text("· \(Image(systemName: "flame.fill")) \(entry.row.streak)")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.points) XP").font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .listRowBackground(entry.row.isMe ? Color.orange.opacity(0.1) : nil)
        .accessibilityElement(children: .combine)
    }
}

struct Podium: View {
    let entries: [LeaderboardRanking.Entry]

    var body: some View {
        // 2nd · 1st · 3rd
        let order = [1, 0, 2].compactMap { entries.indices.contains($0) ? entries[$0] : nil }
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(order) { entry in
                VStack(spacing: 6) {
                    if entry.position == 1 { Text("👑").font(.title2) }
                    BuddyAvatar(name: entry.row.displayName, size: entry.position == 1 ? 58 : 46)
                    Text(buddyName(entry.row.displayName)).font(.caption.weight(.semibold)).lineLimit(1)
                    Text("\(entry.points) XP").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.gradient.opacity(entry.position == 1 ? 1 : 0.6))
                        .frame(height: entry.position == 1 ? 70 : entry.position == 2 ? 50 : 36)
                        .overlay(Text("\(entry.position)").font(.title3.bold()).foregroundStyle(.white))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct InviteCard: View {
    let club: Club
    @State private var showQR = false

    var body: some View {
        VStack(spacing: 12) {
            Text(InviteCode.display(club.inviteCode))
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .textSelection(.enabled)
                .accessibilityLabel("Invite code \(club.inviteCode.map(String.init).joined(separator: " "))")
            HStack(spacing: 12) {
                ShareLink(item: InviteCode.link(club.inviteCode),
                          message: Text(InviteCode.shareText(club: club.name, code: club.inviteCode))) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                Button { showQR.toggle() } label: { Label("QR code", systemImage: "qrcode") }
                    .buttonStyle(.bordered)
            }
            if showQR, let image = InviteQR.image(for: InviteCode.link(club.inviteCode).absoluteString) {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(10).background(.white, in: .rect(cornerRadius: 12))
                    .accessibilityLabel("QR code for the invite link")
                Text("Scan with the iPhone camera to join.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

enum InviteQR {
    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Why are you reporting? + optional block.
struct ReportSheet: View {
    let target: ClubView.ReportTarget
    let onDone: () async -> Void
    @Environment(BuddiesModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Inappropriate photo"
    @State private var details = ""
    @State private var alsoBlock = true
    @State private var busy = false
    @State private var sent = false

    static let reasons = ["Inappropriate photo", "Harassment or bullying", "Hate or violence", "Spam or fake", "Something else"]

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label("Thanks. We'll review this within 24 hours.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section("What's wrong?") {
                        Picker("Reason", selection: $reason) {
                            ForEach(Self.reasons, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        TextField("More details (optional)", text: $details, axis: .vertical).lineLimit(2...5)
                    }
                    if target.userID != nil {
                        Section {
                            Toggle("Also block \(target.name)", isOn: $alsoBlock)
                        } footer: {
                            Text("You won't see each other's photos, times or ranking anymore.")
                        }
                    }
                }
            }
            .navigationTitle("Report \(target.kind == .club ? "club" : target.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(sent ? "Done" : "Cancel") { dismiss() } }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send", action: send).disabled(busy)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func send() {
        busy = true
        Task {
            let text = details.isEmpty ? reason : "\(reason): \(details)"
            let ok = await model.perform {
                try await model.service.report(target.kind, id: target.id, reason: text)
                if alsoBlock, let user = target.userID { try await model.service.block(user) }
            }
            busy = false
            if ok {
                sent = true
                await onDone()
            }
        }
    }
}
