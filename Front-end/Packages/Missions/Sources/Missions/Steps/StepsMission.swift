import Core
import CoreMotion
import SwiftUI
import UIKit

/// "Walk X steps": live step count from the motion co-processor until the target is reached.
public struct StepsMission: Mission {
    public static let kind: MissionKind = .steps
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(StepsMissionView(target: config.target, onComplete: onComplete))
    }
}

@MainActor
@Observable
final class StepCounter {
    enum Status { case counting, unavailable, denied }

    private(set) var progress: StepProgress
    private(set) var status: Status = .counting
    private let pedometer = CMPedometer()
    private var extraSteps = 0

    init(target: Int) {
        progress = StepProgress(target: target)
    }

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { status = .unavailable; return }
        if [.denied, .restricted].contains(CMPedometer.authorizationStatus()) { status = .denied; return }
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            let steps = data?.numberOfSteps.intValue
            let notAuthorized = (error as NSError?)?.code == Int(CMErrorMotionActivityNotAuthorized.rawValue)
            Task { @MainActor in
                guard let self else { return }
                if notAuthorized { self.status = .denied }
                if let steps { self.progress.update(cumulativeSteps: steps + self.extraSteps) }
            }
        }
    }

    func stop() { pedometer.stopUpdates() }

    /// Simulator / debugging: no motion hardware.
    func simulate(_ steps: Int) {
        extraSteps += steps
        progress.update(cumulativeSteps: progress.steps + steps)
    }
}

struct StepsMissionView: View {
    let target: Int
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var counter: StepCounter
    @State private var finished = false
    @Environment(\.openURL) private var openURL

    init(target: Int, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.target = target
        self.onComplete = onComplete
        _counter = State(initialValue: StepCounter(target: target))
    }

    var body: some View {
        VStack(spacing: 28) {
            Text("Get walking").font(.title.bold())
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: counter.progress.fraction)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: counter.progress.fraction)
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk").font(.title)
                    Text("\(min(counter.progress.steps, target)) / \(target)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("steps").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 220, maxHeight: 220)

            switch counter.status {
            case .counting:
                Text("Keep the phone with you — steps can take a few seconds to show up.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .unavailable:
                Text("Step counting isn't available on this device.").foregroundStyle(.secondary)
            case .denied:
                VStack(spacing: 8) {
                    Text("Motion & Fitness access is off, so steps can't be counted.")
                        .foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            #if DEBUG
            Button("Simulate 10 steps") { counter.simulate(10) }
                .buttonStyle(.bordered)
            #endif
        }
        .padding(24)
        .onAppear { counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.progress.isComplete) { _, complete in
            guard complete, !finished else { return }
            finished = true
            counter.stop()
            onComplete(.success)
        }
    }
}
