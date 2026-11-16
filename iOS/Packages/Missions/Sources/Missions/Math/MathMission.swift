import Core
import SwiftUI

public struct MathMission: Mission {
    public static let kind: MissionKind = .math
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(MathMissionView(config: config, onComplete: onComplete))
    }
}

struct MathMissionView: View {
    let config: MissionConfig
    let onComplete: @MainActor (MissionResult) -> Void

    @State private var session: MathSession<SystemRandomNumberGenerator>
    @State private var input = ""
    @State private var shake = false
    @FocusState private var focused: Bool

    init(config: MissionConfig, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.config = config
        self.onComplete = onComplete
        _session = State(initialValue: MathSession(target: config.target, difficulty: config.difficulty,
                                                   rng: SystemRandomNumberGenerator()))
    }

    var body: some View {
        VStack(spacing: 28) {
            Text("\(session.correctInRow) / \(session.target) correct in a row")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(session.problem.text)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .offset(x: shake ? -12 : 0)

            TextField("Answer", text: $input)
                .keyboardType(.numbersAndPunctuation)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding()
                .background(.quaternary, in: .rect(cornerRadius: 16))
                .focused($focused)
                .onSubmit(submit)
                .submitLabel(.done)

            Button("Submit", action: submit)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(Int(input.trimmingCharacters(in: .whitespaces)) == nil)
        }
        .padding(24)
        .onAppear { focused = true }
    }

    private func submit() {
        guard let value = Int(input.trimmingCharacters(in: .whitespaces)) else { return }
        input = ""
        if !session.submit(value) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.2)) { shake = true }
            withAnimation(.spring.delay(0.15)) { shake = false }
        }
        if session.isComplete { onComplete(.success) }
    }
}
