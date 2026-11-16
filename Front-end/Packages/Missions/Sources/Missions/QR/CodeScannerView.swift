import AVFoundation
import Localization
import Permissions
import SwiftUI

/// Live QR/barcode scanner on the shared camera (`CameraFeed` + metadata output), so it gets the
/// same start/retry/interruption handling and flashlight button as the other camera missions.
/// (VisionKit's DataScanner has no flashlight control and gives no frames for auto flashlight.)
struct CodeScannerView: View {
    /// Telemetry name for the flashlight ("qr", "qrSetup").
    let mission: String
    /// Every recognised payload (the same code is reported again at most once a second).
    let onCode: @MainActor (String) -> Void
    /// Shown on "camera off / no camera"; nil = no backup button (setup).
    var onBackup: (() -> Void)? = nil

    @State private var runner = CameraRunner<Bool>()
    @State private var seen = false
    @State private var last: (payload: String, at: Date)?
    @Environment(\.scenePhase) private var scenePhase

    /// Everything the old VisionKit scanner accepted that people stick on a wall or find on a product.
    static let codeTypes: [AVMetadataObject.ObjectType] = [
        .qr, .ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .interleaved2of5, .dataMatrix, .pdf417, .aztec,
    ]

    var body: some View {
        ZStack {
            if runner.status == .scanning || runner.status == .done {
                CameraPreview(session: runner.camera.session)
            } else {
                Color.black.opacity(0.85)
            }
            ViewfinderCorners(matching: seen).padding(28)
            overlay
        }
        .overlay(alignment: .topTrailing) {
            if let torch = runner.torch, runner.status == .scanning { TorchButton(controller: torch) }
        }
        .task {
            runner.camera.codeTypes = Self.codeTypes
            runner.camera.onCodes = { payloads in
                Task { @MainActor in report(payloads) }
            }
            // Codes come from the metadata output; frames are only used for the flashlight's brightness.
            await runner.start(interval: 5, torch: mission, analyse: { _ in false })
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await runner.resume() } }
        }
        .onDisappear { runner.stop() }
    }

    private func report(_ payloads: [String]) {
        guard runner.status == .scanning, let payload = payloads.first else { return }
        if let last, last.payload == payload, Date.now.timeIntervalSince(last.at) < 1 { return }
        last = (payload, .now)
        withAnimation(.snappy) { seen = true }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation { seen = false }
        }
        onCode(payload)
    }

    @ViewBuilder private var overlay: some View {
        switch runner.status {
        case .cameraDenied:
            VStack(spacing: 12) {
                Text("Turn on the camera for Gloop to scan your code.")
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                HStack {
                    Button("Open Settings") { PermissionCenter.shared.openSettings(.camera) }.buttonStyle(.bordered).tint(.white)
                    if let onBackup { Button("Backup mission", action: onBackup).buttonStyle(.borderedProminent) }
                }
            }
            .padding(24)
        case .cameraUnavailable:
            VStack(spacing: 12) {
                Text("This device has no camera for scanning.").multilineTextAlignment(.center).foregroundStyle(.white)
                if let onBackup { Button("Backup mission", action: onBackup).buttonStyle(.borderedProminent) }
            }
            .padding(24)
        case .paused, .loading:
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Starting the camera…").foregroundStyle(.white)
                if runner.status == .paused {
                    Button("Try again") { Task { await runner.resume() } }.buttonStyle(.bordered).tint(.white)
                }
            }
        case .scanning, .done:
            EmptyView()
        }
    }
}
