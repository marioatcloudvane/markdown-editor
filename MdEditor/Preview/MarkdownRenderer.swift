import Foundation

/// Pure function renderer that converts markdown strings to complete HTML documents.
/// Uses a regex-based CommonMark/GFM renderer (no external dependency required
/// for the initial implementation; can be swapped for cmark-gfm later).
/// The HTML includes bundled CSS for preview styling.
enum MarkdownRenderer {

    /// Renders a markdown string to a complete HTML document string.
    /// - Parameter markdown: The raw markdown content.
    /// - Returns: A complete HTML5 document with inlined CSS and JavaScript.
    static func renderHTML(from markdown: String) -> String {
        let bodyHTML = markdownToHTML(markdown)
        return wrapInDocument(body: bodyHTML)
    }

    /// Renders markdown to just the HTML body (for export, where we control the wrapper).
    static func renderHTMLBody(from markdown: String) -> String {
        return markdownToHTML(markdown)
    }

    // MARK: - Markdown to HTML Conversion

    /// Converts markdown to HTML body content.
    /// This is a line-by-line regex-based converter supporting CommonMark + GFM extensions.
    private static func markdownToHTML(_ markdown: String) -> String {
        var html = ""
        let lines = markdown.components(separatedBy: "\n")
        var i = 0
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeLanguage = ""
        var inList = false
        var listType = ""
        var inBlockquote = false
        var blockquoteContent: [String] = []
        var inTable = false
        var tableRows: [[String]] = []
        var tableAlignments: [String] = []

        while i < lines.count {
            let line = lines[i]

            // Fenced code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // Close code block
                    let escapedContent = escapeHTML(codeBlockContent)
                    if codeLanguage.isEmpty {
                        html += "<pre><code>\(escapedContent)</code></pre>\n"
                    } else {
                        html += "<pre><code class=\"language-\(escapeHTML(codeLanguage))\">\(escapedContent)</code></pre>\n"
                    }
                    inCodeBlock = false
                    codeBlockContent = ""
                    codeLanguage = ""
                } else {
                    // Open code block
                    inCodeBlock = true
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                i += 1
                continue
            }

            // Close any open blockquote if the line doesn't start with >
            if inBlockquote && !line.hasPrefix(">") {
                html += "<blockquote>\(processInlines(blockquoteContent.joined(separator: "\n")))</blockquote>\n"
                inBlockquote = false
                blockquoteContent = []
            }

            // Close any open table
            if inTable && !line.contains("|") {
                html += renderTable(rows: tableRows, alignments: tableAlignments)
                inTable = false
                tableRows = []
                tableAlignments = []
            }

            // Close any open list
            if inList && !isListItem(line) && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                html += "</\(listType)>\n"
                inList = false
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if inList {
                    html += "</\(listType)>\n"
                    inList = false
                }
                i += 1
                continue
            }

            // Headings
            if let headingMatch = line.range(of: #"^(#{1,6})\s+(.+)"#, options: .regularExpression) {
                let content = String(line[headingMatch])
                let hashCount = content.prefix(while: { $0 == "#" }).count
                let text = String(content.dropFirst(hashCount).trimmingCharacters(in: .whitespaces))
                html += "<h\(hashCount)>\(processInlines(text))</h\(hashCount)>\n"
                i += 1
                continue
            }

            // Horizontal rule
            if line.range(of: #"^(---|\*\*\*|___)\s*$"#, options: .regularExpression) != nil {
                html += "<hr>\n"
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                inBlockquote = true
                let content = String(line.dropFirst().trimmingCharacters(in: .init(charactersIn: " ")))
                blockquoteContent.append(content)
                i += 1
                continue
            }

            // Table
            if line.contains("|") {
                let cells = parseTableRow(line)
                if !cells.isEmpty {
                    if !inTable {
                        inTable = true
                        tableRows = [cells]
                    } else if tableRows.count == 1 && line.range(of: #"^\|?\s*[-:]+[-|\s:]*$"#, options: .regularExpression) != nil {
                        // Separator row - parse alignments
                        tableAlignments = parseTableAlignments(line)
                    } else {
                        tableRows.append(cells)
                    }
                }
                i += 1
                continue
            }

