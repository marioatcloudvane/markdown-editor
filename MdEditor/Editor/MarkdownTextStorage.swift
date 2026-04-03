import AppKit

/// Custom NSTextStorage subclass that provides markdown syntax highlighting.
/// Uses regex-based line-by-line scanning for per-keystroke performance.
@MainActor
class MarkdownTextStorage: NSTextStorage {

    // MARK: - Backing Store

    private let backingStore = NSMutableAttributedString()

    /// Guard against recursive processEditing calls during highlighting
    private var isHighlighting = false

    // MARK: - NSTextStorage Required Overrides

    override var string: String {
        return backingStore.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Syntax Highlighting

    override func processEditing() {
        if !isHighlighting && editedMask.contains(.editedCharacters) {
            isHighlighting = true
            applyHighlighting(in: editedRange)
            isHighlighting = false
        }
        super.processEditing()
    }

    /// Re-applies syntax highlighting to the specified range, expanded to full line boundaries.
    func applyHighlighting(in editedRange: NSRange) {
        let text = string as NSString
        guard text.length > 0 else { return }

        // Expand to full line boundaries and include neighboring lines for multi-line constructs
        let expandedRange = expandToLineRange(editedRange, in: text)
        guard expandedRange.length > 0, NSMaxRange(expandedRange) <= text.length else { return }

        let baseFontSize = AppPreferences.shared.editorFontSize
        let baseFont = AppPreferences.shared.editorFont

        // Default paragraph style with line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = EditorDefaults.lineHeightMultiple

        // Reset attributes in the affected range to defaults
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]
        backingStore.setAttributes(defaultAttrs, range: expandedRange)

        // Process each line within the range
        text.enumerateSubstrings(in: expandedRange, options: [.byLines, .substringNotRequired]) { [weak self] _, lineRange, enclosingRange, _ in
            guard let self = self else { return }
            let lineText = text.substring(with: lineRange)
            self.highlightLine(lineText, range: lineRange, baseFontSize: baseFontSize, baseFont: baseFont, paragraphStyle: paragraphStyle)
        }

        // Handle fenced code blocks
        highlightFencedCodeBlocks(in: expandedRange, text: text, baseFont: baseFont, paragraphStyle: paragraphStyle)
    }

    /// Applies a full document re-highlight (used after font size changes).
    func rehighlightAll() {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard fullRange.length > 0 else { return }
        isHighlighting = true
        applyHighlighting(in: fullRange)
        isHighlighting = false
    }

    // MARK: - Line-Level Highlighting

    private func highlightLine(_ lineText: String,
                               range: NSRange,
                               baseFontSize: CGFloat,
                               baseFont: NSFont,
                               paragraphStyle: NSMutableParagraphStyle) {
        // Headings: # through ######
        if let headingMatch = lineText.range(of: #"^(#{1,6})\s+"#, options: .regularExpression) {
            let prefixStr = String(lineText[headingMatch])
            let level = prefixStr.filter({ $0 == "#" }).count
            let prefixLen = prefixStr.count

            // Dim the # characters
            let prefixRange = NSRange(location: range.location, length: prefixLen)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: prefixRange)

            // Scale heading content
            let contentRange = NSRange(location: range.location + prefixLen, length: range.length - prefixLen)
            if contentRange.length > 0 {
                let scale: CGFloat
                switch level {
                case 1: scale = 1.5
                case 2: scale = 1.3
                case 3: scale = 1.15
                default: scale = 1.0
                }
                let headingFont = NSFont.systemFont(ofSize: baseFontSize * scale, weight: .semibold)
                backingStore.addAttribute(.font, value: headingFont, range: contentRange)
                backingStore.addAttribute(.foregroundColor, value: NSColor.labelColor, range: contentRange)
            }
            return
        }

        let nsLine = lineText as NSString

        // Bold: **text**
        highlightWrappedPattern(#"\*\*(.+?)\*\*"#, in: nsLine, lineOffset: range.location,
                                markerLen: 2, baseFontSize: baseFontSize, isBold: true)

