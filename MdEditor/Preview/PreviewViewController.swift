import AppKit
import WebKit

/// View controller hosting the WKWebView WYSIWYG editor.
/// The web view renders markdown as styled HTML with contentEditable=true,
/// intercepts DOM input events, serializes back to markdown, and posts
/// updates to Swift via the "contentChanged" script message handler.
@MainActor
class PreviewViewController: NSViewController, WKNavigationDelegate, WKScriptMessageHandler {

    // MARK: - Properties

    private(set) var webView: WKWebView!

    /// Called whenever the user edits content in the WKWebView.
    /// Receives the serialized markdown string.
    var onContentChange: ((String) -> Void)?

    /// Fraction of the document to scroll to after content loads.
    var scrollFractionOnLoad: Double = 0

    /// Whether we're currently loading the initial HTML content.
    private var isLoadingInitialContent = false

    // MARK: - Lifecycle

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.isElementFullscreenEnabled = false
        // Register the message handler that receives markdown from JS
        configuration.userContentController.add(
            ScriptMessageProxy(handler: self),
            name: "contentChanged"
        )

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")

        view = webView
    }

    deinit {
        // Must remove message handler to break retain cycle
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "contentChanged")
    }

    // MARK: - Content Loading

    /// Renders markdown content and loads it into the web view.
    func renderMarkdown(_ markdown: String, baseURL: URL?) {
        let html = MarkdownRenderer.renderHTML(from: markdown)
        loadHTML(html, baseURL: baseURL?.deletingLastPathComponent())
    }

    /// Loads pre-rendered HTML into the web view.
    func loadHTML(_ html: String, baseURL: URL?) {
        isLoadingInitialContent = true
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        guard message.name == "contentChanged",
              let markdown = message.body as? String else { return }
        MainActor.assumeIsolated {
            onContentChange?(markdown)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isLoadingInitialContent {
            isLoadingInitialContent = false
            if scrollFractionOnLoad > 0 {
                let js = "window.scrollTo(0, document.body.scrollHeight * \(scrollFractionOnLoad));"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
            return
        }
        if let url = navigationAction.request.url,
           url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - ScriptMessageProxy

/// Weak-reference proxy to avoid WKUserContentController retaining PreviewViewController.
private class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var handler: (any WKScriptMessageHandler)?

    init(handler: any WKScriptMessageHandler) {
        self.handler = handler
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        handler?.userContentController(userContentController, didReceive: message)
    }
}
