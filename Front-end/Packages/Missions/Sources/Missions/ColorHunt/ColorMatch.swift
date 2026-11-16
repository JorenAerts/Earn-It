import Foundation

/// Colours for the colour hunt: a hue window plus minimum saturation/brightness, so grey,
/// black and white never count.
public enum ColorTarget: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, pink

    /// Centre hue in degrees and allowed distance either side.
    var hue: (center: Double, tolerance: Double) {
        switch self {
        case .red: (0, 14)
        case .orange: (28, 12)
        case .yellow: (54, 12)
        case .green: (120, 40)
        case .blue: (215, 30)
        case .purple: (275, 22)
        case .pink: (325, 18)
        }
    }

    var minimumSaturation: Double { self == .pink ? 0.25 : 0.4 }
    var minimumBrightness: Double { self == .yellow ? 0.45 : 0.25 }
}

public enum ColorMatch {
    /// Smallest angle between two hues (0…180), wrapping around red.
    public static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    /// `hue` in degrees (0…360), saturation and brightness 0…1.
    public static func matches(hue: Double, saturation: Double, brightness: Double, target: ColorTarget) -> Bool {
        saturation >= target.minimumSaturation && brightness >= target.minimumBrightness
            && hueDistance(hue, target.hue.center) <= target.hue.tolerance
    }

    /// `count` different colours in random order.
    public static func targets<RNG: RandomNumberGenerator>(count: Int, rng: inout RNG) -> [ColorTarget] {
        Array(ColorTarget.allCases.shuffled(using: &rng).prefix(max(1, min(count, ColorTarget.allCases.count))))
    }

    /// Frames in a row with the colour in the middle (~1 s).
    public static let requiredFrames = 4
}
