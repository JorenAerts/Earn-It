import SwiftUI

/// A permission with its reason, live status and the right button (Allow / Open Settings).
/// Used in onboarding and the Settings overview.
public struct PermissionRow: View {
    let kind: PermissionKind
    var showsImportance = true
    var onGranted: (() -> Void)?
    @State private var center = PermissionCenter.shared

    public init(kind: PermissionKind, showsImportance: Bool = true, onGranted: (() -> Void)? = nil) {
        self.kind = kind
        self.showsImportance = showsImportance
        self.onGranted = onGranted
    }

    public var body: some View {
        let status = center.status(kind)
        let action = PermissionAction.for(kind, status)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint(for: status), in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(kind.title).font(.body.weight(.semibold))
                    if showsImportance, kind.importance != .info {
                        Text(kind.importance.label)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(kind.reason).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    StatusPill(status: status)
                    if let title = action.buttonTitle {
                        Button(title) {
                            Task {
                                await center.perform(kind)
                                if center.isGranted(kind) { onGranted?() }
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func tint(for status: PermissionStatus) -> Color {
        switch status {
        case .granted: .green
        case .denied: .red
        case .unavailable: .gray
        case .notDetermined: .orange
        }
    }
}

struct StatusPill: View {
    let status: PermissionStatus

    var body: some View {
        Label(status.label, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityLabel("Status: \(status.label)")
    }

    private var symbol: String {
        switch status {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .unavailable: "minus.circle.fill"
        case .notDetermined: "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .granted: .green
        case .denied: .red
        case .unavailable: .secondary
        case .notDetermined: .orange
        }
    }
}

/// Inline warning where a feature can't work, with a button that fixes it.
public struct PermissionBanner: View {
    let kind: PermissionKind
    let message: String
    @State private var center = PermissionCenter.shared

    public init(kind: PermissionKind, message: String) {
        self.kind = kind
        self.message = message
    }

    public var body: some View {
        let action = PermissionAction.for(kind, center.status(kind))
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let title = action.buttonTitle {
                    Button(title) { Task { await center.perform(kind) } }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Hosts the app-wide "X is off — Open Settings" alert driven by `PermissionCenter.blocked`.
    /// Add once at the root; any screen triggers it with `PermissionCenter.shared.ensure(_:)`.
    public func permissionPrompt() -> some View {
        modifier(PermissionPromptModifier())
    }
}

private struct PermissionPromptModifier: ViewModifier {
    @State private var center = PermissionCenter.shared

    func body(content: Content) -> some View {
        let kind = center.blocked
        content.alert(kind.map { center.status($0) == .unavailable ? "\($0.title) unavailable" : "\($0.title) is off" } ?? "",
                      isPresented: Binding(get: { center.blocked != nil }, set: { if !$0 { center.blocked = nil } }),
                      presenting: kind) { kind in
            if PermissionAction.for(kind, center.status(kind)) != .none {
                Button("Open Settings") { center.openSettings(kind) }
            }
            Button("Not now", role: .cancel) {}
        } message: { kind in
            Text(center.status(kind) == .unavailable && kind == .camera
                 ? "This device has no camera that Earn It can use."
                 : kind.blockedMessage)
        }
    }
}
