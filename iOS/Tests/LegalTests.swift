import Features
import Foundation
import Testing

struct LegalTests {
    static let config = TestPaths.shared

    private func raw(_ kind: LegalDocumentKind) throws -> String {
        try String(contentsOf: Self.config.appending(path: "Legal/\(kind.rawValue).md"), encoding: .utf8)
    }

    private var values: [String: String] {
        LegalDocument.values(from: try? Data(contentsOf: Self.config.appending(path: "Legal.json")))
    }

    @Test func everyDocumentLoadsWithTitleAndDate() throws {
        for kind in LegalDocumentKind.allCases {
            let doc = LegalDocument.parse(LegalDocument.fill(try raw(kind), values: values))
            #expect(doc.title == kind.title, "\(kind)")
            #expect(doc.blocks.first == .paragraph("Effective 15 November 2026"), "\(kind)")
            #expect(doc.headings.count >= 4, "\(kind)")
        }
    }

    @Test func everyPlaceholderIsKnown() throws {
        let keys = Set(values.keys)
        for kind in LegalDocumentKind.allCases {
            let text = try raw(kind)
            let used = text.matches(of: #/\{\{\s*([a-zA-Z]+)\s*\}\}/#).map { String($0.output.1) }
            for key in used { #expect(keys.contains(key), "\(kind) uses {{\(key)}} which isn't in Legal.json") }
            #expect(LegalDocument.fill(text, values: values).contains("{{") == false)
        }
    }

    @Test func missingValuesAreVisible() {
        #expect(LegalDocument.fill("Contact {{privacyEmail}} at {{company}}.", values: ["company": "JA-Solutions", "privacyEmail": " "])
                == "Contact [to be completed] at JA-Solutions.")
        #expect(LegalDocument.fill("Broken {{oops", values: [:]) == "Broken {{oops")
    }

    @Test func privacyPolicyMatchesWhatTheAppDoes() throws {
        let text = try raw(.privacy)
        for fact in ["Supabase", "TelemetryDeck", "Apple", "24 hours", "Delete account", "Settings › Privacy",
                     "Data Protection Authority", "{{minimumAge}}", "Standard Contractual Clauses",
                     "Feedback board", "GitHub Pages"] {
            #expect(text.contains(fact), "privacy policy should mention \(fact)")
        }
    }

    @Test func termsCoverSubscriptionsAndApple() throws {
        let text = try raw(.terms)
        for fact in ["renew automatically", "24 hours before", "free trial", "Apple is not responsible",
                     "third-party beneficiaries", "Belgian law", "Community Guidelines"] {
            #expect(text.contains(fact), "terms should mention \(fact)")
        }
    }

    @Test func parserHandlesBlocks() {
        let doc = LegalDocument.parse("""
        # Title

        Intro line one
        line two

        ## Section
        - first
        - second **bold**
        After list
        """)
        #expect(doc.title == "Title")
        #expect(doc.blocks == [.paragraph("Intro line one\nline two"), .heading("Section"),
                               .bullets(["first", "second **bold**"]), .paragraph("After list")])
    }

    @Test func valuesSkipComments() {
        let data = Data(#"{"_help": "x", "company": "JA", "minimumAge": "13"}"#.utf8)
        #expect(LegalDocument.values(from: data) == ["company": "JA", "minimumAge": "13"])
    }
}
