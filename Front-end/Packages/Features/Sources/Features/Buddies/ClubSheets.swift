import Buddies
import SwiftUI
import Telemetry

/// Create a club, or edit one you own.
struct CreateClubView: View {
    let existing: Club?
    var onDone: (UUID) -> Void = { _ in }
    @Environment(BuddiesModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ClubDraft()
    @State private var busy = false
    @State private var problem: String?

    static let emojis = ["⏰", "🌅", "☀️", "🐓", "🐦", "💪", "🏋️", "🏃", "🧘", "📚", "🎓", "💼",
                         "☕️", "🔥", "🚀", "⭐️", "🦁", "🐺", "🏠", "❤️"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(Self.emojis, id: \.self) { emoji in
                            Button { draft.emoji = emoji } label: {
                                Text(emoji).font(.system(size: 28))
                                    .frame(width: 50, height: 50)
                                    .background(draft.emoji == emoji ? Color.orange.opacity(0.25) : .clear, in: .rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(draft.emoji == emoji ? Color.orange : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(emoji)
                            .accessibilityAddTraits(draft.emoji == emoji ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Icon")
                }
                Section("Club") {
                    TextField("Name, e.g. Early birds", text: $draft.name)
                    TextField("What's it about? (optional)", text: $draft.description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Toggle("Public club", isOn: $draft.isPublic)
                } footer: {
                    Text(draft.isPublic
                         ? "Anyone can find this club in Discover and join. Keep the name friendly."
                         : "Only people with your invite code or link can join.")
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
            }
            .navigationTitle(existing == nil ? "New club" : "Edit club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "Create" : "Save", action: save)
                        .disabled(busy || draft.name.trimmingCharacters(in: .whitespaces).count < 2)
                }
            }
            .onAppear {
                if let existing {
                    draft = ClubDraft(name: existing.name, description: existing.description, emoji: existing.emoji,
                                      isPublic: existing.isPublic)
                }
            }
        }
    }

    private func save() {
        if let issue = ClubRules.validate(draft) {
            problem = issue.message
            return
        }
        busy = true
        Task {
            var id: UUID?
            let ok = await model.perform {
                if let existing {
                    try await model.service.updateClub(existing.id, draft)
                    id = existing.id
                } else {
                    id = try await model.service.createClub(draft)
                    Telemetry.shared.send(.action(.clubCreated(isPublic: draft.isPublic)))
                }
            }
            busy = false
            if ok, let id {
                dismiss()
                onDone(id)
            } else {
                problem = model.error
            }
        }
    }
}

/// Enter an invite code (also opened by `gloop://join/<code>`).
struct JoinClubView: View {
    var initialCode = ""
    var onJoined: (UUID) -> Void = { _ in }
    @Environment(BuddiesModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "number.circle.fill").font(.system(size: 54)).foregroundStyle(.orange)
                    .padding(.top, 30)
                Text("Join a club").font(.title.bold())
                Text("Enter the code a member shared with you.").foregroundStyle(.secondary)
                TextField("ABCD-2345", text: $code)
                    .font(.system(.title, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
                    .onSubmit(join)
                if let problem {
                    Text(problem).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button(action: join) {
                    Text(busy ? "Joining…" : "Join").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy || InviteCode.normalize(code) == nil)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 480)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                code = initialCode.isEmpty ? "" : InviteCode.display(InviteCode.normalize(initialCode) ?? initialCode)
                focused = initialCode.isEmpty
            }
        }
        .presentationDetents([.large])
    }

    private func join() {
        guard InviteCode.normalize(code) != nil else {
            problem = "Codes have 8 letters and numbers, like ABCD-2345."
            return
        }
        busy = true
        Task {
            var id: UUID?
            let ok = await model.perform { id = try await model.service.joinClub(code: code) }
            if ok { Telemetry.shared.send(.action(.clubJoined(via: initialCode.isEmpty ? "code" : "link"))) }
            busy = false
            if ok, let id {
                dismiss()
                onJoined(id)
            } else {
                problem = model.error
            }
        }
    }
}

/// Search public clubs and join them.
struct DiscoverClubsView: View {
    @Environment(BuddiesModel.self) private var model
    @State private var query = ""
    @State private var results: [DiscoverClub] = []
    @State private var searching = false
    @State private var joining: UUID?

    var body: some View {
        List {
            ForEach(results) { club in
                HStack(spacing: 12) {
                    Text(club.emoji).font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(Color.orange.opacity(0.15), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(club.name).font(.headline)
                        if !club.description.isEmpty {
                            Text(club.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Text("\(club.memberCount) member\(club.memberCount == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if club.isMember {
                        Label("Joined", systemImage: "checkmark").labelStyle(.iconOnly).foregroundStyle(.green)
                            .accessibilityLabel("Joined")
                    } else {
                        Button(joining == club.id ? "…" : "Join") { join(club) }
                            .buttonStyle(.bordered)
                            .disabled(joining != nil)
                    }
                }
                .contextMenu {
                    Button("Report club", systemImage: "flag") {
                        Task { await model.perform { try await model.service.report(.club, id: club.id, reason: "Discover") } }
                    }
                }
            }
            if results.isEmpty && !searching {
                ContentUnavailableView(query.isEmpty ? "No public clubs yet" : "No clubs found",
                                       systemImage: "magnifyingglass",
                                       description: Text("Create one and make it public so others can join."))
            }
            if let error = model.error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .navigationTitle("Discover clubs")
        .searchable(text: $query, prompt: "Club name")
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))  // debounce typing
            guard !Task.isCancelled else { return }
            await search()
        }
        .refreshable { await search() }
        .overlay { if searching && results.isEmpty { ProgressView() } }
    }

    private func search() async {
        searching = true
        defer { searching = false }
        var found: [DiscoverClub] = []
        if await model.perform({ found = try await model.service.searchPublicClubs(query) }) {
            results = found
        }
    }

    private func join(_ club: DiscoverClub) {
        joining = club.id
        Task {
            if await model.perform({ try await model.service.joinPublicClub(club.id) }) {
                Telemetry.shared.send(.action(.clubJoined(via: "discover")))
                if let i = results.firstIndex(where: { $0.id == club.id }) {
                    results[i].isMember = true
                    results[i].memberCount += 1
                }
                await model.refresh(signedIn: true)
            }
            joining = nil
        }
    }
}

/// One-time rules before using Buddies (App Review 1.2: user-generated content).
struct CommunityRulesView: View {
    var showsAgree = true
    let onAgree: () -> Void

    static let rules: [(String, String, String)] = [
        ("heart.fill", "Be kind", "Cheer each other on. No bullying, harassment or hate."),
        ("eye.slash.fill", "Keep it clean", "Morning faces only: no nudity, violence or anything you wouldn't show a friend's mum."),
        ("hand.raised.fill", "Respect privacy", "Only share photos of yourself. Don't screenshot others' photos to post elsewhere."),
        ("flag.fill", "Report & block", "Long-press any photo or person to report or block them. We review reports and remove people who break the rules."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Community rules").font(.largeTitle.bold())
                Text("Buddies is about motivating each other. A few rules keep it that way:")
                    .foregroundStyle(.secondary)
                ForEach(Self.rules, id: \.1) { symbol, title, text in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: symbol).font(.title3).foregroundStyle(.orange).frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.headline)
                            Text(text).font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("Breaking these rules can get your content removed and your account blocked from Buddies.")
                NavigationLink {
                    LegalDocumentView(kind: .community)
                } label: {
                    Label("Read the full Community Guidelines", systemImage: "doc.text")
                }
                .font(.subheadline.weight(.semibold))
                    .font(.footnote).foregroundStyle(.secondary)
                if showsAgree {
                    Button(action: onAgree) {
                        Text("I agree").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
                }
            }
            .padding(24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}
