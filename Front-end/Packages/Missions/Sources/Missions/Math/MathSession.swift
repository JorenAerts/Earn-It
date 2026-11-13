import Core
import Foundation

public struct MathProblem: Equatable, Sendable {
    public let text: String
    public let answer: Int
}

/// Deterministic RNG so tests can pin problems.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum MathProblemGenerator {
    public static func make<R: RandomNumberGenerator>(_ difficulty: MissionDifficulty, using rng: inout R) -> MathProblem {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 2...20, using: &rng), b = Int.random(in: 2...20, using: &rng)
            return MathProblem(text: "\(a) + \(b)", answer: a + b)
        case .medium:
            let a = Int.random(in: 3...12, using: &rng), b = Int.random(in: 3...12, using: &rng)
            let c = Int.random(in: 5...40, using: &rng)
            return MathProblem(text: "\(a) × \(b) + \(c)", answer: a * b + c)
        case .hard:
            let a = Int.random(in: 12...29, using: &rng), b = Int.random(in: 6...19, using: &rng)
            let c = Int.random(in: 20...99, using: &rng)
            return MathProblem(text: "\(a) × \(b) − \(c)", answer: a * b - c)
        }
    }
}

/// N correct in a row. A wrong answer resets the run and gives a new problem.
public struct MathSession<R: RandomNumberGenerator> {
    public let target: Int
    public let difficulty: MissionDifficulty
    public private(set) var correctInRow = 0
    public private(set) var problem: MathProblem
    private var rng: R

    public init(target: Int, difficulty: MissionDifficulty, rng: R) {
        self.target = max(1, target)
        self.difficulty = difficulty
        self.rng = rng
        self.problem = MathProblemGenerator.make(difficulty, using: &self.rng)
    }

    public var isComplete: Bool { correctInRow >= target }

    /// Returns whether the answer was correct.
    @discardableResult
    public mutating func submit(_ answer: Int) -> Bool {
        guard !isComplete else { return true }
        let correct = answer == problem.answer
        correctInRow = correct ? correctInRow + 1 : 0
        if !isComplete { problem = MathProblemGenerator.make(difficulty, using: &rng) }
        return correct
    }
}
