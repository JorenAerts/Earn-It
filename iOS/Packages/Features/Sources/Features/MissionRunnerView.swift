import Coach
import Core
import Localization
import Missions
import SwiftUI
import Telemetry

/// Full-screen, no way back: runs each configured mission in order.
/// Layout: coach → progress (steps + alarm status) → mission card (what to do) → the mission.
struct MissionRunnerView: View {
    let missions: [MissionConfig]
    let reArmCount: Int
    let reArmMinutes: Int
    var coachState = CoachState(mood: .suspicious, context: .ringing)
    var coachLine = ""
    let onAllComplete: () -> Void

    @State private var run: MissionRun
    @State private var showBackupOffer = false
    @State private var stepDone = 0

    init(missions: [MissionConfig], reArmCount: Int, reArmMinutes: Int,
         coachState: CoachState = CoachState(mood: .suspicious, context: .ringing), coachLine: String = "",
         onAllComplete: @escaping () -> Void) {
        self.missions = missions
        self.reArmCount = reArmCount
        self.reArmMinutes = reArmMinutes
        self.coachState = coachState
        self.coachLine = coachLine
        self.onAllComplete = onAllComplete
        _run = State(initialValue: MissionRun(steps: missions))
    }

    var body: some View {
        VStack(spacing: 14) {
            CoachCard(state: coachState, line: coachLine, avatarSize: 72)
                .padding(.horizontal, 20)

            progressBar

            if let current = run.current {
                missionCard(current)
                    .padding(.horizontal, 20)
                    .id("card-\(run.index)-\(current.id)")
                    .transition(.push(from: .trailing))

                MissionRegistry.make(current)
                    .makeView { result in handle(result) }
                    .id("\(run.index)-\(current.id)")
                    .transition(.push(from: .trailing))
                    .frame(maxHeight: .infinity)

                if showBackupOffer {
                    Button {
                        if let current = run.current {
                            Telemetry.shared.send(.missionBackupUsed(kind: current.kind.rawValue))
                        }
                        withAnimation { run.swapToBackup() }
                        showBackupOffer = false
                    } label: {
                        Label("Can't find it? Do a backup mission", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(.top, 12)
        .overlay { if stepDone > 0 { StepDoneFlash(trigger: stepDone) } }
        .sensoryFeedback(.success, trigger: stepDone)
        .interactiveDismissDisabled()
        .onAppear {
            if missions.isEmpty { onAllComplete() }
            Telemetry.shared.send(.missionStarted(kinds: missions.map(\.kind.rawValue).joined(separator: "+"),
                                                  attempt: reArmCount + 1))
        }
        .trackScreen("Mission")
        // Offer the backup after the current step's delay (e.g. 2 min for "Scan your item").
        .task(id: "\(run.index)-\(run.backedUp.count)") {
            showBackupOffer = false
            guard let delay = run.backupDelay else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation { showBackupOffer = true }
        }
    }

    // MARK: Pieces

    private var progressBar: some View {
        VStack(spacing: 8) {
            if run.steps.count > 1 {
                HStack(spacing: 6) {
                    ForEach(run.steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i < run.index ? Color.green : (i == run.index ? Color.orange : Color.secondary.opacity(0.25)))
                            .frame(width: i == run.index ? 28 : 10, height: 8)
                    }
                }
                .animation(.snappy, value: run.index)
                .accessibilityElement()
                .accessibilityLabel("Step \(min(run.index + 1, run.steps.count)) of \(run.steps.count)")
            }
            HStack(spacing: 8) {
                Label("Alarm on until you finish", systemImage: "speaker.wave.3.fill")
                    .foregroundStyle(.orange)
                if reArmCount > 0 {
                    Text("· re-rung \(reArmCount)×").foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))
        }
    }

    private func missionCard(_ config: MissionConfig) -> some View {
        HStack(spacing: 12) {
            Image(systemName: config.kind.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [.orange, .red.opacity(0.85)], startPoint: .top, endPoint: .bottom),
                            in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(run.backedUp.contains(run.index) ? L10n.tr("Backup mission") : config.kind.displayName)
                    .font(.headline)
                Text(config.instruction).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private func handle(_ result: MissionResult) {
        withAnimation(.snappy) {
            switch run.apply(result) {
            case .finished:
                onAllComplete()  // coordinator stops the alarm sound
            case .nextStep:
                stepDone += 1
            case .backupStarted:
                showBackupOffer = false
            }
        }
    }
}

/// Short green checkmark between steps.
private struct StepDoneFlash: View {
    let trigger: Int
    @State private var visible = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 96))
            .foregroundStyle(.white, .green)
            .scaleEffect(visible ? 1 : 0.4)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .task(id: trigger) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { visible = true }
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.easeOut(duration: 0.25)) { visible = false }
            }
            .accessibilityHidden(true)
    }
}
