import Core
import Foundation
import Localization

/// Tongue twisters per difficulty: `Config/TongueTwisters.json` (English) and
/// `Translations/TongueTwisters.<code>.json` (each language has its own, not translations).
public enum TongueTwisters {
    public static func load(from bundle: Bundle = .main, language: String = L10n.languageCode) -> [MissionDifficulty: [String]] {
        func decode(_ url: URL?) -> [String: [String]]? {
            guard let url, let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode([String: [String]].self, from: data)
        }
        let table = decode(L10n.translatedResource("TongueTwisters", ext: "json", subdirectories: ["Translations", nil],
                                                   code: language, in: bundle))
            ?? decode(bundle.url(forResource: "TongueTwisters", withExtension: "json")) ?? [:]
        var result: [MissionDifficulty: [String]] = [:]
        for (key, list) in table { if let d = MissionDifficulty(rawValue: key) { result[d] = list } }
        return result
    }
}

/// Compares typed text with the target, forgiving what doesn't matter on a phone keyboard:
/// case, punctuation, extra spaces and curly vs straight quotes. Letters (incl. accents) must match.
public enum TypingCheck {
    public static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let kept = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) ? Character(scalar) : " "
        }
        return String(kept).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func matches(_ typed: String, _ target: String) -> Bool {
        normalize(typed) == normalize(target)
    }

    /// How many leading characters of the (normalized) target are typed correctly, for the progress hint.
    public static func correctPrefix(_ typed: String, _ target: String) -> Int {
        zip(normalize(typed), normalize(target)).prefix { $0 == $1 }.count
    }
}
