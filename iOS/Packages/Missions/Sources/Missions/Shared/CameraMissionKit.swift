import AVFoundation
import Core
import OSLog
import Localization
import Permissions
import SwiftUI

/// N analysed frames in a row must pass; one miss starts over (rejects a lucky single frame).
public struct ConsecutiveHits: Equatable, Sendable {
    public let required: Int
    public private(set) var streak = 0

    public init(required: Int) { self.required = max(1, required) }

    public var isComplete: Bool { streak >= required }
    public var progress: Double { min(1, Double(streak) / Double(required)) }

    public mutating func record(_ hit: Bool) { streak = hit ? streak + 1 : 0 }
    public mutating func reset() { streak = 0 }
}

/// Camera lifecycle shared by the camera missions (same rules as the item scan): start, keep
/// retrying while iOS hasn't released the camera, pause on interruptions, resume on foreground.
/// The analyser runs on the camera queue and returns a value the mission evaluates on the main actor.
@MainActor
@Observable
final class CameraRunner<Value: Sendable> {
    enum Status: Equatable { case loading, cameraDenied, cameraUnavailable, paused, scanning, done }

    private(set) var status: Status = .loading
    @ObservationIgnored let camera = CameraFeed()
    @ObservationIgnored var onValue: ((Value) -> Void)?
    /// Flashlight for this screen; nil = no flashlight button (the sky mission).
    private(set) var torch: TorchController?

    /// `torch`: the mission name for a flashlight button (nil = none).
    func start(interval: CFTimeInterval = 0.3, torch mission: String? = nil,
               analyse: @escaping @Sendable (CVPixelBuffer) -> Value) async {
        if let mission, torch == nil { torch = TorchController(camera: camera, mission: mission) }
        camera.interval = interval
        camera.onFrame = { [weak self] buffer in
            let value = analyse(buffer)
            Task { @MainActor in
                guard let self, self.status == .scanning else { return }
                self.onValue?(value)
            }
        }
        camera.onInterruption = { [weak self] interrupted in
            Task { @MainActor in
                guard let self, self.status == .scanning || self.status == .paused else { return }
                if interrupted { self.status = .paused } else { await self.resume() }
            }
        }
        await startCamera()
    }

    private func startCamera() async {
        for attempt in 0..<30 {
            switch await camera.start() {
            case .running:
                status = .scanning
                torch?.activate()
                return
            case .denied: status = .cameraDenied; return
            case .unavailable: status = .cameraUnavailable; return
            case .paused, .starting:
                status = .paused
                if attempt < 29 { try? await Task.sleep(for: .seconds(1)) }
                if Task.isCancelled { return }
            }
        }
    }

    func resume() async {
        guard status == .paused else { return }
        await startCamera()
    }

    func finish() {
        status = .done
        torch?.reset()
        camera.stop()
    }

    func stop() {
        torch?.reset()
        camera.stop()
    }

    #if DEBUG
    /// The Simulator has no camera: pretend it runs so "Simulate" can feed values.
    func forceScanning() { if status != .done { status = .scanning } }
    #endif
}

/// Live scan numbers for tuning thresholds on a real iPhone: Console.app → the iPhone →
/// subsystem `be.gloop.app`, category `camera` (debug level; never shown to users).
enum CameraLog {
    static let logger = Logger(subsystem: "be.gloop.app", category: "camera")

    static func values(_ text: String, brightness: Double?) {
        guard !text.isEmpty else { return }
        let lux = brightness.map { String(format: " · lux %.1f", $0) } ?? ""
        logger.debug("\(text, privacy: .public)\(lux, privacy: .public)")
    }
}

/// Camera screen used by the sky, bed and colour missions: preview, corners, status overlays
/// (camera off → Open Settings / backup), a hint with a progress bar and an optional way out.
struct CameraMissionScreen<Value: Sendable, Header: View>: View {
    let runner: CameraRunner<Value>
    let hint: String
    let progress: Double
    var matching = false
    var wayOut: (title: String, action: () -> Void)? = nil
    let onBackup: () -> Void
    /// DEBUG only (shown under the camera): feed fake hits in the Simulator, live numbers for tuning.
    var simulate: (() -> Void)? = nil
    var debugText: String = ""
    @ViewBuilder var header: () -> Header
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 14) {
            header()
            ZStack {
                if runner.status == .scanning || runner.status == .done {
                    CameraPreview(session: runner.camera.session)
                } else {
                    Color.black.opacity(0.85)
                }
                ViewfinderCorners(matching: matching).padding(28)
                overlay
            }
            .overlay(alignment: .topTrailing) {
                if let torch = runner.torch, runner.status == .scanning { TorchButton(controller: torch) }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .frame(maxHeight: 420)
            .clipShape(.rect(cornerRadius: 24))

            let cameraOff = runner.status == .cameraDenied || runner.status == .cameraUnavailable
            VStack(alignment: .leading, spacing: 6) {
                Text(cameraOff ? " " : hint).font(.subheadline.weight(.semibold)).contentTransition(.opacity)
                ProgressView(value: progress)
                    .tint(matching ? .green : .orange)
                    .animation(.easeOut(duration: 0.2), value: progress)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            if let wayOut, runner.status != .done {
                Button(wayOut.title, action: wayOut.action).font(.subheadline.weight(.semibold))
            }

            #if DEBUG && targetEnvironment(simulator)
            if let simulate {
                // The Simulator has no camera. Live numbers go to the log (CameraLog), not on screen.
                Button("Simulate") { runner.forceScanning(); simulate() }.buttonStyle(.bordered).controlSize(.small)
            }
            #endif
        }
        .padding(.horizontal, 20)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await runner.resume() } }
        }
        .onChange(of: debugText) { _, text in
            CameraLog.values(text, brightness: runner.torch?.lastBrightness)
        }
        .onDisappear { runner.stop() }
        .sensoryFeedback(.success, trigger: runner.status == .done)
    }

    @ViewBuilder private var overlay: some View {
        switch runner.status {
        case .cameraDenied:
            VStack(spacing: 12) {
                Text("Turn on the camera for Gloop, or do the backup mission.")
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                HStack {
                    Button("Open Settings") { PermissionCenter.shared.openSettings(.camera) }.buttonStyle(.bordered).tint(.white)
                    Button("Backup mission", action: onBackup).buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        case .cameraUnavailable:
            VStack(spacing: 12) {
                Text("This device has no camera for scanning.").multilineTextAlignment(.center).foregroundStyle(.white)
                Button("Backup mission", action: onBackup).buttonStyle(.borderedProminent)
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
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundStyle(.white, .green)
                .transition(.scale.combined(with: .opacity))
        case .scanning:
            EmptyView()
        }
    }
}
