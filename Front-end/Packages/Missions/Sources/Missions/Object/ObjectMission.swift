import Core
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
    enum Status: Equatable { case loading, missingReference, cameraDenied, cameraUnavailable, scanning, done }

    private(set) var status: Status = .loading
    private(set) var tracker = ObjectMatchTracker()
    private(set) var lastDistance: Float?
    private(set) var objectInView = false
    private(set) var thumbnail: UIImage?
    private(set) var threshold: Float = ObjectMatchPolicy.minimumThreshold
    @ObservationIgnored let camera = CameraFeed()
    @ObservationIgnored var onMatched: (() -> Void)?

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
        switch await camera.start() {
        case .running: status = .scanning
        case .denied: status = .cameraDenied
        default: status = .cameraUnavailable
        }
    }

    func stop() { camera.stop() }

    private func record(_ distance: Float?) {
        guard status == .scanning else { return }
        lastDistance = distance
        objectInView = distance != nil
        tracker.record(distance: distance, threshold: threshold)
        if tracker.isComplete {
            status = .done
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

            #if DEBUG
            HStack {
                Text(recognizer.lastDistance.map { String(format: "d %.2f", $0) } ?? "d –")
                Text(String(format: "max %.2f", recognizer.threshold))
                Text("streak \(recognizer.tracker.streak)")
                Spacer()
                Button("Simulate match") { recognizer.simulateMatch() }.buttonStyle(.bordered).controlSize(.small)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            #endif
        }
        .padding(.horizontal, 20)
        .task {
            recognizer.onMatched = { onComplete(.success) }
            await recognizer.start(referenceID: referenceID)
        }
        .onDisappear { recognizer.stop() }
        .sensoryFeedback(.selection, trigger: recognizer.tracker.streak) { old, new in new > old }
    }

    private var hint: String {
        switch recognizer.status {
        case .loading: "Starting camera…"
        case .missingReference: "Your item scan is missing."
        case .cameraDenied: "Camera access is off."
        case .cameraUnavailable: "No camera available."
        case .done: "Got it!"
        case .scanning:
            if !recognizer.objectInView { "Point the camera at your \(label.lowercased())." }
            else if recognizer.tracker.streak > 0 { "That's it, hold still…" }
            else if recognizer.tracker.lastCloseness > 0.5 { "Getting closer…" }
            else { "That's not your \(label.lowercased())." }
        }
    }

    @ViewBuilder private var statusOverlay: some View {
        switch recognizer.status {
        case .missingReference:
            overlayMessage("This item was removed. Do the backup mission instead.", button: "Backup mission") {
                onComplete(.needsBackup)
            }
        case .cameraDenied:
            overlayMessage("Allow camera access in Settings to scan your item, or do the backup mission.",
                           button: "Backup mission") { onComplete(.needsBackup) }
        case .cameraUnavailable:
            overlayMessage("This device has no camera for scanning.", button: "Backup mission") { onComplete(.needsBackup) }
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
                Label(config.isReady ? "\(config.label ?? "Item") registered" : "Scan the item you'll need to find",
                      systemImage: config.isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(config.isReady ? .green : .orange)
                    .font(.subheadline)
            }
            Button(config.isReady ? "Scan again" : "Scan your item") { scanning = true }
                .buttonStyle(.bordered)
        }
        .fullScreenCover(isPresented: $scanning) {
            ObjectScanSetupView(config: $config)
        }
    }
}
