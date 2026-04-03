import AppKit

/// Custom NSTextView subclass providing markdown-specific behavior:
/// current line highlighting, tab-to-spaces conversion, list continuation,
/// and drag-and-drop for images and markdown files.
@MainActor
class MarkdownTextView: NSTextView {

    // MARK: - Properties

    /// The range of the previously highlighted line, used for invalidation.
    private var previousLineRect: NSRect = .zero

    /// Reference to the document (set by EditorViewController).
    weak var markdownDocument: MarkdownDocument?

    // MARK: - Current Line Highlight

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let layoutManager = layoutManager,
              let _ = textContainer else { return }

        let cursorIndex = selectedRange().location
        guard cursorIndex <= (string as NSString).length else { return }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(cursorIndex, max(0, (string as NSString).length - 1)))
        var effectiveRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)

        // Extend the rect to the full width of the text view
        let highlightRect = NSRect(
            x: 0,
            y: lineRect.origin.y,
            width: bounds.width,
            height: lineRect.height
        )

        NSColor.textColor.withAlphaComponent(LayoutConstants.currentLineHighlightAlpha).setFill()
        highlightRect.fill()
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        let oldRange = selectedRange()
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)

        // Invalidate old and new line rects for current line highlight redraw
        if oldRange.location != charRange.location {
            needsDisplay = true
        }
    }

    // MARK: - Tab Key Override

    override func insertTab(_ sender: Any?) {
        let tabWidth = AppPreferences.shared.editorTabWidth
        let spaces = String(repeating: " ", count: tabWidth)
        insertText(spaces, replacementRange: selectedRange())
    }

    // MARK: - List Continuation

    override func insertNewline(_ sender: Any?) {
        guard AppPreferences.shared.autoContinueLists else {
            super.insertNewline(sender)
            return
        }

        let text = string as NSString
        let cursorLocation = selectedRange().location
        let currentLineRange = text.lineRange(for: NSRange(location: cursorLocation, length: 0))
        let currentLine = text.substring(with: currentLineRange)

        if let continuation = ListContinuation.continuation(for: currentLine, cursorOffset: cursorLocation - currentLineRange.location) {
            switch continuation {
            case .continueList(let prefix):
                undoManager?.beginUndoGrouping()
                super.insertNewline(sender)
                insertText(prefix, replacementRange: selectedRange())
                undoManager?.endUndoGrouping()

            case .exitList(let prefixRange):
                // Remove the list prefix from the current line
                undoManager?.beginUndoGrouping()
                let absoluteRange = NSRange(location: currentLineRange.location + prefixRange.location,
                                            length: prefixRange.length)
                insertText("", replacementRange: absoluteRange)
                undoManager?.endUndoGrouping()
            }
        } else {
            super.insertNewline(sender)
        }
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if let types = pasteboard.types, types.contains(.fileURL) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                                 options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return super.performDragOperation(sender)
        }

        for url in urls {
            let ext = url.pathExtension.lowercased()

            if ["png", "jpg", "jpeg", "gif", "svg", "webp"].contains(ext) {
                // Image file: insert markdown image reference
                let point = convert(sender.draggingLocation, from: nil)
                let charIndex = characterIndexForInsertion(at: point)
                let imagePath = computeImagePath(for: url)
                let markdown = "![\(url.deletingPathExtension().lastPathComponent)](\(imagePath))"

                undoManager?.beginUndoGrouping()
                insertText(markdown, replacementRange: NSRange(location: charIndex, length: 0))
                undoManager?.endUndoGrouping()
                return true

            } else if SupportedExtensions.openFile.contains(ext) {
                // Markdown file: open as new tab
                NSDocumentController.shared.openDocument(
                    withContentsOf: url,
                    display: true
                ) { _, _, _ in }
                return true
            }
        }

        return super.performDragOperation(sender)
    }

    private func computeImagePath(for imageURL: URL) -> String {
        guard let docURL = markdownDocument?.fileURL else {
            return imageURL.path
        }

        let docDir = docURL.deletingLastPathComponent().standardizedFileURL.path
        let imagePath = imageURL.standardizedFileURL.path

        if imagePath.hasPrefix(docDir) {
            // Compute relative path
            let relative = String(imagePath.dropFirst(docDir.count))
            if relative.hasPrefix("/") {
                return String(relative.dropFirst())
            }
            return relative
        }

        return imageURL.path
    }
}

// MARK: - Formatting Responder Implementation

extension MarkdownTextView: @preconcurrency FormattingResponder {

    @objc func toggleBold(_ sender: Any?) {
        FormattingCommands.toggleWrap(in: self, marker: "**", placeholder: "bold text")
    }

    @objc func toggleItalic(_ sender: Any?) {
        FormattingCommands.toggleWrap(in: self, marker: "*", placeholder: "italic text")
    }

    @objc func insertLink(_ sender: Any?) {
        FormattingCommands.insertLink(in: self)
    }

    @objc func toggleInlineCode(_ sender: Any?) {
        FormattingCommands.toggleWrap(in: self, marker: "`", placeholder: "code")
    }

    @objc func toggleBulletList(_ sender: Any?) {
        FormattingCommands.toggleLinePrefix(in: self, prefix: "- ")
    }

    @objc func toggleNumberedList(_ sender: Any?) {
        FormattingCommands.toggleNumberedList(in: self)
    }

    @objc func toggleTaskList(_ sender: Any?) {
        FormattingCommands.toggleLinePrefix(in: self, prefix: "- [ ] ")
    }

    @objc func cycleHeading(_ sender: Any?) {
        FormattingCommands.cycleHeading(in: self)
    }

    @objc func toggleStrikethrough(_ sender: Any?) {
        FormattingCommands.toggleWrap(in: self, marker: "~~", placeholder: "strikethrough text")
    }

    @objc func toggleBlockquote(_ sender: Any?) {
        FormattingCommands.toggleLinePrefix(in: self, prefix: "> ")
    }

    @objc func insertCodeBlock(_ sender: Any?) {
        FormattingCommands.insertCodeBlock(in: self)
    }

    @objc func insertHorizontalRule(_ sender: Any?) {
        FormattingCommands.insertHorizontalRule(in: self)
    }

    @objc func insertImage(_ sender: Any?) {
        FormattingCommands.insertImage(in: self)
    }

    @objc func insertTable(_ sender: Any?) {
        FormattingCommands.insertTable(in: self)
    }

    @objc func setHeading1(_ sender: Any?) { FormattingCommands.setHeading(in: self, level: 1) }
    @objc func setHeading2(_ sender: Any?) { FormattingCommands.setHeading(in: self, level: 2) }
    @objc func setHeading3(_ sender: Any?) { FormattingCommands.setHeading(in: self, level: 3) }
    @objc func setHeading4(_ sender: Any?) { FormattingCommands.setHeading(in: self, level: 4) }
    @objc func setHeading5(_ sender: Any?) { FormattingCommands.setHeading(in: self, level: 5) }
    @objc func setHeading6(_ sender: Any?) { FormattingCommands.setHeading(in: self, level: 6) }
}
