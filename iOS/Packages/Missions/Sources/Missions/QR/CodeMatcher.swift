import Foundation

/// Pure logic for the QR mission: what counts as "the registered code".
public enum CodeMatcher {
    /// Prefix for codes the app generates itself (printable from setup).
    public static let generatedPrefix = "gloop:"

    public static func newPayload() -> String {
        generatedPrefix + UUID().uuidString
    }

    /// Exact match after trimming whitespace/newlines (some printed codes add a trailing newline).
    public static func matches(scanned: String?, expected: String?) -> Bool {
        guard let scanned = normalize(scanned), let expected = normalize(expected) else { return false }
        return scanned == expected
    }

    static func normalize(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
