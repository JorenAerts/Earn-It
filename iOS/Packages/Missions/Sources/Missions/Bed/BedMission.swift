import Core
import CoreImage
import CoreVideo
import Localization
import Permissions
import SwiftUI
import UIKit
import Vision

public struct BedMission: Mission {
    public static let kind: MissionKind = .bed
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(BedMissionView(referenceID: config.payload, onComplete: onComplete))
    }

    @MainActor public static func makeSetupView(config: Binding<MissionConfig>) -> AnyView? {
        AnyView(BedSetupRow(config: config))
    }
}

/// Whole-frame feature print (the bed is a scene, not a cut-out object).
enum SceneVision {
    private static let context = CIContext()

    static func print(_ buffer: CVPixelBuffer) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right)
        guard (try? handler.perform([request])) != nil else { return nil }
        return request.results?.first
    }

    static func thumbnail(_ buffer: CVPixelBuffer) -> UIImage? {
        let image = CIImage(cvPixelBuffer: buffer).oriented(.right)
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg).preparingThumbnail(of: CGSize(width: 240, height: 320))
    }
}

/// Holds the (non-Sendable) reference prints for the camera queue. Immutable after creation.
private final class BedPrints: @unchecked Sendable {
    let prints: [VNFeaturePrintObservation]
    init(_ prints: [VNFeaturePrintObservation]) { self.prints = prints }
}

struct BedMissionView: View {
    let referenceID: String?
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var runner = CameraRunner<Float?>()
    @State private var hits = ConsecutiveHits(required: BedMatchPolicy.requiredFrames)
    @State private var threshold: Float = BedMatchPolicy.minimumThreshold
    @State private var thumbnail: UIImage?
    @State private var missing = false
    @State private var last: Float?

