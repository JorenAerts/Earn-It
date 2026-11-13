import Foundation

/// Pure progress for the steps mission. Pedometer counts are cumulative since the mission started.
public struct StepProgress: Equatable, Sendable {
    public let target: Int
    public private(set) var steps = 0

    public init(target: Int) {
        self.target = max(1, target)
    }

    public var isComplete: Bool { steps >= target }
    public var fraction: Double { min(1, Double(steps) / Double(target)) }
    public var remaining: Int { max(0, target - steps) }

    /// Pedometer reports can arrive out of order; never go backwards.
    public mutating func update(cumulativeSteps: Int) {
        steps = max(steps, cumulativeSteps)
    }
}
