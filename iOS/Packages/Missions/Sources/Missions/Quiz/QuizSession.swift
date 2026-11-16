import Foundation

/// Pure quiz state: questions in random order (each once until all were asked), shuffled options,
/// done after `target` correct answers. A wrong answer just moves on.
public struct QuizSession<RNG: RandomNumberGenerator>: Sendable where RNG: Sendable {
    public struct Round: Equatable, Sendable {
        public let question: QuizQuestion
        public let options: [String]
        public var correctIndex: Int { options.firstIndex(of: question.answer) ?? 0 }
    }

    public let target: Int
    public private(set) var correct = 0
    public private(set) var round: Round?
    private var deck: [QuizQuestion]
    private let all: [QuizQuestion]
    private var rng: RNG

    public init(questions: [QuizQuestion], target: Int, rng: RNG) {
        self.all = questions
        self.target = max(1, min(target, questions.count))
        self.rng = rng
        self.deck = []
        next()
    }

    public var isComplete: Bool { correct >= target }

    /// Returns whether the picked option was right, and advances to the next question.
    @discardableResult
    public mutating func answer(_ index: Int) -> Bool {
        guard let round else { return false }
        let right = index == round.correctIndex
        if right { correct += 1 }
        if !isComplete { next() }
        return right
    }

    private mutating func next() {
        guard !all.isEmpty else { round = nil; return }
        if deck.isEmpty {
            deck = all.shuffled(using: &rng)
            // Don't repeat the question that was just shown.
            if deck.count > 1, let current = round?.question, deck.last == current { deck.swapAt(0, deck.count - 1) }
        }
        let question = deck.removeLast()
        let options = ([question.answer] + question.wrong.prefix(3)).shuffled(using: &rng)
        round = Round(question: question, options: options)
    }
}