            // Task list
            if let taskMatch = line.range(of: #"^(\s*)- \[([ x])\]\s+(.+)"#, options: .regularExpression) {
                if !inList || listType != "ul" {
                    if inList { html += "</\(listType)>\n" }
                    html += "<ul class=\"task-list\">\n"
                    inList = true
                    listType = "ul"
                }
                let taskText = String(line[taskMatch])
                let isChecked = taskText.contains("[x]")
                let content: String
                if let contentRange = taskText.range(of: #"\]\s+(.+)$"#, options: .regularExpression) {
                    content = String(taskText[contentRange]).replacingOccurrences(of: #"^\]\s+"#, with: "", options: .regularExpression)
                } else {
                    content = ""
                }
                let checked = isChecked ? " checked disabled" : " disabled"
                html += "<li class=\"task-list-item\"><input type=\"checkbox\"\(checked)> \(processInlines(content))</li>\n"
                i += 1
                continue
            }

            // Unordered list
            if let _ = line.range(of: #"^\s*[-*]\s+(.+)"#, options: .regularExpression) {
                if !inList || listType != "ul" {
                    if inList { html += "</\(listType)>\n" }
                    html += "<ul>\n"
                    inList = true
                    listType = "ul"
                }
                let content = line.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
                html += "<li>\(processInlines(content))</li>\n"
                i += 1
                continue
            }

            // Ordered list
            if let _ = line.range(of: #"^\s*\d+\.\s+(.+)"#, options: .regularExpression) {
                if !inList || listType != "ol" {
                    if inList { html += "</\(listType)>\n" }
                    html += "<ol>\n"
                    inList = true
                    listType = "ol"
                }
                let content = line.replacingOccurrences(of: #"^\s*\d+\.\s+"#, with: "", options: .regularExpression)
                html += "<li>\(processInlines(content))</li>\n"
                i += 1
                continue
            }

            // Paragraph
            html += "<p>\(processInlines(line))</p>\n"
            i += 1
        }

        // Close any remaining open elements
        if inCodeBlock {
            html += "<pre><code>\(escapeHTML(codeBlockContent))</code></pre>\n"
        }
        if inBlockquote {
            html += "<blockquote>\(processInlines(blockquoteContent.joined(separator: "\n")))</blockquote>\n"
        }
        if inTable {
            html += renderTable(rows: tableRows, alignments: tableAlignments)
        }
        if inList {
            html += "</\(listType)>\n"
        }

        return html
    }

    // MARK: - Inline Processing

    /// Processes inline markdown elements (bold, italic, code, links, images, etc.)
    private static func processInlines(_ text: String) -> String {
        var result = escapeHTML(text)

        // Images: ![alt](url)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )

        // Links: [text](url)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        // Bold + Italic: ***text***
        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#,
            with: "<strong><em>$1</em></strong>",
            options: .regularExpression
        )