    var body: some View {
        Group {
            if missing {
                ContentUnavailableView {
                    Label("Your bed scan is missing.", systemImage: "bed.double")
                } actions: {
                    Button("Backup mission") { onComplete(.needsBackup) }.buttonStyle(.borderedProminent)
                }
            } else {
                CameraMissionScreen(runner: runner, hint: hint, progress: hits.progress, matching: hits.streak > 0,
                                    onBackup: { onComplete(.needsBackup) },
                                    simulate: { for _ in 0..<BedMatchPolicy.requiredFrames { record(threshold * 0.5) } },
                                    debugText: String(format: "d %@ · max %.2f · streak %d",
                                                      last.map { String(format: "%.2f", $0) } ?? "–", threshold, hits.streak)) {
                    if let thumbnail {
                        HStack(spacing: 12) {
                            Image(uiImage: thumbnail).resizable().scaledToFill()
                                .frame(width: 48, height: 64).clipShape(.rect(cornerRadius: 8))
                            Text("Make it look like this, then show it from the foot of the bed.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task { await start() }
    }

    private var hint: String {
        switch runner.status {
        case .done: L10n.tr("Neat! Bed made.")
        case .scanning:
            if hits.streak > 0 { L10n.tr("That's it, hold still…") }
            else if let last, last <= threshold * 1.4 { L10n.tr("Almost: smooth the duvet and pillows.") }
            else { L10n.tr("Stand at the foot of your bed and point the camera at it.") }
        default: L10n.tr("Starting camera…")
        }
    }

    private func start() async {
        guard let id = referenceID, let reference = ObjectReferenceStore.shared.load(id) else {
            missing = true
            return
        }
        threshold = reference.threshold
        thumbnail = reference.thumbnail
        let prints = BedPrints(reference.prints)
        runner.onValue = { record($0) }
        await runner.start(torch: MissionKind.bed.rawValue) { buffer in
            SceneVision.print(buffer).flatMap { ObjectVision.distance($0, toAnyOf: prints.prints) }
        }
    }

    private func record(_ distance: Float?) {
        last = distance
        hits.record(distance.map { BedMatchPolicy.isMatch(distance: $0, threshold: threshold) } ?? false)
        if hits.isComplete {
            runner.finish()
            onComplete(.success)
        }
    }
}

// MARK: - Setup

struct BedSetupRow: View {
    @Binding var config: MissionConfig
    @State private var scanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let id = config.payload, let thumb = ObjectReferenceStore.shared.thumbnail(id) {
                    Image(uiImage: thumb).resizable().scaledToFill()
                        .frame(width: 48, height: 64).clipShape(.rect(cornerRadius: 10))
                }
                Label(config.isReady ? L10n.tr("Bed scanned") : L10n.tr("Take 3 photos of your made bed"),
                      systemImage: config.isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(config.isReady ? .green : .orange)
                    .font(.subheadline)
            }
            Button(config.isReady ? L10n.tr("Scan again") : L10n.tr("Scan your made bed")) {
                Task { if await PermissionCenter.shared.ensure(.camera) { scanning = true } }
            }
            .buttonStyle(.bordered)
        }
        .fullScreenCover(isPresented: $scanning) { BedScanSetupView(config: $config) }
    }
}

/// Three photos of the made bed: from the foot of the bed, a step left, a step right.
struct BedScanSetupView: View {
    @Binding var config: MissionConfig
    @Environment(\.dismiss) private var dismiss
    @State private var runner = CameraRunner<Bool>()
    @State private var prints: [VNFeaturePrintObservation] = []
    @State private var thumb: UIImage?
    @State private var problem: String?
    @State private var busy = false

    private var prompts: [String] {
        [L10n.tr("Stand at the foot of your made bed"), L10n.tr("Now one step to the left"), L10n.tr("Now one step to the right")]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if prints.count < BedMatchPolicy.requiredShots {
                    Text(prompts[prints.count]).font(.title3.bold()).multilineTextAlignment(.center)
                    Text("Make your bed first. Get the whole bed in the frame.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                ZStack {
                    if runner.status == .scanning || runner.status == .done {
                        CameraPreview(session: runner.camera.session)
                    } else {
                        Color.black.opacity(0.85)
                        ProgressView().tint(.white)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let torch = runner.torch, runner.status == .scanning { TorchButton(controller: torch) }
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxHeight: 440)
                .clipShape(.rect(cornerRadius: 24))
                if let problem { Text(problem).font(.subheadline).foregroundStyle(.orange) }
                Text("Photo \(min(prints.count + 1, BedMatchPolicy.requiredShots)) of \(BedMatchPolicy.requiredShots)")
                    .font(.headline).foregroundStyle(.secondary)
                Button { Task { await capture() } } label: {
                    Label("Take photo", systemImage: "camera.fill").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(busy || runner.status != .scanning)
                #if DEBUG && targetEnvironment(simulator)
                if runner.status != .scanning {
                    Button("Simulate scan (no camera)") { saveSimulated() }.font(.caption)
                }
                #endif
            }
            .padding(20)
            .navigationTitle("Scan your made bed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { runner.stop(); dismiss() } }
            }
        }
        .task { await runner.start(torch: "bedSetup", analyse: { _ in true }) }
        .onDisappear { runner.stop() }
    }

    private func capture() async {
        guard let buffer = runner.camera.latestFrame() else { return }
        busy = true
        defer { busy = false }
        let result = await Task.detached { () -> (BedPrintsBox?, UIImage?) in
            (SceneVision.print(buffer).map(BedPrintsBox.init), SceneVision.thumbnail(buffer))
        }.value
        guard let print = result.0?.print else {
            problem = L10n.tr("Couldn't read the photo. Try again in better light.")
            return
        }
        if let previous = prints.last, let d = ObjectVision.distance(print, previous), d < BedMatchPolicy.minimumShotChange {
            problem = L10n.tr("That looks the same as the last photo. Take one step to the side.")
            return
        }
        problem = nil
        if prints.isEmpty { thumb = result.1 }
        prints.append(print)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if prints.count >= BedMatchPolicy.requiredShots { save() }
    }

    private func save() {
        let threshold = BedMatchPolicy.threshold(pairwiseDistances: ObjectVision.pairwiseDistances(prints))
        do {
            let id = try ObjectReferenceStore.shared.save(prints: prints, threshold: threshold, thumbnail: thumb)
            config.payload = id
            config.label = L10n.tr("Bed")
            runner.stop()
            dismiss()
        } catch {
            problem = L10n.tr("Couldn't save the scan: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    /// Simulator: store a placeholder so the mission can be added and tested with "Simulate".
    private func saveSimulated() {
        config.payload = "simulated-bed"
        config.label = L10n.tr("Bed")
        runner.stop()
        dismiss()
    }
    #endif
}

private final class BedPrintsBox: @unchecked Sendable {
    let print: VNFeaturePrintObservation
    init(_ print: VNFeaturePrintObservation) { self.print = print }
}
