import SwiftUI
import WebKit
import OSLog

@MainActor
class NavigationState: NSObject, ObservableObject {
    @Published var url: URL?
    let webView: WKWebView
    private let logger = AppLoggerFactory.makeLogger(category: "WebLoginView")
    
    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.pageZoom = 0.7
        super.init()
        webView.navigationDelegate = self
    }
}

extension NavigationState: WKNavigationDelegate {
    /// Observes navigation commits so onboarding can detect login redirects and adjust headers.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.url = webView.url

        logger.debug("Navigation committed to URL \(String(describing: self.url), privacy: .public)")

        if ((self.url?.absoluteString.starts(with: "https://open.spotify.com")) ?? false) {
            ViewModel.shared.checkIfLoggedIn()
        }

        if (self.url?.absoluteString.starts(with: "https://accounts.google.com/") ?? false) {
            logger.notice("Detected Google login redirect: \(self.url?.absoluteString ?? "none", privacy: .public)")
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
        }
    }
}

struct WebView: NSViewRepresentable {
    let request: URLRequest
    @ObservedObject var navigationState: NavigationState
    
    /// Configures the shared WKWebView instance with the initial onboarding request.
    func makeNSView(context: Context) -> WKWebView {
        navigationState.webView.load(request)
        return navigationState.webView
    }

    /// Updates the WKWebView; no-op because navigation is driven by the shared state object.
    func updateNSView(_ nsView: WKWebView, context: Context) {
    }
}
