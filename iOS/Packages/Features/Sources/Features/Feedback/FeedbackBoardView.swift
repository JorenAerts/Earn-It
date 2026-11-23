import Account
import Localization
import SwiftUI
import Telemetry
import UIKit
import WebKit

/// Settings › Help & feedback › Suggest a feature: the web feedback board in a WKWebView, signed
/// in with the app's account (see `FeedbackBoardLink`). Needs an account; otherwise asks to sign in.
struct FeedbackBoardView: View {
    let auth: any AuthService
    let base: URL

    @State private var token: String?
    @State private var tokenLoaded = false
    @State private var phase: FeedbackWebView.Phase = .loading
    @State private var reloadID = 0
    @State private var showSignIn = false

    var body: some View {
        content
            .navigationTitle("Suggest a feature")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Telemetry.shared.send(.action(.feedbackBoardOpened(signedIn: auth.user != nil))) }
            .trackScreen("FeedbackBoard")
            .task(id: auth.user?.id) { await loadToken() }
            .sheet(isPresented: $showSignIn) {
                AccountStepView(auth: auth, skipTitle: L10n.tr("Not now")) { showSignIn = false }
            }
            .onChange(of: auth.user) { _, user in if user != nil { showSignIn = false } }
    }

    @ViewBuilder private var content: some View {
        if auth.user == nil {
            ContentUnavailableView {
                Label("Sign in to share ideas", systemImage: "lightbulb.fill")
            } description: {
                Text("Suggest features and vote for the ideas you want most. You need a Gloop account so every person gets one vote.")
            } actions: {
                Button("Sign in") { showSignIn = true }.buttonStyle(.borderedProminent)
            }
        } else if !tokenLoaded {
            ProgressView()
        } else {
            ZStack {
                FeedbackWebView(url: FeedbackBoardLink.url(base: base, language: LanguageSettings.shared.current.code),
                                base: base, initialToken: token, phase: $phase,
                                tokenProvider: { await auth.currentAccessToken() })
                    .id(reloadID)
                    .opacity(phase == .loaded ? 1 : 0)
                switch phase {
                case .loading: ProgressView()
                case .failed:
                    ContentUnavailableView {
                        Label("Can't load the board", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your connection and try again.")
                    } actions: {
                        Button("Try again") { phase = .loading; reloadID += 1 }.buttonStyle(.borderedProminent)
                    }
                case .loaded: EmptyView()
                }
            }
        }
    }

    private func loadToken() async {
        tokenLoaded = false
        token = await auth.currentAccessToken()
        tokenLoaded = true
    }
}

/// WKWebView with the access token injected at document start and a `gloop` message handler that
/// hands out fresh tokens. Links to other sites open in Safari.
struct FeedbackWebView: UIViewRepresentable {
    enum Phase: Equatable { case loading, loaded, failed }

    let url: URL
    let base: URL
    let initialToken: String?
    @Binding var phase: Phase
    let tokenProvider: @MainActor () async -> String?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()  // the page keeps nothing between visits
        let content = configuration.userContentController
        content.addUserScript(WKUserScript(source: FeedbackBoardLink.sessionScript(accessToken: initialToken),
                                           injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.add(WeakMessageHandler(context.coordinator), name: FeedbackBoardLink.messageHandler)
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .systemBackground
        view.allowsBackForwardNavigationGestures = false
        #if DEBUG
        view.isInspectable = true  // Safari › Develop › Simulator
        #endif
        context.coordinator.webView = view
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: FeedbackBoardLink.messageHandler)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: FeedbackWebView
        weak var webView: WKWebView?

        init(parent: FeedbackWebView) { self.parent = parent }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard (message.body as? [String: Any])?["type"] as? String == "needsSession" else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let token = await parent.tokenProvider()
                _ = try? await webView?.evaluateJavaScript(FeedbackBoardLink.receiveScript(accessToken: token))
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            if FeedbackBoardLink.staysInside(url, base: parent.base) { return .allow }
            if action.navigationType == .linkActivated || url.scheme == "mailto" { await UIApplication.shared.open(url) }
            return .cancel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.phase = .loaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            parent.phase = .failed
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            parent.phase = .failed
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }
    }
}

/// `WKUserContentController` retains its handlers; this breaks the cycle with the coordinator.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?
    init(_ target: any WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
