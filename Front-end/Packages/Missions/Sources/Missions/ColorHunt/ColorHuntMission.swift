import Core
import CoreImage
import CoreVideo
import Localization
import SwiftUI
import UIKit

public struct ColorHuntMission: Mission {
    public static let kind: MissionKind = .colorHunt
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(ColorHuntMissionView(target: config.target, onComplete: onComplete))
    }
}

/// Average colour of the centre of the frame (the part inside the corners).
struct HSB: Sendable { let hue: Double, saturation: Double, brightness: Double }

enum ColorVision {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func centre(_ buffer: CVPixelBuffer) -> HSB? {
        let image = CIImage(cvPixelBuffer: buffer)
        let e = image.extent
        let side = min(e.width, e.height) * 0.3
        let rect = CGRect(x: e.midX - side / 2, y: e.midY - side / 2, width: side, height: side)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: rect)]),
              let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
            .getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return HSB(hue: Double(h) * 360, saturation: Double(s), brightness: Double(b))
    }
}

extension ColorTarget {
    var title: String {
        switch self {
        case .red: L10n.tr("red")
        case .orange: L10n.tr("orange")
        case .yellow: L10n.tr("yellow")
        case .green: L10n.tr("green")
        case .blue: L10n.tr("blue")
        case .purple: L10n.tr("purple")
        case .pink: L10n.tr("pink")
        }
    }

    var swatch: Color { Color(hue: hue.center / 360, saturation: 0.8, brightness: 0.9) }
}

struct ColorHuntMissionView: View {
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var runner = CameraRunner<HSB?>()
    @State private var targets: [ColorTarget]
    @State private var index = 0
    @State private var hits = ConsecutiveHits(required: ColorMatch.requiredFrames)
    @State private var last: HSB?

    init(target: Int, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.onComplete = onComplete
        var rng = SystemRandomNumberGenerator()
        _targets = State(initialValue: ColorMatch.targets(count: target, rng: &rng))
    }

    private var current: ColorTarget? { targets.indices.contains(index) ? targets[index] : nil }

    var body: some View {
        CameraMissionScreen(runner: runner, hint: hint, progress: hits.progress, matching: hits.streak > 0,
                            onBackup: { onComplete(.needsBackup) },
                            simulate: simulate,
                            debugText: last.map { String(format: "h %.0f s %.2f b %.2f", $0.hue, $0.saturation, $0.brightness) } ?? "–") {
            if let current {
                HStack(spacing: 12) {
                    Circle().fill(current.swatch).frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2)).shadow(radius: 2)
                    Text("Find something \(current.title)")
                        .font(.title3.bold())
                    Spacer()
                    Text("\(index + 1) / \(targets.count)").font(.headline).foregroundStyle(.secondary)
                }
                .id(current)
                .transition(.push(from: .trailing))
            }
        }
        .task {
            runner.onValue = { record($0) }
            await runner.start(interval: 0.25, torch: MissionKind.colorHunt.rawValue, analyse: ColorVision.centre)
        }
    }

    private var hint: String {
        switch runner.status {
        case .done: L10n.tr("All colors found!")
        case .scanning:
            hits.streak > 0 ? L10n.tr("That's it, hold still…") : L10n.tr("Fill the middle of the frame with the color.")
        default: L10n.tr("Starting camera…")
        }
    }

    private func record(_ hsb: HSB?) {
        guard let current else { return }
        last = hsb
        let hit = hsb.map { ColorMatch.matches(hue: $0.hue, saturation: $0.saturation, brightness: $0.brightness, target: current) } ?? false
        hits.record(hit)
        guard hits.isComplete else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        hits.reset()
        if index + 1 >= targets.count {
            runner.finish()
            onComplete(.success)
        } else {
            withAnimation(.snappy) { index += 1 }
        }
    }

    private func simulate() {
        guard let current else { return }
        for _ in 0..<ColorMatch.requiredFrames {
            record(HSB(hue: current.hue.center, saturation: 0.9, brightness: 0.9))
        }
    }
}
