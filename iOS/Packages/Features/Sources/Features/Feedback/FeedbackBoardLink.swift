import Foundation

/// Pure helpers for the feedback board web page (`Web/feedback`, GitHub Pages) shown in
/// Settings › Help & feedback › Suggest a feature. The app hands over only the access token
/// (`window.__gloopEmbed`); the page asks for a fresh one via the `gloop` message handler and
/// never sees the refresh token, so it can't rotate the app's session.
public enum FeedbackBoardLink {
    /// Name of the `WKScriptMessageHandler` the page posts `{type: "needsSession"}` to.
    public static let messageHandler = "gloop"

    /// `<feedbackURL>?embed=1&lang=<code>` (existing query items are kept).
    public static func url(base: URL, language: String) -> URL {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        var items = (parts.queryItems ?? []).filter { $0.name != "embed" && $0.name != "lang" }
        items.append(URLQueryItem(name: "embed", value: "1"))
        items.append(URLQueryItem(name: "lang", value: language))
        parts.queryItems = items
        return parts.url ?? base
    }

    /// Injected at document start, before the page's own scripts run.
    public static func sessionScript(accessToken: String?) -> String {
        "window.__gloopEmbed = { accessToken: \(jsonString(accessToken)) };"
    }

    /// Answer to `needsSession` (evaluated in the page).
    public static func receiveScript(accessToken: String?) -> String {
        "window.gloopReceiveSession && window.gloopReceiveSession(\(jsonString(accessToken)));"
    }

    /// Only the board's own site loads inside the web view; any other link opens in Safari.
    public static func staysInside(_ url: URL, base: URL) -> Bool {
        if url.scheme == "about" { return true }
        return url.scheme == "https" && url.host()?.lowercased() == base.host()?.lowercased()
    }

    /// A JavaScript string literal (or `null`), escaped by JSON so quotes and newlines can't break out.
    static func jsonString(_ value: String?) -> String {
        guard let value,
              let data = try? JSONSerialization.data(withJSONObject: [value], options: [.fragmentsAllowed]),
              let array = String(data: data, encoding: .utf8)
        else { return "null" }
        // ["…"] → "…"; also keep `</script>`-like sequences harmless.
        return String(array.dropFirst().dropLast()).replacingOccurrences(of: "</", with: "<\\/")
    }
}
