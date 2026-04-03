import AppKit
import UniformTypeIdentifiers

/// Exports the current document as a standalone HTML file with inlined CSS.
/// The exported file is fully self-contained with no external dependencies.
@MainActor
enum HTMLExporter {

    /// Exports markdown content as a standalone HTML file.
    /// - Parameters:
    ///   - markdownContent: The raw markdown string to render.
    ///   - documentName: The document name used for the default filename.
    ///   - window: The window to present the save panel in.
    static func exportHTML(from markdownContent: String,
                           documentName: String,
                           in window: NSWindow) {
        // Render the HTML
        let bodyHTML = MarkdownRenderer.renderHTMLBody(from: markdownContent)
        let fullHTML = buildStandaloneHTML(title: documentName, body: bodyHTML)

        // Present save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.html]
        savePanel.nameFieldStringValue = "\(documentName).html"
        savePanel.canCreateDirectories = true

        savePanel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try fullHTML.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: window)
            }
        }
    }

    /// Builds a complete, standalone HTML document with inlined CSS.
    static func buildStandaloneHTML(title: String, body: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(title))</title>
        <style>
        \(MarkdownRenderer.previewCSS)
        </style>
        <style>
        \(MarkdownRenderer.highlightCSS)
        </style>
        </head>
        <body>
        <article>
        \(body)
        </article>
        <script>
        \(MarkdownRenderer.highlightJS)
        </script>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
