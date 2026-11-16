import Core
import Localization
import SwiftUI

public struct QuizMission: Mission {
    public static let kind: MissionKind = .quiz
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(QuizMissionView(config: config, onComplete: onComplete))
    }

    @MainActor public static func makeSetupView(config: Binding<MissionConfig>) -> AnyView? {
        AnyView(Picker("Topic", selection: config.quizTopic) {
            ForEach(QuizTopic.allCases) { topic in
                Label(topic.title, systemImage: topic.symbol).tag(topic)
            }
        }
        .pickerStyle(.navigationLink))
    }
}

struct QuizMissionView: View {
    let config: MissionConfig
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var session: QuizSession<SystemRandomNumberGenerator>
    @State private var picked: Int?
    @State private var locked = false

    init(config: MissionConfig, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.config = config
        self.onComplete = onComplete
        _session = State(initialValue: QuizSession(questions: QuizBank.questions(for: config.quizTopic),
                                                   target: config.target, rng: SystemRandomNumberGenerator()))
    }

    var body: some View {
        VStack(spacing: 22) {
            Label(config.quizTopic.title, systemImage: config.quizTopic.symbol)
                .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            Text("\(session.correct) / \(session.target) correct")
                .font(.headline).foregroundStyle(.secondary)
            if let round = session.round {
                Text(round.question.question)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(round.question.question)
                VStack(spacing: 10) {
                    ForEach(Array(round.options.enumerated()), id: \.offset) { index, option in
                        Button { choose(index, round: round) } label: {
                            Text(option)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(tint(index, round: round))
                        .disabled(locked)
                    }
                }
            } else {
                // No questions bundled (should not happen): don't trap the user.
                Button("Continue") { onComplete(.needsBackup) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 560)
    }

    private func tint(_ index: Int, round: QuizSession<SystemRandomNumberGenerator>.Round) -> Color {
        guard let picked else { return .orange }
        if index == round.correctIndex { return .green }
        return index == picked ? .red : .gray
    }

    private func choose(_ index: Int, round: QuizSession<SystemRandomNumberGenerator>.Round) {
        picked = index
        locked = true
        let right = index == round.correctIndex
        UINotificationFeedbackGenerator().notificationOccurred(right ? .success : .error)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(right ? 450 : 1100))  // a moment to see the right answer
            session.answer(index)
            picked = nil
            locked = false
            if session.isComplete { onComplete(.success) }
        }
    }
}
