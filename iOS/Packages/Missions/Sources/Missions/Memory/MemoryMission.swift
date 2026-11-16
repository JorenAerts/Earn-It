import Core
import SwiftUI

public struct MemoryMission: Mission {
    public static let kind: MissionKind = .memory
    public let config: MissionConfig

    public init(config: MissionConfig) { self.config = config }

    public func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView {
        AnyView(MemoryMissionView(config: config, onComplete: onComplete))
    }
}

struct MemoryMissionView: View {
    let config: MissionConfig
    let onComplete: @MainActor (MissionResult) -> Void
    @State private var game: MemoryGame

    init(config: MissionConfig, onComplete: @escaping @MainActor (MissionResult) -> Void) {
        self.config = config
        self.onComplete = onComplete
        var rng = SystemRandomNumberGenerator()
        _game = State(initialValue: MemoryGame(pairs: config.memoryPairs, rng: &rng))
    }

    private var columns: Int { config.memoryPairs >= 8 ? 4 : 3 }

    var body: some View {
        VStack(spacing: 18) {
            Text("\(game.cards.filter(\.isMatched).count / 2) / \(config.memoryPairs) pairs")
                .font(.headline).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                ForEach(game.cards) { card in
                    CardView(card: card)
                        .onTapGesture { flip(card.id) }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 520)
    }

    private func flip(_ index: Int) {
        let result = withAnimation(.spring(duration: 0.25)) { game.flip(index) }
        switch result {
        case .match:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if game.isComplete { onComplete(.success) }
        case .mismatch:
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                withAnimation(.spring(duration: 0.25)) { game.closeMismatch() }
            }
        case .first, .ignored: break
        }
    }
}

private struct CardView: View {
    let card: MemoryGame.Card

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(card.isUp || card.isMatched ? Color(.secondarySystemGroupedBackground) : Color.orange)
            if card.isUp || card.isMatched {
                Text(card.face).font(.system(size: 34))
            } else {
                Image(systemName: "questionmark").font(.title2.bold()).foregroundStyle(.white.opacity(0.85))
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .opacity(card.isMatched ? 0.45 : 1)
        .rotation3DEffect(.degrees(card.isUp || card.isMatched ? 0 : 180), axis: (0, 1, 0))
        .accessibilityLabel(card.isUp || card.isMatched ? Text(card.face) : Text("Hidden card"))
        .accessibilityAddTraits(.isButton)
    }
}
