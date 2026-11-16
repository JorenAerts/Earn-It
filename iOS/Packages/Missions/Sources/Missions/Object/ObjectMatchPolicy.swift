import Foundation

/// Pure rules for recognising the user's registered item from feature-print distances
/// (Vision `VNFeaturePrintObservation.computeDistance`, revision 2: ~0 = identical, ~1+ = unrelated).
/// Constants are tuned on device; the debug overlay on the mission screen shows live distances.
public enum ObjectMatchPolicy {
    /// Angles captured during setup.
    public static let requiredShots = 5
    /// Matching frames in a row needed to finish the mission (rejects a lucky single frame).
    public static let requiredConsecutive = 4
    /// Each new setup shot must differ at least this much from the previous one (user moved).
    public static let minimumAngleChange: Float = 0.06
    /// Bounds for the per-item threshold.
    public static let minimumThreshold: Float = 0.35
    public static let maximumThreshold: Float = 0.75
    /// Margin on top of the biggest difference seen between the item's own angles.
    public static let thresholdMargin: Float = 1.15

    /// Per-item match threshold from the distances between its reference shots: an item that
    /// looks very different from each angle gets a looser threshold, a uniform one a stricter one.
    public static func threshold(pairwiseDistances: [Float]) -> Float {
        guard let widest = pairwiseDistances.max() else { return minimumThreshold }
        return min(maximumThreshold, max(minimumThreshold, widest * thresholdMargin))
    }

    public static func isMatch(distance: Float, threshold: Float) -> Bool {
        distance <= threshold
    }

    /// 0…1 "how close" for the live meter: 1 at or under the threshold, 0 when far away.
    public static func closeness(distance: Float, threshold: Float) -> Double {
        let far = threshold * 2
        guard distance > threshold else { return 1 }
        return Double(max(0, min(1, (far - distance) / (far - threshold))))
    }

    public static func isDistinctAngle(distanceToPrevious: Float) -> Bool {
        distanceToPrevious >= minimumAngleChange
    }
}

/// Counts consecutive matching frames.
public struct ObjectMatchTracker: Equatable, Sendable {
    public private(set) var streak = 0
    public private(set) var lastCloseness: Double = 0

    public init() {}

    public var isComplete: Bool { streak >= ObjectMatchPolicy.requiredConsecutive }

    /// Feed one analysed frame. `distance == nil` means no object was found in the frame.
    public mutating func record(distance: Float?, threshold: Float) {
        guard let distance else {
            streak = 0
            lastCloseness = 0
            return
        }
        lastCloseness = ObjectMatchPolicy.closeness(distance: distance, threshold: threshold)
        streak = ObjectMatchPolicy.isMatch(distance: distance, threshold: threshold) ? streak + 1 : 0
    }
}
