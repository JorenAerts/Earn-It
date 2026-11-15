import Foundation
import Localization

/// The in-app legal documents (`Config/Legal/<file>.md`), filled with `Config/Legal.json`.
public enum LegalDocumentKind: String, CaseIterable, Identifiable, Sendable {
    case privacy, terms, healthSafety = "health-safety", community

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .privacy: L10n.tr("Privacy Policy")
        case .terms: L10n.tr("Terms of Use")
        case .healthSafety: L10n.tr("Health & Safety")
        case .community: L10n.tr("Community Guidelines")
        }
    }

    public var symbol: String {
        switch self {
        case .privacy: "hand.raised.fill"
        case .terms: "doc.text.fill"
        case .healthSafety: "heart.text.square.fill"
        case .community: "person.3.fill"
        }
    }
}

/// A parsed document: title, effective-date line and blocks.
public struct LegalDocument: Equatable, Sendable {
    public enum Block: Equatable, Sendable, Identifiable {
        case heading(String)
        case paragraph(String)
        case bullets([String])

        public var id: String {
            switch self {
            case .heading(let t): "h:" + t
            case .paragraph(let t): "p:" + t
            case .bullets(let items): "b:" + items.joined(separator: "|")
            }
        }
    }

    public let title: String
    public let blocks: [Block]
    /// Loaded from a translated file (the English original prevails).
    public var isTranslation = false

    public var headings: [String] { blocks.compactMap { if case .heading(let t) = $0 { t } else { nil } } }

    /// Shown wherever a `Legal.json` value is still empty.
    public static let missing = "[to be completed]"

    /// Replaces `{{key}}` with values; unknown or empty keys become `missing`.
    public static func fill(_ text: String, values: [String: String]) -> String {
        var result = ""
        var rest = Substring(text)
        while let open = rest.range(of: "{{") {
            result += rest[..<open.lowerBound]
            guard let close = rest[open.upperBound...].range(of: "}}") else {
                result += rest[open.lowerBound...]
                return result
            }
            let key = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            result += value.isEmpty ? missing : value
            rest = rest[close.upperBound...]
        }
        return result + rest
    }

    /// Minimal Markdown: `# Title`, `## Heading`, `- bullet`, paragraphs (blank-line separated).
    /// Inline Markdown (bold, links) is kept for the view to render.
    public static func parse(_ markdown: String) -> LegalDocument {
        var title = ""
        var blocks: [Block] = []
        var paragraph: [String] = []
        var bullets: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
        }

        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("## ") {
                flush()
                blocks.append(.heading(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flush()
                title = String(line.dropFirst(2))
            } else if line.hasPrefix("- ") {
                if !paragraph.isEmpty { flush() }
                bullets.append(String(line.dropFirst(2)))
            } else {
                if !bullets.isEmpty { flush() }
                paragraph.append(line)
            }
        }
        flush()
        return LegalDocument(title: title, blocks: blocks)
    }

    /// `Legal.json` values (strings only; keys starting with "_" are comments).
    public static func values(from data: Data?) -> [String: String] {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object.compactMapValues { $0 as? String }.filter { !$0.key.hasPrefix("_") }
    }

    /// The document in the current language when `Legal/<kind>.<code>.md` exists, else English.
    /// `english: true` always loads the English original (it prevails).
    public static func load(_ kind: LegalDocumentKind, bundle: Bundle = .main, english: Bool = false,
                            language: String = L10n.languageCode) -> LegalDocument {
        var values = values(from: bundle.url(forResource: "Legal", withExtension: "json").flatMap { try? Data(contentsOf: $0) })
        let translated = english ? nil : L10n.translatedResource(kind.rawValue, ext: "md", subdirectories: ["Legal", nil],
                                                                 code: language, in: bundle)
        if translated != nil { values = localizedValues(values, language: language) }
        guard let url = translated
                ?? bundle.url(forResource: kind.rawValue, withExtension: "md", subdirectory: "Legal")
                ?? bundle.url(forResource: kind.rawValue, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return LegalDocument(title: kind.title, blocks: [.paragraph(L10n.tr("This document couldn't be loaded."))])
        }
        var document = parse(fill(text, values: values))
        document.isTranslation = translated != nil
        return document
    }

    /// `"country.nl": "België"` overrides `"country"` in the Dutch documents (most specific code wins).
    public static func localizedValues(_ values: [String: String], language: String) -> [String: String] {
        var result = values.filter { !$0.key.contains(".") }
        for code in L10n.contentCodes(for: language).reversed() {
            for (key, value) in values where key.hasSuffix(".\(code)") && !value.isEmpty {
                result[String(key.dropLast(code.count + 1))] = value
            }
        }
        return result
    }

    /// Whether a translated version exists for the current language.
    public static func hasTranslation(_ kind: LegalDocumentKind, bundle: Bundle = .main,
                                      language: String = L10n.languageCode) -> Bool {
        L10n.translatedResource(kind.rawValue, ext: "md", subdirectories: ["Legal", nil], code: language, in: bundle) != nil
    }
}
