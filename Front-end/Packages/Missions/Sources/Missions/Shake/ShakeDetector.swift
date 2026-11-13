import Foundation

/// Counts shakes from raw accelerometer samples (in g, gravity included).
/// A shake = magnitude crosses `threshold`, at least `minInterval` after the previous one.
public struct ShakeDetector: Sendable {
    public var threshold: Double
    public var minInterval: TimeInterval
    public private(set) var count = 0
    private var lastShake: TimeInterval?

    public init(threshold: Double = 2.0, minInterval: TimeInterval = 0.25) {
        self.threshold = threshold
        self.minInterval = minInterval
    }

    /// Returns true when this sample registered a new shake.
    @discardableResult
    public mutating func process(x: Double, y: Double, z: Double, timestamp: TimeInterval) -> Bool {
        let magnitude = (x * x + y * y + z * z).squareRoot()
        guard magnitude >= threshold else { return false }
        if let lastShake, timestamp - lastShake < minInterval { return false }
        lastShake = timestamp
        count += 1
        return true
    }
}
