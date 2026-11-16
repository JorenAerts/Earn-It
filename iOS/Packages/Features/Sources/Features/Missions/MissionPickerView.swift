import Core
import Localization
import Missions
import Permissions
import Purchases
import SwiftUI
import Telemetry

/// "Add mission" sheet: a card per mission (what you do, how long, what it needs), locked ones
/// show PRO. Picking one opens its setup page (difficulty, amount, or the guided scan) → "Add to alarm".
struct MissionPickerView: View {
    let gate: FeatureGate
    let onAdd: (MissionConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var path: [MissionKind] = []
    /// nil = All.
    @State private var category: MissionCategory?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CategoryChips(selection: $category)
                    ForEach(category.map { [$0] } ?? MissionCategory.allCases) { folder in
                        if !folder.kinds.isEmpty {
                            if category == nil {
                                Label(folder.title, systemImage: folder.symbol)
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                    .padding(.top, 6).padding(.leading, 4)
                            }
                            ForEach(folder.kinds) { kind in
                                Button {
                                    if gate.isLocked(kind) { showPaywall = true } else { path.append(kind) }
                                } label: {
                                    MissionKindCard(kind: kind, locked: gate.isLocked(kind))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add a mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .navigationDestination(for: MissionKind.self) { kind in
                MissionSetupPage(kind: kind) { config in
                    onAdd(config)
                    dismiss()
                }
            }
        }
        .paywallSheet(isPresented: $showPaywall, source: .lockedMission)
    }
}

/// Folder filter: All · Brain · Body · Out of bed · Mindset (empty folders are hidden).
struct CategoryChips: View {
    @Binding var selection: MissionCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(L10n.tr("All"), symbol: "square.grid.2x2.fill", selected: selection == nil) { selection = nil }
                ForEach(MissionCategory.allCases.filter { !$0.kinds.isEmpty }) { folder in
                    chip(folder.title, symbol: folder.symbol, selected: selection == folder) { selection = folder }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.snappy) { action() } }) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(selected ? Color.orange : Color(.secondarySystemGroupedBackground), in: .capsule)
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One mission in the picker.
struct MissionKindCard: View {
    let kind: MissionKind
    var locked = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MissionIcon(kind: kind, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(kind.displayName).font(.headline)
                    Spacer()
                    if locked { ProBadge() }
                }
                Text(kind.tagline).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Tag(text: kind.estimatedDuration, symbol: "clock")
                    if kind.needsCamera {
                        if PermissionCenter.shared.status(.camera) == .denied {
                            Tag(text: L10n.tr("Camera off"), symbol: "exclamationmark.triangle.fill")
                        } else {
                            Tag(text: L10n.tr("Camera"), symbol: "camera.fill")
                        }
                    }
                    if kind.needsSetup { Tag(text: L10n.tr("Setup"), symbol: "wrench.and.screwdriver.fill") }
                    if kind.usesDifficulty { Tag(text: L10n.tr("Difficulty"), symbol: "slider.horizontal.3") }
                }
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .opacity(locked ? 0.8 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(locked ? "Requires Gloop Pro" : "Opens setup")
    }
}

private struct Tag: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: .capsule)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }
}

/// Mission icon in a rounded square, also used in editor rows and the mission screen.
struct MissionIcon: View {
    let kind: MissionKind
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [.orange, .red.opacity(0.85)], startPoint: .top, endPoint: .bottom),
                        in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

/// Setup page after picking a mission: what it is, its options, then "Add to alarm".
struct MissionSetupPage: View {
    let onAdd: (MissionConfig) -> Void
    @State private var config: MissionConfig

    init(kind: MissionKind, onAdd: @escaping (MissionConfig) -> Void) {
        self.onAdd = onAdd
        _config = State(initialValue: MissionConfig(kind: kind))
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    MissionIcon(kind: config.kind, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.kind.displayName).font(.title3.bold())
                        Text(config.kind.tagline).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            MissionOptionsSection(config: $config)
        }
        .navigationTitle(config.kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { onAdd(config) } label: {
                Text(config.isReady ? L10n.tr("Add to alarm") : L10n.tr("Finish setup to add")).font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!config.isReady)
            .padding(16)
            .background(.bar)
        }
    }
}

/// Difficulty, amount and mission-specific setup. Shared by the setup page and the edit sheet.
struct MissionOptionsSection: View {
    @Binding var config: MissionConfig

    var body: some View {
        if config.kind.usesDifficulty || config.kind.targetRange != nil {
            Section("Settings") {
                if config.kind.usesDifficulty {
                    Picker("Difficulty", selection: $config.difficulty) {
                        ForEach(MissionDifficulty.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if let range = config.kind.targetRange {
                    Stepper(config.kind.targetText(config.target), value: $config.target,
                            in: range, step: config.kind.targetStep)
                }
            }
        }
        if let setup = MissionRegistry.setupView(for: $config) {
            Section("Setup") { setup }
        }
        Section {
            Label(config.instruction, systemImage: "alarm.waves.left.and.right")
                .font(.subheadline)
        } header: {
            Text("When the alarm rings")
        }
    }
}

/// Compact mission row in the alarm editor.
struct MissionRow: View {
    let config: MissionConfig

    var body: some View {
        HStack(spacing: 12) {
            MissionIcon(kind: config.kind, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.kind.displayName).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if config.kind.needsCamera && PermissionCenter.shared.status(.camera) == .denied {
                    Label("Camera is off — the backup mission will be used", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text(config.summary).font(.caption)
                        .foregroundStyle(config.isReady ? Color.secondary : Color.orange)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit mission")
    }
}

/// Edit an existing mission of the alarm.
struct MissionEditSheet: View {
    @Binding var config: MissionConfig
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                MissionOptionsSection(config: $config)
                Section {
                    Button("Remove mission", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                }
            }
            .navigationTitle(config.kind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
