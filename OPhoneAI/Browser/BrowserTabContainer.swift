import SwiftUI
import WebKit

struct BrowserTabContainer: UIViewRepresentable {
    let tab: BrowserTab
    let browser: BrowserStore
    func makeCoordinator() -> Coordinator { Coordinator(tabID: tab.id, browser: browser) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent(); configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(WKUserScript(source: viewportScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let webView = WKWebView(frame: .zero, configuration: configuration); webView.navigationDelegate = context.coordinator; webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.minimumZoomScale = 0.25; webView.scrollView.maximumZoomScale = 5
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        browser.attach(webView, to: tab.id); webView.load(URLRequest(url: tab.url)); context.coordinator.loadedURL = tab.url; return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) { if context.coordinator.loadedURL != tab.url { context.coordinator.loadedURL = tab.url; webView.load(URLRequest(url: tab.url)) } }
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) { coordinator.browser.detach(coordinator.tabID) }
    final class Coordinator: NSObject, WKNavigationDelegate {
        let tabID: UUID, browser: BrowserStore; var loadedURL: URL?
        init(tabID: UUID, browser: BrowserStore) { self.tabID = tabID; self.browser = browser }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loadedURL = webView.url; browser.update(tabID, title: webView.title, url: webView.url) }
    }
}

private let viewportScript = """
(function(){var m=document.querySelector('meta[name=viewport]');if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}m.content='width=device-width, initial-scale=1, minimum-scale=0.25, maximum-scale=5, user-scalable=yes';})();
"""
