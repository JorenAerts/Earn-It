import Foundation

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

    public static func load(from bundle: Bundle = .main) -> HelpContent {
        func data(_ name: String) -> Data? {
            bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        }
        return decode(help: data("Help"), whatsNew: data("WhatsNew"))
    }

    /// Prefilled support mail: subject + device details that help debugging.
    public static func supportMailURL(to address: String, appVersion: String, systemVersion: String,
                                      model: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Earn It support"),
            URLQueryItem(name: "body", value: "\n\n—\nEarn It \(appVersion) · iOS \(systemVersion) · \(model)"),
        ]
        return components.url
    }
}
