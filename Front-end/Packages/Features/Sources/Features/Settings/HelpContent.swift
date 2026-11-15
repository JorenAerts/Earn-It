import Foundation
import Localization

/// `Config/Help.json` (FAQ) and `Config/WhatsNew.json`.
public struct HelpContent: Equatable, Sendable {
    public struct Question: Decodable, Equatable, Sendable, Identifiable {
        public let question: String
        public let answer: String
        public var id: String { question }
    }

    public struct Release: Decodable, Equatable, Sendable, Identifiable {
        public let version: String
        public let items: [String]
        public var id: String { version }
    }

    public let faq: [Question]
    public let releases: [Release]

    public init(faq: [Question], releases: [Release]) {
        self.faq = faq
        self.releases = releases
    }

    public static func decode(help: Data?, whatsNew: Data?) -> HelpContent {
        struct HelpFile: Decodable { let faq: [Question]? }
        struct NewsFile: Decodable { let releases: [Release]? }
        let faq = help.flatMap { try? JSONDecoder().decode(HelpFile.self, from: $0) }?.faq ?? []
        let releases = whatsNew.flatMap { try? JSONDecoder().decode(NewsFile.self, from: $0) }?.releases ?? []
        return HelpContent(faq: faq, releases: releases)
    }

    /// In the current language when `Translations/<name>.<code>.json` exists; per release, missing
    /// translations fall back to the English notes.
    public static func load(from bundle: Bundle = .main, language: String = L10n.languageCode) -> HelpContent {
        func english(_ name: String) -> Data? {
            bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        }
        func translated(_ name: String) -> Data? {
            L10n.translatedResource(name, ext: "json", subdirectories: ["Translations", nil], code: language, in: bundle)
                .flatMap { try? Data(contentsOf: $0) }
        }
        let base = decode(help: english("Help"), whatsNew: english("WhatsNew"))
        let local = decode(help: translated("Help"), whatsNew: translated("WhatsNew"))
        let releases = base.releases.map { release in local.releases.first { $0.version == release.version } ?? release }
        return HelpContent(faq: local.faq.isEmpty ? base.faq : local.faq, releases: releases)
    }

    /// Prefilled support mail: subject + device details that help debugging.
    public static func supportMailURL(to address: String, appVersion: String, systemVersion: String,
                                      model: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: L10n.tr("Gloop support")),
            URLQueryItem(name: "body", value: "\n\n—\nGloop \(appVersion) · iOS \(systemVersion) · \(model)"),
        ]
        return components.url
    }
}
