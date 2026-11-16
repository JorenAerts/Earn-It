import Core
import CoreImage.CIFilterBuiltins
import Permissions
import Localization
import SwiftUI
import UIKit

/// "Scan a code in another room": the alarm only ends when the code registered at setup
/// (e.g. stuck on the bathroom mirror) is scanned.
public struct QRMission: Mission {
    public static let kind: MissionKind = .qr
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(QRMissionView(expected: config.payload, onComplete: onComplete))
    }

    public static func makeSetupView(config: Binding<MissionConfig>) -> AnyView? {
        AnyView(QRSetupRow(config: config))
    }
}

// MARK: - Mission (morning)

struct QRMissionView: View {
    let expected: String?
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var wrongCode = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Scan your code").font(.title.bold())
            Text("Go to where you stuck it and point the camera at it.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

            CodeScannerView(mission: MissionKind.qr.rawValue, onCode: handle) { onComplete(.needsBackup) }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 24))
                .frame(maxHeight: 420)
                .frame(maxWidth: .infinity)

            Text(wrongCode ? L10n.tr("That's not your registered code.") : " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)

            #if DEBUG && targetEnvironment(simulator)
            Button("Simulate correct scan") { handle(expected ?? "") }
                .buttonStyle(.bordered)
            #endif
        }
        .padding(24)
        .sensoryFeedback(.error, trigger: wrongCode) { _, new in new }
    }

    private func handle(_ payload: String) {
        guard !finished else { return }
        if CodeMatcher.matches(scanned: payload, expected: expected) {
            finished = true
            onComplete(.success)
        } else {
            wrongCode = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                wrongCode = false
            }
        }
    }
}

// MARK: - Setup (alarm editor)

struct QRSetupRow: View {
    @Binding var config: MissionConfig
    @State private var mode: SetupMode?

    enum SetupMode: String, Identifiable {
        case scan, create
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(config.isReady ? L10n.tr("Code registered") : L10n.tr("Register a code to use this mission"),
                  systemImage: config.isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(config.isReady ? .green : .orange)
                .font(.subheadline)
            HStack {
                Button("Scan existing code") {
                    Task { if await PermissionCenter.shared.ensure(.camera) { mode = .scan } }
                }
                Button("Create printable code") { mode = .create }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .sheet(item: $mode) { mode in
            switch mode {
            case .scan: RegisterByScanView(config: $config)
            case .create: CreateCodeView(config: $config)
            }
        }
    }
}

private struct RegisterByScanView: View {
    @Binding var config: MissionConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Scan any QR code or barcode in another room — a sticker, a product, a printed code. You'll need to scan this same code to stop your alarm.")
                    .font(.subheadline).foregroundStyle(.secondary)
                CodeScannerView(mission: "qrSetup") { payload in
                    config.payload = payload
                    dismiss()
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 24))
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Register code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct CreateCodeView: View {
    @Binding var config: MissionConfig
    @Environment(\.dismiss) private var dismiss
    @State private var payload = CodeMatcher.newPayload()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Print or show this code somewhere away from your bed — the bathroom mirror works great.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let image = QRCodeRenderer.image(for: payload) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .padding()
                        .background(.white, in: .rect(cornerRadius: 16))
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview("Gloop wake-up code", image: Image(uiImage: image))) {
                        Label("Share / print", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Your wake-up code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this code") {
                        config.payload = payload
                        dismiss()
                    }
                }
            }
        }
    }
}

enum QRCodeRenderer {
    static func image(for payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
