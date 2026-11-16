import Core
import Localization
import SwiftUI

public struct TypingMission: Mission {
    public static let kind: MissionKind = .typing
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(TypingMissionView(config: config, onComplete: onComplete))
    }
}

struct TypingMissionView: View {
    let config: MissionConfig
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var queue: [String]
    @State private var done = 0
    @State private var input = ""
    @State private var shake = false
    @FocusState private var focused: Bool

    init(config: MissionConfig, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.config = config
        self.onComplete = onComplete
        let list = TongueTwisters.load()[config.difficulty] ?? TongueTwisters.load()[.medium] ?? []
        _queue = State(initialValue: Array(list.shuffled().prefix(max(1, config.target))))
    }

    private var current: String? { queue.indices.contains(done) ? queue[done] : nil }

    var body: some View {
        VStack(spacing: 22) {
            Text("\(done) / \(queue.count) done").font(.headline).foregroundStyle(.secondary)
            if let current {
                Text(current)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(x: shake ? -10 : 0)
                ProgressView(value: Double(TypingCheck.correctPrefix(input, current)),
                             total: Double(max(1, TypingCheck.normalize(current).count)))
                    .tint(.orange)
                TextField("Type it here", text: $input, axis: .vertical)
                    .lineLimit(2...4)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.title3)
                    .padding()
                    .background(.quaternary, in: .rect(cornerRadius: 16))
                    .focused($focused)
                    .onChange(of: input) { check(current) }
                Text("Capitals and punctuation don't matter.").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Continue") { onComplete(.needsBackup) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 560)
        .onAppear { focused = true }
    }

    private func check(_ target: String) {
        if TypingCheck.matches(input, target) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            input = ""
            done += 1
            if done >= queue.count { onComplete(.success) }
        } else if TypingCheck.correctPrefix(input, target) < TypingCheck.normalize(input).count {
            // Typo: nudge (the bar shows how far it's still right).
            withAnimation(.spring(response: 0.15, dampingFraction: 0.2)) { shake = true }
            withAnimation(.spring.delay(0.15)) { shake = false }
        }
    }
}
