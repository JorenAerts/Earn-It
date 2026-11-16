import Foundation

/// Pure memory-match state. Flip two cards: a pair stays open, otherwise both close again
/// (`closeMismatch()` after a short delay in the UI).
public struct MemoryGame: Sendable, Equatable {
    public struct Card: Identifiable, Equatable, Sendable {
        public let id: Int
        public let face: String
        public var isUp = false
        public var isMatched = false
    }

    public enum FlipResult: Equatable, Sendable { case ignored, first, match, mismatch }

    public private(set) var cards: [Card]
    public private(set) var moves = 0
    private var open: [Int] = []

    /// Emoji faces used for the cards (enough for the hardest board).
    public static let faces = ["☀️", "🌙", "⭐️", "☕️", "🍓", "🍋", "🐸", "🐙", "🦊", "🐝", "🌵", "🍩"]

    public init<RNG: RandomNumberGenerator>(pairs: Int, rng: inout RNG) {
        let faces = Array(Self.faces.shuffled(using: &rng).prefix(max(2, min(pairs, Self.faces.count))))
        cards = (faces + faces).shuffled(using: &rng).enumerated().map { Card(id: $0.offset, face: $0.element) }
    }

    public var isComplete: Bool { cards.allSatisfy(\.isMatched) }
    /// Two non-matching cards are face up and must be closed before the next flip.
    public var needsClose: Bool { open.count == 2 }

    public mutating func flip(_ index: Int) -> FlipResult {
        guard cards.indices.contains(index), !needsClose, !cards[index].isUp, !cards[index].isMatched else { return .ignored }
        cards[index].isUp = true
        open.append(index)
        guard open.count == 2 else { return .first }
        moves += 1
        let (a, b) = (open[0], open[1])
        if cards[a].face == cards[b].face {
            cards[a].isMatched = true
            cards[b].isMatched = true
            open = []
            return .match
        }
        return .mismatch
    }

    public mutating func closeMismatch() {
        for i in open { cards[i].isUp = false }
        open = []
    }
}
