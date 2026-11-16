import Foundation

/// Is the camera looking at the sky? Works on the labels of Vision's image classifier.
/// Day, night, clouds, rain, sunrise and sunset all count.
public enum SkyPolicy {
    /// Words in a classifier label (split on "_") that mean "sky".
    public static let skyWords: Set<String> = [
        "sky", "cloud", "clouds", "cloudy", "overcast", "sunset", "sunrise", "dusk", "dawn",
        "rain", "rainbow", "storm", "thunderstorm", "lightning", "moon", "starry", "fog",
    ]
    /// Minimum classifier confidence for a frame to count as sky (tuned on device).
    public static let threshold: Float = 0.25
    /// Sky frames in a row (~1.2 s at 0.3 s per frame).
    public static let requiredFrames = 4

    public static func isSkyLabel(_ identifier: String) -> Bool {
        let words = identifier.lowercased().split(whereSeparator: { $0 == "_" || $0 == " " || $0 == "-" }).map(String.init)
        return words.contains(where: skyWords.contains)
    }

    /// Highest confidence among sky labels (0 when none).
    public static func score(_ labels: [(identifier: String, confidence: Float)]) -> Float {
        labels.filter { isSkyLabel($0.identifier) }.map(\.confidence).max() ?? 0
    }

    public static func isSky(_ score: Float) -> Bool { score >= threshold }
}
