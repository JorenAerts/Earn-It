import Account
import Features
import Foundation
import Telemetry
import Testing

@Suite struct FeedbackBoardTests {
    private let base = URL(string: "https://jorenaerts.github.io/Earn-It/feedback/")!

    @Test func urlAddsEmbedAndLanguage() throws {
        let url = FeedbackBoardLink.url(base: base, language: "pt-BR")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.path() == "/Earn-It/feedback/")
        #expect(items.contains(URLQueryItem(name: "embed", value: "1")))
        #expect(items.contains(URLQueryItem(name: "lang", value: "pt-BR")))

        let again = FeedbackBoardLink.url(base: URL(string: "https://x.dev/f/?lang=en&a=b")!, language: "nl")
        let names = URLComponents(url: again, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name)
        #expect(names == ["a", "embed", "lang"], "an old lang item is replaced, others kept")
    }

    @Test func scriptsEscapeTheToken() {
        let tricky = #"a"b\c</script>"#
        let script = FeedbackBoardLink.sessionScript(accessToken: tricky)
        #expect(script == #"window.__gloopEmbed = { accessToken: "a\"b\\c<\/script>" };"#)
        #expect(FeedbackBoardLink.sessionScript(accessToken: nil) == "window.__gloopEmbed = { accessToken: null };")
        #expect(FeedbackBoardLink.receiveScript(accessToken: "abc.def")
                == #"window.gloopReceiveSession && window.gloopReceiveSession("abc.def");"#)
    }

    @Test func onlyTheBoardsSiteStaysInside() {
        #expect(FeedbackBoardLink.staysInside(URL(string: "https://jorenaerts.github.io/Earn-It/legal/privacy.md")!, base: base))
        #expect(FeedbackBoardLink.staysInside(URL(string: "about:blank")!, base: base))
        #expect(!FeedbackBoardLink.staysInside(URL(string: "http://jorenaerts.github.io/Earn-It/feedback/")!, base: base))
        #expect(!FeedbackBoardLink.staysInside(URL(string: "https://evil.example/feedback/")!, base: base))
        #expect(!FeedbackBoardLink.staysInside(URL(string: "mailto:a@b.be")!, base: base))
    }

    @Test func configHidesTheRowUntilAnHTTPSURLIsSet() throws {
        func decode(_ value: String) throws -> URL? {
            let json = #"{"redirectURL":"gloop://auth-callback","feedbackURL":"\#(value)"}"#
            return try JSONDecoder().decode(AuthConfig.self, from: Data(json.utf8)).feedbackURL
        }
        #expect(try decode("") == nil)
        #expect(try decode("  ") == nil)
        #expect(try decode("http://example.com/feedback/") == nil)
        #expect(try decode("not a url") == nil)
        #expect(try decode("https://jorenaerts.github.io/Earn-It/feedback/") == base)
        let old = try JSONDecoder().decode(AuthConfig.self, from: Data(#"{"redirectURL":"gloop://x"}"#.utf8))
        #expect(old.feedbackURL == nil)
    }

    @Test func bundledAuthConfigHasTheKey() throws {
        let text = try String(contentsOf: TestPaths.shared.appending(path: "Auth.json"), encoding: .utf8)
        #expect(text.contains(#""feedbackURL""#))
    }

    @Test func telemetryEventHasNoFreeText() {
        let event = TelemetryEvent.action(.feedbackBoardOpened(signedIn: true))
        #expect(event.name == "Feedback.boardOpened")
        #expect(event.parameters == ["signedIn": "true"])
    }
}