        // Italic: *text* (but not **)
        highlightWrappedPattern(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, in: nsLine, lineOffset: range.location,
                                markerLen: 1, baseFontSize: baseFontSize, isItalic: true)

        // Strikethrough: ~~text~~
        highlightWrappedPattern(#"~~(.+?)~~"#, in: nsLine, lineOffset: range.location,
                                markerLen: 2, baseFontSize: baseFontSize, isStrikethrough: true)

        // Inline code: `code`
        highlightInlineCode(in: nsLine, lineOffset: range.location, baseFontSize: baseFontSize)

        // Links: [text](url)
        highlightLinks(in: nsLine, lineOffset: range.location)

        // List markers: -, *, numbers
        highlightListMarkers(in: nsLine, lineOffset: range.location)

        // Blockquote markers: >
        if lineText.hasPrefix(">") {
            let markerRange = NSRange(location: range.location, length: min(2, nsLine.length))
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markerRange)
        }
    }

    // MARK: - Pattern Highlighting Helpers

    private func highlightWrappedPattern(_ pattern: String,
                                         in text: NSString,
                                         lineOffset: Int,
                                         markerLen: Int,
                                         baseFontSize: CGFloat,
                                         isBold: Bool = false,
                                         isItalic: Bool = false,
                                         isStrikethrough: Bool = false) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let lineRange = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, options: [], range: lineRange) { [weak self] match, _, _ in
            guard let self = self, let match = match else { return }
            let fullRange = NSRange(location: match.range.location + lineOffset, length: match.range.length)

            // Dim markers (opening)
            let openMarker = NSRange(location: fullRange.location, length: markerLen)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openMarker)

            // Dim markers (closing)
            let closeMarker = NSRange(location: NSMaxRange(fullRange) - markerLen, length: markerLen)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeMarker)

            // Apply formatting to content (between markers)
            let contentRange = NSRange(location: fullRange.location + markerLen,
                                       length: fullRange.length - markerLen * 2)
            if contentRange.length > 0 {
                if isBold {
                    let boldFont = NSFont.systemFont(ofSize: baseFontSize, weight: .bold)
                    backingStore.addAttribute(.font, value: boldFont, range: contentRange)
                }
                if isItalic {
                    if let currentFont = backingStore.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont {
                        let italicFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                        backingStore.addAttribute(.font, value: italicFont, range: contentRange)
                    }
                }
                if isStrikethrough {
                    backingStore.addAttribute(.strikethroughStyle,
                                             value: NSUnderlineStyle.single.rawValue,
                                             range: contentRange)
                }
            }
        }
    }

    private func highlightInlineCode(in text: NSString, lineOffset: Int, baseFontSize: CGFloat) {
        guard let regex = try? NSRegularExpression(pattern: #"`([^`]+)`"#, options: []) else { return }
        let range = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, options: [], range: range) { [weak self] match, _, _ in
            guard let self = self, let match = match else { return }
            let fullRange = NSRange(location: match.range.location + lineOffset, length: match.range.length)

            // Dim backticks
            let openTick = NSRange(location: fullRange.location, length: 1)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openTick)
            let closeTick = NSRange(location: NSMaxRange(fullRange) - 1, length: 1)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeTick)

            // Background tint for code content
            let contentRange = NSRange(location: fullRange.location + 1, length: fullRange.length - 2)
            if contentRange.length > 0 {
                backingStore.addAttribute(.backgroundColor,
                                         value: NSColor.quaternaryLabelColor,
                                         range: contentRange)
            }
        }
    }

    private func highlightLinks(in text: NSString, lineOffset: Int) {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, options: []) else { return }
        let range = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, options: [], range: range) { [weak self] match, _, _ in
            guard let self = self, let match = match else { return }
            let fullRange = NSRange(location: match.range.location + lineOffset, length: match.range.length)

            // Brackets and parens in tertiaryLabelColor
            let openBracket = NSRange(location: fullRange.location, length: 1)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openBracket)

            if match.numberOfRanges > 1 {
                let textRange = NSRange(location: match.range(at: 1).location + lineOffset,
                                        length: match.range(at: 1).length)
                backingStore.addAttribute(.foregroundColor,
                                         value: NSColor.controlAccentColor.withAlphaComponent(LayoutConstants.linkColorOpacity),
                                         range: textRange)
            }

            if match.numberOfRanges > 2 {
                let urlRange = NSRange(location: match.range(at: 2).location + lineOffset,
                                       length: match.range(at: 2).length)
                backingStore.addAttribute(.foregroundColor,
                                         value: NSColor.tertiaryLabelColor,
                                         range: urlRange)
            }

            // Closing bracket and opening paren
            let closeBracket = NSRange(location: fullRange.location + 1 + (match.numberOfRanges > 1 ? match.range(at: 1).length : 0), length: 2)
            if NSMaxRange(closeBracket) <= NSMaxRange(fullRange) {
                backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeBracket)
            }

            // Closing paren
            let closeParen = NSRange(location: NSMaxRange(fullRange) - 1, length: 1)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeParen)
        }
    }

    private func highlightListMarkers(in text: NSString, lineOffset: Int) {
        guard let regex = try? NSRegularExpression(pattern: #"^(\s*)([-*]|\d+\.)\s"#, options: []) else { return }
        let range = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, options: [], range: range) { [weak self] match, _, _ in
            guard let self = self, let match = match, match.numberOfRanges > 2 else { return }
            let markerRange = NSRange(location: match.range(at: 2).location + lineOffset,
                                      length: match.range(at: 2).length)
            backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markerRange)
        }
    }

    private func highlightFencedCodeBlocks(in range: NSRange, text: NSString, baseFont: NSFont, paragraphStyle: NSMutableParagraphStyle) {
        guard let regex = try? NSRegularExpression(pattern: #"```[^\n]*\n[\s\S]*?```"#, options: [.anchorsMatchLines]) else { return }

        // Search the full document for code blocks that intersect the range
        let fullRange = NSRange(location: 0, length: text.length)
        regex.enumerateMatches(in: text as String, options: [], range: fullRange) { [weak self] match, _, _ in
            guard let self = self, let match = match else { return }
            // Only process code blocks that intersect with our range
            if NSIntersectionRange(match.range, range).length > 0 || NSLocationInRange(match.range.location, range) {
                // Apply background tint to the entire code block
                backingStore.addAttribute(.backgroundColor,
                                         value: NSColor.quaternaryLabelColor.withAlphaComponent(0.3),
                                         range: match.range)
                // Dim the fence markers
                let blockText = text.substring(with: match.range)
                if let fenceStart = blockText.range(of: "```") {
                    let fenceLen = blockText.distance(from: blockText.startIndex, to: fenceStart.upperBound)
                    if let lineEnd = blockText.range(of: "\n") {
                        let headerLen = blockText.distance(from: blockText.startIndex, to: lineEnd.lowerBound)
                        let headerRange = NSRange(location: match.range.location, length: headerLen)
                        backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: headerRange)
                    }
                }
                // Dim closing fence
                if blockText.hasSuffix("```") {
                    let closingRange = NSRange(location: NSMaxRange(match.range) - 3, length: 3)
                    backingStore.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closingRange)
                }
            }
        }
    }

    // MARK: - Utility

    private func expandToLineRange(_ range: NSRange, in text: NSString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }

        let clampedRange = NSRange(
            location: min(range.location, text.length),
            length: min(range.length, text.length - min(range.location, text.length))
        )

        var lineRange = text.lineRange(for: clampedRange)

        // Expand one line before and after for multi-line constructs
        if lineRange.location > 0 {
            let prevLineRange = text.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
            lineRange = NSUnionRange(lineRange, prevLineRange)
        }
        if NSMaxRange(lineRange) < text.length {
            let nextLineRange = text.lineRange(for: NSRange(location: NSMaxRange(lineRange), length: 0))
            lineRange = NSUnionRange(lineRange, nextLineRange)
        }

        return lineRange
    }
}
