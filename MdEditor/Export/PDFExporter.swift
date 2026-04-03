import AppKit
import WebKit
import UniformTypeIdentifiers

/// Exports the current document as a PDF file.
/// Uses an offscreen WKWebView to render the HTML and then generates
/// the PDF using WKWebView's createPDF API.
@MainActor
class PDFExporter: NSObject, WKNavigationDelegate {

    /// Retained reference to the offscreen web view during export.
    private var webView: WKWebView?
    /// The window to present the save panel in.
    private weak var window: NSWindow?
    /// The document name for the save panel.
    private var documentName: String = ""
    /// Continuation for the async flow.
    private var pdfContinuation: CheckedContinuation<Data, Error>?

    /// Exports markdown content as a PDF file.
    /// - Parameters:
    ///   - markdownContent: The raw markdown string to render.
    ///   - documentName: The document name used for the default filename.
    ///   - window: The window to present the save panel in.
    static func exportPDF(from markdownContent: String,
                          documentName: String,
                          in window: NSWindow) {
        let exporter = PDFExporter()
        exporter.window = window
        exporter.documentName = documentName
        exporter.performExport(markdownContent: markdownContent)
    }

    private func performExport(markdownContent: String) {
        // Build HTML
        let bodyHTML = MarkdownRenderer.renderHTMLBody(from: markdownContent)
        let fullHTML = HTMLExporter.buildStandaloneHTML(title: documentName, body: bodyHTML)

        // Create offscreen WKWebView
        let configuration = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1200), configuration: configuration)
        wv.navigationDelegate = self

        // Force light mode for PDF
        wv.appearance = NSAppearance(named: .aqua)

        self.webView = wv

        // Load HTML
        wv.loadHTMLString(fullHTML, baseURL: nil)
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            generatePDF(from: webView)
        }
    }

    private func generatePDF(from webView: WKWebView) {
        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = NSRect(x: 0, y: 0, width: 612, height: 792) // US Letter

        webView.createPDF(configuration: pdfConfig) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let pdfData):
                self.presentSavePanel(with: pdfData)
            case .failure(let error):
                DispatchQueue.main.async {
                    if let window = self.window {
                        let alert = NSAlert(error: error)
                        alert.beginSheetModal(for: window)
                    }
                }
            }
        }
    }

    private func presentSavePanel(with pdfData: Data) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = "\(self.documentName).pdf"
            savePanel.canCreateDirectories = true

            savePanel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = savePanel.url else { return }

                do {
                    try pdfData.write(to: url, options: .atomic)
                } catch {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window)
                }
            }

            // Clean up
            self.webView = nil
        }
    }
}
