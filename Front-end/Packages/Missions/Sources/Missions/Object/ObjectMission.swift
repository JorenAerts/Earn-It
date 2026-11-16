import Core
import Localization
import Permissions
import SwiftUI
import UIKit
import Vision

/// "Scan your item": the alarm only stops when the camera recognises the item the user
/// registered at setup (e.g. their toothbrush). Recognition: Vision feature prints of the item
/// cut out of its background, compared with the 5 reference angles (`ObjectMatchPolicy`).
public struct ObjectMission: Mission {
    public static let kind: MissionKind = .object
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(ObjectMissionView(referenceID: config.payload, label: config.label ?? "item", onComplete: onComplete))
    }

    public static func makeSetupView(config: Binding<MissionConfig>) -> AnyView? {
        AnyView(ObjectSetupRow(config: config))
    }
}

/// Holds the (non-Sendable) Vision references for the camera queue. Immutable after creation.
private final class ReferencePrints: @unchecked Sendable {
    let prints: [VNFeaturePrintObservation]
    init(_ prints: [VNFeaturePrintObservation]) { self.prints = prints }
}

/// Live recognition: camera frames → distance to the references → consecutive-match tracker.
@MainActor
@Observable
final class ObjectRecognizer {
    enum Status: Equatable { case loading, missingReference, cameraDenied, cameraUnavailable, paused, scanning, done }

    private(set) var status: Status = .loading
    private(set) var tracker = ObjectMatchTracker()
    private(set) var lastDistance: Float?
    private(set) var objectInView = false
    private(set) var thumbnail: UIImage?
    private(set) var threshold: Float = ObjectMatchPolicy.minimumThreshold
    @ObservationIgnored let camera = CameraFeed()
    @ObservationIgnored var onMatched: (() -> Void)?
    let torch: TorchController

    init() { torch = TorchController(camera: camera, mission: MissionKind.object.rawValue) }

    func start(referenceID: String?) async {
        guard let id = referenceID, let reference = ObjectReferenceStore.shared.load(id) else {
            status = .missingReference
            return
        }
        thumbnail = reference.thumbnail
        threshold = reference.threshold
        let references = ReferencePrints(reference.prints)
        camera.onFrame = { [weak self] buffer in
            let frame = ObjectVision.analyse(buffer)
            let distance = frame.flatMap { ObjectVision.distance($0.print, toAnyOf: references.prints) }
            Task { @MainActor in self?.record(distance) }
        }
        camera.onInterruption = { [weak self] interrupted in
            Task { @MainActor in
                guard let self, self.status == .scanning || self.status == .paused else { return }
                if interrupted { self.status = .paused } else { await self.resume() }
            }
        }
        await startCamera()
    }

    /// Starts the camera; if iOS doesn't let it run yet, keeps retrying for a while.
    private func startCamera() async {
        for attempt in 0..<30 {
            switch await camera.start() {
            case .running:
                status = .scanning
                torch.activate()
                return
            case .denied:
                status = .cameraDenied
                return
            case .unavailable:
                status = .cameraUnavailable
                return
            case .paused, .starting:
                status = .paused
                if attempt < 29 { try? await Task.sleep(for: .seconds(1)) }
                if Task.isCancelled { return }
            }
        }
    }

    /// Back in the foreground / interruption over: try again.
    func resume() async {
        guard status == .paused else { return }
        await startCamera()
    }

    func stop() {
        torch.reset()
        camera.stop()
    }

    private func record(_ distance: Float?) {
        guard status == .scanning else { return }
        lastDistance = distance
        objectInView = distance != nil
        CameraLog.values(String(format: "item d %@ · max %.2f · streak %d",
                                distance.map { String(format: "%.2f", $0) } ?? "–", threshold, tracker.streak),
                         brightness: torch.lastBrightness)
        tracker.record(distance: distance, threshold: threshold)
        if tracker.isComplete {
            status = .done
            torch.reset()
            camera.stop()
            onMatched?()
        }
    }

    #if DEBUG
    /// Simulator has no camera.
    func simulateMatch() {
        if status != .scanning { status = .scanning }
        for _ in 0..<ObjectMatchPolicy.requiredConsecutive { record(threshold * 0.5) }
    }
    #endif
}

