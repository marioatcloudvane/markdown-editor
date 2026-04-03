import AppKit

/// Stateless formatting command implementations that operate on an NSTextView.
/// Called by toolbar buttons, menu items, and keyboard shortcuts through
/// the responder chain. Each method is a single undoable operation.
enum FormattingCommands {

    // MARK: - Wrap-Style Formatting (Bold, Italic, Code, Strikethrough)

    /// Toggles wrap-style formatting around the selection.
    /// If text is selected and already wrapped, removes the markers.
    /// If text is selected and not wrapped, adds markers.
    /// If no selection, inserts markers with placeholder text selected.
    static func toggleWrap(in textView: NSTextView, marker: String, placeholder: String) {
        let range = textView.selectedRange()
        let text = textView.string as NSString
        let markerLen = marker.count

        textView.undoManager?.beginUndoGrouping()

        if range.length > 0 {
            // Check if already wrapped
            let start = range.location
            let end = range.location + range.length

            if start >= markerLen && end + markerLen <= text.length {
                let before = text.substring(with: NSRange(location: start - markerLen, length: markerLen))
                let after = text.substring(with: NSRange(location: end, length: markerLen))

                if before == marker && after == marker {
                    // Toggle off: remove markers
                    let fullRange = NSRange(location: start - markerLen, length: range.length + markerLen * 2)
                    let content = text.substring(with: range)
                    textView.insertText(content, replacementRange: fullRange)
                    textView.setSelectedRange(NSRange(location: start - markerLen, length: range.length))
                    textView.undoManager?.endUndoGrouping()
                    return
                }
            }

            // Toggle on: wrap selection
            let selectedText = text.substring(with: range)
            let wrapped = "\(marker)\(selectedText)\(marker)"
            textView.insertText(wrapped, replacementRange: range)
            textView.setSelectedRange(NSRange(location: range.location, length: wrapped.count))

        } else {
            // No selection: insert with placeholder
            let insertion = "\(marker)\(placeholder)\(marker)"
            textView.insertText(insertion, replacementRange: range)
            // Select the placeholder text
            textView.setSelectedRange(NSRange(location: range.location + markerLen, length: placeholder.count))
        }

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Line-Prefix Formatting (Lists, Blockquotes)

    /// Toggles a line prefix on the current line or selected lines.
    static func toggleLinePrefix(in textView: NSTextView, prefix: String) {
        let text = textView.string as NSString
        let range = textView.selectedRange()
        let lineRange = text.lineRange(for: range)

        textView.undoManager?.beginUndoGrouping()

        var newLines: [String] = []
        var allHavePrefix = true

        text.enumerateSubstrings(in: lineRange, options: [.byLines]) { substring, _, _, _ in
            guard let line = substring else { return }
            if !line.hasPrefix(prefix) {
                allHavePrefix = false
            }
        }

        text.enumerateSubstrings(in: lineRange, options: [.byLines]) { substring, _, _, _ in
            guard let line = substring else { return }
            if allHavePrefix {
                // Remove prefix
                if line.hasPrefix(prefix) {
                    newLines.append(String(line.dropFirst(prefix.count)))
                } else {
                    newLines.append(line)
                }
            } else {
                // Remove existing list prefix first, then add new one
                let cleaned = removeExistingLinePrefix(from: line)
                newLines.append(prefix + cleaned)
            }
        }

        let replacement = newLines.joined(separator: "\n")
        // Account for trailing newline in the lineRange
        let adjustedRange: NSRange
        if lineRange.length > 0 &&
           NSMaxRange(lineRange) <= text.length &&
           text.character(at: NSMaxRange(lineRange) - 1) == 0x0A {
            adjustedRange = NSRange(location: lineRange.location, length: lineRange.length - 1)
        } else {
            adjustedRange = lineRange
        }

        textView.insertText(replacement, replacementRange: adjustedRange)

        textView.undoManager?.endUndoGrouping()
    }

    /// Toggles numbered list formatting on selected lines.
    static func toggleNumberedList(in textView: NSTextView) {
        let text = textView.string as NSString
        let range = textView.selectedRange()
        let lineRange = text.lineRange(for: range)

        textView.undoManager?.beginUndoGrouping()

        var lines: [String] = []
        text.enumerateSubstrings(in: lineRange, options: [.byLines]) { substring, _, _, _ in
            guard let line = substring else { return }
            lines.append(line)
        }

        // Check if all lines already have numbered list prefix
        let allNumbered = lines.allSatisfy { line in
            line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
        }

        var newLines: [String] = []
        for (index, line) in lines.enumerated() {
            if allNumbered {
                // Remove numbering
                if let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    newLines.append(String(line[range.upperBound...]))
                } else {
                    newLines.append(line)
                }
            } else {
                let cleaned = removeExistingLinePrefix(from: line)
                newLines.append("\(index + 1). \(cleaned)")
            }
        }

        let replacement = newLines.joined(separator: "\n")
        let adjustedRange: NSRange
        if lineRange.length > 0 &&
           NSMaxRange(lineRange) <= text.length &&
           text.character(at: NSMaxRange(lineRange) - 1) == 0x0A {
            adjustedRange = NSRange(location: lineRange.location, length: lineRange.length - 1)
        } else {
            adjustedRange = lineRange
        }

        textView.insertText(replacement, replacementRange: adjustedRange)

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Heading

    /// Cycles through heading levels H1 -> H2 -> H3 -> remove on repeated presses.
    static func cycleHeading(in textView: NSTextView) {
        let text = textView.string as NSString
        let range = textView.selectedRange()
        let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
        let lineText = text.substring(with: lineRange)

        let currentLevel: Int
        if let match = lineText.range(of: #"^(#{1,6})\s"#, options: .regularExpression) {
            let hashes = lineText[match].filter { $0 == "#" }
            currentLevel = hashes.count
        } else {
            currentLevel = 0
        }

        let nextLevel: Int
        switch currentLevel {
        case 0: nextLevel = 1
        case 1: nextLevel = 2
        case 2: nextLevel = 3
        default: nextLevel = 0  // Remove heading
        }

        setHeading(in: textView, level: nextLevel)
    }

    /// Sets a specific heading level on the current line.
    static func setHeading(in textView: NSTextView, level: Int) {
        let text = textView.string as NSString
        let range = textView.selectedRange()
        let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
        let lineText = text.substring(with: lineRange).trimmingCharacters(in: .newlines)

        textView.undoManager?.beginUndoGrouping()

        // Remove existing heading prefix
        let cleanedLine: String
        if let match = lineText.range(of: #"^#{1,6}\s*"#, options: .regularExpression) {
            cleanedLine = String(lineText[match.upperBound...])
        } else {
            cleanedLine = lineText
        }

        // Add new heading prefix
        let newLine: String
        if level > 0 && level <= 6 {
            let prefix = String(repeating: "#", count: level) + " "
            newLine = prefix + cleanedLine
        } else {
            newLine = cleanedLine
        }

        // Replace the line (accounting for trailing newline)
        let replaceRange: NSRange
        if NSMaxRange(lineRange) <= text.length && lineRange.length > 0 &&
           NSMaxRange(lineRange) > lineRange.location &&
           text.character(at: NSMaxRange(lineRange) - 1) == 0x0A {
            replaceRange = NSRange(location: lineRange.location, length: lineRange.length - 1)
        } else {
            replaceRange = lineRange
        }

        textView.insertText(newLine, replacementRange: replaceRange)

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Link

    /// Inserts a markdown link. If text is selected, uses it as the link text.
    /// Auto-populates URL from clipboard if available.
    static func insertLink(in textView: NSTextView) {
        let range = textView.selectedRange()
        let text = textView.string as NSString
        let selectedText = range.length > 0 ? text.substring(with: range) : ""

        // Check clipboard for URL
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let defaultURL = clipboard.hasPrefix("http://") || clipboard.hasPrefix("https://") ? clipboard : "url"

        textView.undoManager?.beginUndoGrouping()

        if range.length > 0 {
            let linkMarkdown = "[\(selectedText)](\(defaultURL))"
            textView.insertText(linkMarkdown, replacementRange: range)
            // Select the URL part for easy replacement
            let urlStart = range.location + selectedText.count + 3
            textView.setSelectedRange(NSRange(location: urlStart, length: defaultURL.count))
        } else {
            let linkMarkdown = "[link text](\(defaultURL))"
            textView.insertText(linkMarkdown, replacementRange: range)
            // Select "link text" for easy replacement
            textView.setSelectedRange(NSRange(location: range.location + 1, length: 9))
        }

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Code Block

    /// Inserts a fenced code block. Wraps selection if present.
    static func insertCodeBlock(in textView: NSTextView) {
        let range = textView.selectedRange()
        let text = textView.string as NSString

        textView.undoManager?.beginUndoGrouping()

        if range.length > 0 {
            let selectedText = text.substring(with: range)
            let codeBlock = "```\n\(selectedText)\n```"
            textView.insertText(codeBlock, replacementRange: range)
        } else {
            // Ensure we're on a new line
            var prefix = ""
            if range.location > 0 && text.character(at: range.location - 1) != 0x0A {
                prefix = "\n"
            }
            let codeBlock = "\(prefix)```\n\n```"
            textView.insertText(codeBlock, replacementRange: range)
            // Position cursor inside the code block
            let cursorPos = range.location + prefix.count + 4
            textView.setSelectedRange(NSRange(location: cursorPos, length: 0))
        }

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Horizontal Rule

    /// Inserts a horizontal rule (---) on a new line.
    static func insertHorizontalRule(in textView: NSTextView) {
        let range = textView.selectedRange()
        let text = textView.string as NSString

        textView.undoManager?.beginUndoGrouping()

        var prefix = ""
        if range.location > 0 && text.character(at: range.location - 1) != 0x0A {
            prefix = "\n"
        }
        let rule = "\(prefix)---\n"
        textView.insertText(rule, replacementRange: range)

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Image

    /// Inserts an image reference. Shows a simple dialog for alt text and URL.
    static func insertImage(in textView: NSTextView) {
        let range = textView.selectedRange()

        textView.undoManager?.beginUndoGrouping()

        let imageMarkdown = "![alt text](image-url)"
        textView.insertText(imageMarkdown, replacementRange: range)
        // Select "alt text" for easy replacement
        textView.setSelectedRange(NSRange(location: range.location + 2, length: 8))

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Table

    /// Inserts a 3x3 markdown table template.
    static func insertTable(in textView: NSTextView) {
        let range = textView.selectedRange()
        let text = textView.string as NSString

        textView.undoManager?.beginUndoGrouping()

        var prefix = ""
        if range.location > 0 && text.character(at: range.location - 1) != 0x0A {
            prefix = "\n"
        }

        let table = """
        \(prefix)| Column 1 | Column 2 | Column 3 |
        |----------|----------|----------|
        |          |          |          |
        |          |          |          |
        """
        textView.insertText(table, replacementRange: range)

        // Position cursor in first data cell
        let firstCellOffset = prefix.count + "| Column 1 | Column 2 | Column 3 |\n|----------|----------|----------|\n| ".count
        textView.setSelectedRange(NSRange(location: range.location + firstCellOffset, length: 0))

        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Helpers

    /// Removes any existing list/heading prefix from a line.
    private static func removeExistingLinePrefix(from line: String) -> String {
        // Remove heading prefix
        if let match = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        // Remove bullet list prefix
        if let match = line.range(of: #"^[-*]\s+"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        // Remove numbered list prefix
        if let match = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        // Remove task list prefix
        if let match = line.range(of: #"^- \[[ x]\]\s+"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        // Remove blockquote prefix
        if let match = line.range(of: #"^>\s*"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        return line
    }
}