        // Bold: **text**
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic: *text*
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#,
            with: "<del>$1</del>",
            options: .regularExpression
        )

        // Inline code: `code`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Autolinks: bare URLs
        result = result.replacingOccurrences(
            of: #"(?<![\"(])(https?://[^\s<>]+)"#,
            with: "<a href=\"$1\">$1</a>",
            options: .regularExpression
        )

        return result
    }

    // MARK: - Table Rendering

    private static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
        let end = stripped.hasSuffix("|") ? String(stripped.dropLast()) : stripped
        return end.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseTableAlignments(_ line: String) -> [String] {
        let cells = parseTableRow(line)
        return cells.map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") { return "center" }
            if trimmed.hasSuffix(":") { return "right" }
            return "left"
        }
    }

    private static func renderTable(rows: [[String]], alignments: [String]) -> String {
        guard !rows.isEmpty else { return "" }

        var html = "<table>\n<thead>\n<tr>\n"
        // Header row
        for (i, cell) in rows[0].enumerated() {
            let align = i < alignments.count ? " style=\"text-align: \(alignments[i])\"" : ""
            html += "<th\(align)>\(processInlines(cell))</th>\n"
        }
        html += "</tr>\n</thead>\n"

        // Body rows
        if rows.count > 1 {
            html += "<tbody>\n"
            for row in rows.dropFirst() {
                html += "<tr>\n"
                for (i, cell) in row.enumerated() {
                    let align = i < alignments.count ? " style=\"text-align: \(alignments[i])\"" : ""
                    html += "<td\(align)>\(processInlines(cell))</td>\n"
                }
                html += "</tr>\n"
            }
            html += "</tbody>\n"
        }

        html += "</table>\n"
        return html
    }

    private static func isListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.range(of: #"^[-*]\s+"#, options: .regularExpression) != nil ||
               trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil ||
               trimmed.range(of: #"^- \[[ x]\]\s+"#, options: .regularExpression) != nil
    }

    // MARK: - HTML Escaping

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Document Wrapper

    /// Wraps HTML body content in a complete HTML5 document with CSS and JS.
    static func wrapInDocument(body: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Preview</title>
        <style>
        \(previewCSS)
        </style>
        <style>
        \(highlightCSS)
        </style>
        </head>
        <body>
        <article>
        \(body)
        </article>
        <script>
        \(highlightJS)
        </script>
        <script>
        \(editableJS)
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Bundled CSS

    static let previewCSS = """
    :root {
        --text-color: #1d1d1f;
        --bg-color: #ffffff;
        --secondary-text: #6e6e73;
        --border-color: #d2d2d7;
        --code-bg: #f5f5f7;
        --blockquote-border: #d2d2d7;
        --table-stripe: #f5f5f7;
        --link-color: #0066cc;
    }

    @media (prefers-color-scheme: dark) {
        :root {
            --text-color: #f5f5f7;
            --bg-color: #1d1d1f;
            --secondary-text: #98989d;
            --border-color: #424245;
            --code-bg: #2c2c2e;
            --blockquote-border: #424245;
            --table-stripe: #2c2c2e;
            --link-color: #2997ff;
        }
    }

    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        font-size: 15px;
        line-height: 1.7;
        color: var(--text-color);
        background-color: var(--bg-color);
        -webkit-font-smoothing: antialiased;
    }

    article {
        max-width: 680px;
        margin: 0 auto;
        padding: 24px 24px 100px 24px;
    }

    h1, h2, h3, h4, h5, h6 {
        margin-top: 1.5em;
        margin-bottom: 0.5em;
        font-weight: 600;
        line-height: 1.25;
    }

    h1 { font-size: 2em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: var(--secondary-text); }

    p {
        margin-bottom: 1em;
    }

    a {
        color: var(--link-color);
        text-decoration: none;
    }

    a:hover {
        text-decoration: underline;
    }

    strong {
        font-weight: 600;
    }

    code {
        font-family: 'SF Mono', SFMono-Regular, Menlo, Consolas, monospace;
        font-size: 0.875em;
        background-color: var(--code-bg);
        padding: 0.2em 0.4em;
        border-radius: 3px;
    }

    pre {
        background-color: var(--code-bg);
        padding: 16px;
        border-radius: 6px;
        overflow-x: auto;
        margin-bottom: 1em;
    }

    pre code {
        background: none;
        padding: 0;
        font-size: 13px;
        line-height: 1.5;
    }

    blockquote {
        border-left: 4px solid var(--blockquote-border);
        padding: 0.5em 1em;
        margin: 0 0 1em 0;
        color: var(--secondary-text);
    }

    blockquote p {
        margin-bottom: 0.5em;
    }

    ul, ol {
        margin-bottom: 1em;
        padding-left: 2em;
    }

    li {
        margin-bottom: 0.25em;
    }

    .task-list {
        list-style: none;
        padding-left: 0;
    }

    .task-list-item {
        padding-left: 1.5em;
        position: relative;
    }

    .task-list-item input[type="checkbox"] {
        position: absolute;
        left: 0;
        top: 0.3em;
    }

    table {
        border-collapse: collapse;
        width: 100%;
        margin-bottom: 1em;
        overflow-x: auto;
        display: block;
    }

    th, td {
        border: 1px solid var(--border-color);
        padding: 8px 12px;
        text-align: left;
    }

    th {
        font-weight: 600;
        background-color: var(--code-bg);
    }

    tbody tr:nth-child(even) {
        background-color: var(--table-stripe);
    }

    hr {
        border: none;
        border-top: 1px solid var(--border-color);
        margin: 2em 0;
    }

    img {
        max-width: 100%;
        height: auto;
        border-radius: 4px;
    }

    del {
        color: var(--secondary-text);
    }
    """

    static let highlightCSS = """
    /* Minimal 4-color syntax highlighting */
    .hljs-keyword, .hljs-selector-tag, .hljs-built_in, .hljs-name, .hljs-tag {
        color: #ad3da4;
    }
    .hljs-string, .hljs-title, .hljs-section, .hljs-attribute, .hljs-literal, .hljs-template-tag, .hljs-template-variable, .hljs-type, .hljs-addition {
        color: #272ad8;
    }
    .hljs-comment, .hljs-deletion, .hljs-meta {
        color: #8e8e93;
    }

    @media (prefers-color-scheme: dark) {
        .hljs-keyword, .hljs-selector-tag, .hljs-built_in, .hljs-name, .hljs-tag {
            color: #fc5fa3;
        }
        .hljs-string, .hljs-title, .hljs-section, .hljs-attribute, .hljs-literal, .hljs-template-tag, .hljs-template-variable, .hljs-type, .hljs-addition {
            color: #fc6a5d;
        }
        .hljs-comment, .hljs-deletion, .hljs-meta {
            color: #7f8c8d;
        }
    }
    """

    // Makes the WKWebView a WYSIWYG editor. On every change, serializes DOM back to
    // markdown and posts it to Swift via the "contentChanged" message handler.
    static let editableJS = #"""
    document.addEventListener('DOMContentLoaded', function() {
        document.body.contentEditable = 'true';
        document.body.spellcheck = true;

        // Prevent <p> gap on Enter — use a plain line break instead
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                document.execCommand('insertLineBreak');
            }
        });

        // Sync DOM → markdown on every edit
        document.addEventListener('input', function() {
            var md = serializeToMarkdown();
            window.webkit.messageHandlers.contentChanged.postMessage(md);
        });
    });

    function serializeToMarkdown() {
        var article = document.querySelector('article') || document.body;
        return nodeToMarkdown(article).replace(/\n{3,}/g, '\n\n').trim() + '\n';
    }

    function nodeToMarkdown(node) {
        var result = '';
        for (var i = 0; i < node.childNodes.length; i++) {
            result += childToMarkdown(node.childNodes[i]);
        }
        return result;
    }

    function childToMarkdown(node) {
        if (node.nodeType === 3) return node.textContent;
        if (node.nodeType !== 1) return '';
        var tag = node.tagName;
        var inner = nodeToMarkdown(node);
        if (tag === 'H1') return '\n# ' + inner.trim() + '\n\n';
        if (tag === 'H2') return '\n## ' + inner.trim() + '\n\n';
        if (tag === 'H3') return '\n### ' + inner.trim() + '\n\n';
        if (tag === 'H4') return '\n#### ' + inner.trim() + '\n\n';
        if (tag === 'H5') return '\n##### ' + inner.trim() + '\n\n';
        if (tag === 'H6') return '\n###### ' + inner.trim() + '\n\n';
        if (tag === 'P') return inner.trim() + '\n\n';
        if (tag === 'BR') return '\n';
        if (tag === 'STRONG' || tag === 'B') return '**' + inner + '**';
        if (tag === 'EM' || tag === 'I') return '*' + inner + '*';
        if (tag === 'DEL' || tag === 'S') return '~~' + inner + '~~';
        if (tag === 'CODE' && node.parentElement && node.parentElement.tagName !== 'PRE') return '`' + inner + '`';
        if (tag === 'PRE') return '\n```\n' + node.textContent.trim() + '\n```\n\n';
        if (tag === 'BLOCKQUOTE') {
            return inner.trim().split('\n').map(function(l) { return '> ' + l; }).join('\n') + '\n\n';
        }
        if (tag === 'UL') {
            var s = '';
            for (var i = 0; i < node.children.length; i++) { s += '- ' + nodeToMarkdown(node.children[i]).trim() + '\n'; }
            return s + '\n';
        }
        if (tag === 'OL') {
            var s = ''; var n = 1;
            for (var i = 0; i < node.children.length; i++) { s += (n++) + '. ' + nodeToMarkdown(node.children[i]).trim() + '\n'; }
            return s + '\n';
        }
        if (tag === 'LI') return inner;
        if (tag === 'A') return '[' + inner + '](' + (node.getAttribute('href') || '') + ')';
        if (tag === 'IMG') return '![' + (node.getAttribute('alt') || '') + '](' + (node.getAttribute('src') || '') + ')';
        if (tag === 'HR') return '\n---\n\n';
        return inner;
    }
    """#

    static let highlightJS = #"""
    // Minimal syntax highlighting - just applies basic classes
    document.querySelectorAll('pre code').forEach(function(block) {
        // Basic keyword highlighting for common languages
        var text = block.innerHTML;

        // Keywords
        var keywords = /\b(function|var|let|const|if|else|for|while|return|class|import|export|from|default|new|this|true|false|null|undefined|async|await|try|catch|throw|switch|case|break|continue|do|in|of|typeof|instanceof|void|delete|yield|static|get|set|super|extends|implements|interface|enum|public|private|protected|abstract|final|override|struct|func|guard|defer|where|protocol|extension|self|Self|some|any|mutating|nonmutating|init|deinit|subscript|associatedtype|typealias)\b/g;
        text = text.replace(keywords, '<span class="hljs-keyword">$1</span>');

        // Strings (double and single quotes)
        text = text.replace(/(&quot;[^&]*?&quot;|'[^']*?')/g, '<span class="hljs-string">$1</span>');

        // Comments (// and /* */)
        text = text.replace(/(\/\/[^\n]*)/g, '<span class="hljs-comment">$1</span>');
        text = text.replace(/(\/\*[\s\S]*?\*\/)/g, '<span class="hljs-comment">$1</span>');

        // Comments (# for Python, Ruby, etc.)
        text = text.replace(/^(#[^\n]*)/gm, '<span class="hljs-comment">$1</span>');

        block.innerHTML = text;
    });
    """#
}
