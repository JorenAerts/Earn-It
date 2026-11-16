import Foundation

/// Rules for "this is your made bed", from whole-frame feature-print distances (same scale as the
/// item scan: ~0 identical, ~1+ unrelated). A messy duvet changes the picture enough to push the
/// distance over the threshold. Tuned on device; the DEBUG line under the camera shows live values.
public enum BedMatchPolicy {
    /// Photos taken at setup (foot of the bed, a step left, a step right).
    public static let requiredShots = 3
    /// Matching frames in a row.
    public static let requiredFrames = 4
    /// Bounds for the per-bed threshold: stricter than items, since the room around the bed is the same.
    public static let minimumThreshold: Float = 0.25
    public static let maximumThreshold: Float = 0.55
    public static let thresholdMargin: Float = 1.2
    /// Each setup shot must differ a little from the previous one (user stepped aside).
    public static let minimumShotChange: Float = 0.04

    public static func threshold(pairwiseDistances: [Float]) -> Float {
        guard let widest = pairwiseDistances.max() else { return minimumThreshold }
        return min(maximumThreshold, max(minimumThreshold, widest * thresholdMargin))
    }

    public static func isMatch(distance: Float, threshold: Float) -> Bool { distance <= threshold }
}
