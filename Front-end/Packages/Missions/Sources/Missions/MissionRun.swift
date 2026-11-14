import Core
import Foundation

/// The steps of one wake-up: which mission is active, what a result does, the backup swap.
/// Pure, so the rules (a backup never counts as success, etc.) are unit-tested.
public struct MissionRun: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case nextStep
        case finished
        case backupStarted
    }

    /// Replaces a mission that can't be done (item not found, no camera): hard, not a shortcut.
    public static func backup() -> MissionConfig {
        MissionConfig(kind: .math, difficulty: .hard, target: 5)
    }

    public private(set) var steps: [MissionConfig]
    public private(set) var index = 0
    /// Steps that were swapped for the backup.
    public private(set) var backedUp: Set<Int> = []

    public init(steps: [MissionConfig]) {
        self.steps = steps
    }

    public var current: MissionConfig? { steps.indices.contains(index) ? steps[index] : nil }
    public var isFinished: Bool { index >= steps.count }

    /// Whether the current step may offer "Can't find it?" (and after how long).
    public var backupDelay: TimeInterval? {
        guard let current, !backedUp.contains(index) else { return nil }
        return current.kind.backupAfter
    }

    public mutating func apply(_ result: MissionResult) -> Outcome {
        switch result {
        case .success:
            index += 1
            return isFinished ? .finished : .nextStep
        case .needsBackup:
            swapToBackup()
            return .backupStarted
        }
    }

    public mutating func swapToBackup() {
        guard steps.indices.contains(index), !backedUp.contains(index) else { return }
        steps[index] = Self.backup()
        backedUp.insert(index)
    }
}
