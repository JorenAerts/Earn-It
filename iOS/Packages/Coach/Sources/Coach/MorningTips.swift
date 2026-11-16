import Foundation
import Localization

/// One line for the success screen: a practical morning tip in Gloop's voice, or a short quote.
public struct MorningTip: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case tip, quote }

    public let id: String
    public let kind: Kind
    public let text: String
    /// Quotes only (a person or "Old proverb").
    public let author: String?

    public init(id: String, kind: Kind, text: String, author: String? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.author = author
    }
}

/// `Shared/Config/MorningTips.json` (English, the full list with ids) + `Translations/MorningTips.<code>.json`
/// (`{ "<id>": { "text": "…", "author": "…"? } }`; anything missing stays English).
public enum MorningTips {
    struct Translation: Codable { let text: String; let author: String? }

    public static func load(from bundle: Bundle = .main, language: String = L10n.languageCode) -> [MorningTip] {
        guard let url = bundle.url(forResource: "MorningTips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let tips = try? JSONDecoder().decode([MorningTip].self, from: data) else { return [] }
        guard let localURL = L10n.translatedResource("MorningTips", ext: "json", subdirectories: ["Translations", nil],
                                                     code: language, in: bundle),
              let localData = try? Data(contentsOf: localURL),
              let local = try? JSONDecoder().decode([String: Translation].self, from: localData) else { return tips }
        return tips.map { tip in
            guard let t = local[tip.id], !t.text.isEmpty else { return tip }
            return MorningTip(id: tip.id, kind: tip.kind, text: t.text, author: t.author ?? tip.author)
        }
    }

    /// The tip for `day`: the same all day (reopening shows the same one), a different one tomorrow,
    /// and no repeats until the whole list has been shown. The order is shuffled with a fixed seed,
    /// so tips and quotes mix.
    public static func pick(from tips: [MorningTip], day: Date, calendar: Calendar = .current) -> MorningTip? {
        guard !tips.isEmpty else { return nil }
        let order = shuffledOrder(count: tips.count)
        let n = dayNumber(day, calendar: calendar) % tips.count
        let index = n < 0 ? n + tips.count : n  // days before the epoch
        return tips[order[index]]
    }

    static func dayNumber(_ day: Date, calendar: Calendar) -> Int {
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch),
                                           to: calendar.startOfDay(for: day)).day ?? 0
    }

    static func shuffledOrder(count: Int) -> [Int] {
        var rng = SplitMix64(seed: 0x6C00_9A11)
        return Array(0..<count).shuffled(using: &rng)
    }
}

/// Small deterministic generator, so the order is the same on every device and every launch.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
