import SwiftUI
import Telemetry

/// Shows a legal document inside the app (no browser): title, contents, sections.
struct LegalDocumentView: View {
    let kind: LegalDocumentKind
    @State private var document: LegalDocument?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let document {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(document.title).font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        // "Effective …" line right under the title, then the contents.
                        let dated = document.blocks.first.map { if case .paragraph(let t) = $0 { t.hasPrefix("Effective ") } else { false } } ?? false
                        if dated, let first = document.blocks.first { view(for: first).padding(.top, -8) }
                        if document.headings.count >= 5 {
                            contents(document, proxy: proxy)
                        }
                        ForEach(Array(document.blocks.dropFirst(dated ? 1 : 0).enumerated()), id: \.offset) { _, block in
                            view(for: block)
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { document = LegalDocument.load(kind) }
        .trackScreen("Legal.\(kind.rawValue)")
    }

    private func contents(_ document: LegalDocument, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contents").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
            ForEach(document.headings, id: \.self) { heading in
                Button(heading) { withAnimation { proxy.scrollTo("h:" + heading, anchor: .top) } }
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func view(for block: LegalDocument.Block) -> some View {
        switch block {
        case .heading(let text):
            Text(text).font(.title3.bold()).padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
                .id("h:" + text)
        case .paragraph(let text):
            Text(Self.inline(text)).font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(text.hasPrefix("Effective ") ? .secondary : .primary)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.orange)
                        Text(Self.inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Bold / italic / links; emails become tappable mail links.
    static func inline(_ text: String) -> AttributedString {
        let linked = text.replacing(#/([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/#) { match in
            "[\(match.output.1)](mailto:\(match.output.1))"
        }
        return (try? AttributedString(markdown: linked, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// A legal document presented as a sheet (paywall, sign-up, onboarding).
struct LegalSheet: View {
    let kind: LegalDocumentKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LegalDocumentView(kind: kind)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// "By continuing you accept the Terms of Use and Privacy Policy." with in-app sheets.
struct LegalConsentLine: View {
    var prefix = "By continuing you accept the"
    @State private var showing: LegalDocumentKind?

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix + " ").foregroundStyle(.secondary)
            Button("Terms") { showing = .terms }
            Text(" and ").foregroundStyle(.secondary)
            Button("Privacy Policy") { showing = .privacy }
            Text(".").foregroundStyle(.secondary)
        }
        .font(.caption)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .sheet(item: $showing) { LegalSheet(kind: $0) }
    }
}
