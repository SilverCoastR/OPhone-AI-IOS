import SwiftUI
import WebKit

struct WebContainer: UIViewRepresentable {
    var initialURL: URL
    var persistent: Bool
    var onChange: (String?, URL?) -> Void = { _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = persistent ? .default() : .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let viewport = """
        (function(){
          var meta=document.querySelector('meta[name=viewport]');
          if(!meta){meta=document.createElement('meta');meta.name='viewport';document.head.appendChild(meta);}
          meta.content='width=device-width, initial-scale=1, minimum-scale=0.25, maximum-scale=5, user-scalable=yes';
        })();
        """
        configuration.userContentController.addUserScript(WKUserScript(source: viewport, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.minimumZoomScale = 0.25
        webView.scrollView.maximumZoomScale = 5
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        webView.load(URLRequest(url: initialURL)); context.coordinator.loadedURL = initialURL
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onChange = onChange
        if context.coordinator.loadedURL != initialURL { context.coordinator.loadedURL = initialURL; webView.load(URLRequest(url: initialURL)) }
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onChange: (String?, URL?) -> Void
        var loadedURL: URL?
        init(onChange: @escaping (String?, URL?) -> Void) { self.onChange = onChange }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loadedURL = webView.url; onChange(webView.title, webView.url) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onChange(error.localizedDescription, webView.url) }
    }
}
