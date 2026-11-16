import Core
import CoreMotion
import SwiftUI
import UIKit

public struct ShakeMission: Mission {
    public static let kind: MissionKind = .shake
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(ShakeMissionView(config: config, onComplete: onComplete))
    }
}

@MainActor
@Observable
final class ShakeMonitor {
    private(set) var count = 0
    private(set) var available = true
    private var detector: ShakeDetector
    private let motion = CMMotionManager()
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    init(difficulty: MissionDifficulty) {
        let threshold = switch difficulty {
        case .easy: 1.7
        case .medium: 2.0
        case .hard: 2.5
        }
        detector = ShakeDetector(threshold: threshold)
    }

    func start() {
        guard motion.isAccelerometerAvailable else { available = false; return }
        motion.accelerometerUpdateInterval = 1.0 / 60.0
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let a = data.acceleration
            let t = data.timestamp
            MainActor.assumeIsolated { self?.ingest(x: a.x, y: a.y, z: a.z, t: t) }
        }
    }

    func stop() { motion.stopAccelerometerUpdates() }

    /// Simulator has no accelerometer: lets a debug button count a shake.
    func simulateShake() {
        detector.process(x: 3, y: 0, z: 0, timestamp: Date().timeIntervalSince1970)
        count = detector.count
    }

    private func ingest(x: Double, y: Double, z: Double, t: TimeInterval) {
        if detector.process(x: x, y: y, z: z, timestamp: t) {
            count = detector.count
            haptic.impactOccurred()
        }
    }
}

struct ShakeMissionView: View {
    let config: MissionConfig
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var monitor: ShakeMonitor
    @State private var finished = false

    init(config: MissionConfig, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.config = config
        self.onComplete = onComplete
        _monitor = State(initialValue: ShakeMonitor(difficulty: config.difficulty))
    }

    private var progress: Double { min(1, Double(monitor.count) / Double(max(1, config.target))) }

    var body: some View {
        VStack(spacing: 32) {
            Text("Shake your phone")
                .font(.title.bold())
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: progress)
                Text("\(min(monitor.count, config.target)) / \(config.target)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 220, maxHeight: 220)  // shrinks in landscape / small windows

            if !monitor.available {
                Text("No accelerometer on this device.").foregroundStyle(.secondary)
            }
            #if DEBUG
            Button("Simulate shake") { monitor.simulateShake() }
                .buttonStyle(.bordered)
            #endif
        }
        .padding(24)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .onChange(of: monitor.count) { _, count in
            guard !finished, count >= config.target else { return }
            finished = true
            monitor.stop()
            onComplete(.success)
        }
    }
}
