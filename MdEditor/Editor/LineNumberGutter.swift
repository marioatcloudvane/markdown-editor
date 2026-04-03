import AppKit

/// NSRulerView subclass that displays line numbers in the editor gutter.
/// Synchronizes with the text view's layout manager to position numbers
/// correctly as the user scrolls and edits.
@MainActor
class LineNumberGutter: NSRulerView {

    // MARK: - Properties

    private weak var textView: NSTextView?
    private let separatorWidth: CGFloat = 1

    // MARK: - Initialization

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40

        // Observe text changes and scroll
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        if let clipView = scrollView.contentView as? NSClipView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let text = textView.string as NSString
        guard text.length > 0 else { return }

        // Draw separator line
        NSColor.separatorColor.setFill()
        let separatorRect = NSRect(x: bounds.width - separatorWidth, y: rect.origin.y,
                                    width: separatorWidth, height: rect.height)
        separatorRect.fill()

        // Calculate visible range
        let visibleRect = scrollView?.contentView.bounds ?? bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Update gutter width based on line count
        let totalLines = countLines(in: text)
        let digitCount = max(2, String(totalLines).count)
        let newThickness = CGFloat(digitCount) * 10 + 16
        if abs(ruleThickness - newThickness) > 1 {
            ruleThickness = newThickness
        }

        // Text attributes for line numbers
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.quaternaryLabelColor
        ]

        // Track which line number we're on
        var lineNumber = countLines(in: text, upTo: charRange.location) + 1

        let textContainerInset = textView.textContainerInset

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, container, range, _ in
            // Only draw for the first glyph range of each line
            let charIndex = layoutManager.characterIndexForGlyph(at: range.location)
            if charIndex == 0 || (charIndex > 0 && text.character(at: charIndex - 1) == 0x0A) {
                let lineStr = "\(lineNumber)" as NSString
                let stringSize = lineStr.size(withAttributes: attrs)

                let yPosition = rect.origin.y + textContainerInset.height - (visibleRect.origin.y)
                let xPosition = self.bounds.width - stringSize.width - 8 - self.separatorWidth

                lineStr.draw(
                    at: NSPoint(x: xPosition, y: yPosition + (rect.height - stringSize.height) / 2),
                    withAttributes: attrs
                )

                lineNumber += 1
            }
        }
    }

    // MARK: - Observers

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func boundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    // MARK: - Utility

    private func countLines(in text: NSString, upTo location: Int? = nil) -> Int {
        let end = location ?? text.length
        var count = 0
        for i in 0..<end {
            if text.character(at: i) == 0x0A {
                count += 1
            }
        }
        // If counting total lines, add 1 for the last line
        if location == nil {
            count += 1
        }
        return count
    }
}
