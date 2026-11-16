import Core
import CoreVideo
import Localization
import SwiftUI
import Vision

public struct SkyMission: Mission {
    public static let kind: MissionKind = .sky
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(SkyMissionView(onComplete: onComplete))
    }
}

enum SkyVision {
    /// Classifier labels of a frame (on the camera queue).
    static func score(_ buffer: CVPixelBuffer) -> Float {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right)
        guard (try? handler.perform([request])) != nil, let results = request.results else { return 0 }
        return SkyPolicy.score(results.prefix(40).map { ($0.identifier, $0.confidence) })
    }
}

struct SkyMissionView: View {
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var runner = CameraRunner<Float>()
    @State private var hits = ConsecutiveHits(required: SkyPolicy.requiredFrames)
    @State private var lastScore: Float = 0

    var body: some View {
        CameraMissionScreen(runner: runner, hint: hint, progress: hits.progress, matching: hits.streak > 0,
                            wayOut: (L10n.tr("Can't see the sky? Do another mission"), { onComplete(.needsBackup) }),
                            onBackup: { onComplete(.needsBackup) },
                            simulate: { for _ in 0..<SkyPolicy.requiredFrames { record(0.9) } },
                            debugText: String(format: "sky %.2f · streak %d", lastScore, hits.streak)) {
            Label("Day, night, clouds or rain: any sky counts.", systemImage: "cloud.sun.rain.fill")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .task {
            runner.onValue = { record($0) }
            await runner.start(analyse: SkyVision.score)
        }
    }

    private var hint: String {
        switch runner.status {
        case .done: L10n.tr("Good morning, sky!")
        case .scanning:
            hits.streak > 0 ? L10n.tr("That's the sky, hold still…") : L10n.tr("Point the camera at the sky.")
        default: L10n.tr("Starting camera…")
        }
    }

    private func record(_ score: Float) {
        lastScore = score
        hits.record(SkyPolicy.isSky(score))
        if hits.isComplete {
            runner.finish()
            onComplete(.success)
        }
    }
}