struct ObjectMissionView: View {
    let referenceID: String?
    let label: String
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var recognizer = ObjectRecognizer()
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if recognizer.status == .scanning || recognizer.status == .done {
                    CameraPreview(session: recognizer.camera.session)
                } else {
                    Color.black.opacity(0.85)
                }
                ViewfinderCorners(matching: recognizer.tracker.streak > 0)
                    .padding(28)
                statusOverlay
            }
            .overlay(alignment: .topTrailing) {
                if recognizer.status == .scanning { TorchButton(controller: recognizer.torch) }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .frame(maxHeight: 420)
            .clipShape(.rect(cornerRadius: 24))

            HStack(spacing: 12) {
                if let thumb = recognizer.thumbnail {
                    Image(uiImage: thumb).resizable().scaledToFit()
                        .frame(width: 48, height: 48)
                        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 10))
                        .accessibilityLabel("Your \(label)")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(hint).font(.subheadline.weight(.semibold)).contentTransition(.opacity)
                    ProgressView(value: recognizer.tracker.lastCloseness)
                        .tint(recognizer.tracker.streak > 0 ? .green : .orange)
                        .animation(.easeOut(duration: 0.2), value: recognizer.tracker.lastCloseness)
                        .accessibilityLabel("How close the match is")
                }
            }
            .padding(.horizontal, 4)

            #if DEBUG && targetEnvironment(simulator)
            Button("Simulate match") { recognizer.simulateMatch() }.buttonStyle(.bordered).controlSize(.small)
            #endif
        }
        .padding(.horizontal, 20)
        .task {
            recognizer.onMatched = { onComplete(.success) }
            await recognizer.start(referenceID: referenceID)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await recognizer.resume() } }
        }
        .onDisappear { recognizer.stop() }
        .sensoryFeedback(.selection, trigger: recognizer.tracker.streak) { old, new in new > old }
    }

    private var hint: String {
        switch recognizer.status {
        case .loading: L10n.tr("Starting camera…")
        case .missingReference: L10n.tr("Your item scan is missing.")
        case .cameraDenied: L10n.tr("Camera access is off.")
        case .cameraUnavailable: L10n.tr("No camera available.")
        case .paused: L10n.tr("Starting the camera…")
        case .done: L10n.tr("Got it!")
        case .scanning:
            if !recognizer.objectInView { L10n.tr("Point the camera at your \(L10n.inSentence(label)).") }
            else if recognizer.tracker.streak > 0 { L10n.tr("That's it, hold still…") }
            else if recognizer.tracker.lastCloseness > 0.5 { L10n.tr("Getting closer…") }
            else { L10n.tr("That's not your \(L10n.inSentence(label)).") }
        }
    }

    @ViewBuilder private var statusOverlay: some View {
        switch recognizer.status {
        case .missingReference:
            overlayMessage(L10n.tr("This item was removed. Do the backup mission instead."), button: L10n.tr("Backup mission")) {
                onComplete(.needsBackup)
            }
        case .cameraDenied:
            VStack(spacing: 12) {
                Text("The camera is off for Gloop. Turn it on to scan your item, or do the backup mission.")
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                HStack {
                    Button("Open Settings") { PermissionCenter.shared.openSettings(.camera) }.buttonStyle(.bordered).tint(.white)
                    Button("Backup mission") { onComplete(.needsBackup) }.buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        case .cameraUnavailable:
            overlayMessage(L10n.tr("This device has no camera for scanning."), button: L10n.tr("Backup mission")) { onComplete(.needsBackup) }
        case .paused:
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Starting the camera…").foregroundStyle(.white)
                Button("Try again") { Task { await recognizer.resume() } }.buttonStyle(.bordered).tint(.white)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundStyle(.white, .green)
                .transition(.scale.combined(with: .opacity))
        default:
            EmptyView()
        }
    }

    private func overlayMessage(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(text).multilineTextAlignment(.center).foregroundStyle(.white)
            Button(button, action: action).buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

/// Four corner brackets; green while frames match.
struct ViewfinderCorners: View {
    var matching = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l = min(w, h) * 0.16
            Path { p in
                p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: l, y: 0))
                p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
                p.move(to: CGPoint(x: w, y: h - l)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - l, y: h))
                p.move(to: CGPoint(x: l, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - l))
            }
            .stroke(matching ? Color.green : Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            .animation(.easeOut(duration: 0.2), value: matching)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Setup row (alarm editor / mission picker)

struct ObjectSetupRow: View {
    @Binding var config: MissionConfig
    @State private var scanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let id = config.payload, let thumb = ObjectReferenceStore.shared.thumbnail(id) {
                    Image(uiImage: thumb).resizable().scaledToFit()
                        .frame(width: 52, height: 52)
                        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                }
                Label(config.isReady ? "\(config.label ?? L10n.tr("Item")) registered" : "Scan the item you'll need to find",
                      systemImage: config.isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(config.isReady ? .green : .orange)
                    .font(.subheadline)
            }
            Button(config.isReady ? L10n.tr("Scan again") : L10n.tr("Scan your item")) {
                Task { if await PermissionCenter.shared.ensure(.camera) { scanning = true } }
            }
                .buttonStyle(.bordered)
        }
        .fullScreenCover(isPresented: $scanning) {
            ObjectScanSetupView(config: $config)
        }
    }
}
