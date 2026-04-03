import AppKit

/// View controller hosting the NSTextView-based editing surface.
/// Manages the TextKit 1 stack, document content synchronization,
/// spatial layout (padding, centering, bottom overscroll), and
/// cursor tracking for the status bar.
@MainActor
class EditorViewController: NSViewController, NSTextStorageDelegate {

    // MARK: - Properties

    private(set) var scrollView: NSScrollView!
    private(set) var textView: MarkdownTextView!
    private(set) var textStorage: MarkdownTextStorage!
    private var lineNumberGutter: LineNumberGutter?

    /// Metrics object updated for the status bar
    var documentMetrics: DocumentMetrics?

    /// The document currently being edited
    private weak var currentDocument: MarkdownDocument?

    /// Flag to suppress content sync during programmatic text load
    private var isSyncingContent = false

    // MARK: - View Lifecycle

    override func loadView() {
        // Create the TextKit 1 stack manually
        textStorage = MarkdownTextStorage()
        textStorage.delegate = self

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        // Create scroll view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = true

        // Create text view
        textView = MarkdownTextView(frame: .zero, textContainer: textContainer)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = AppPreferences.shared.spellCheck
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.textColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor
        ]

        // Register for image drag-and-drop
        textView.registerForDraggedTypes([.fileURL])

        // Configure font and paragraph style
        applyFontAndParagraphStyle()

        scrollView.documentView = textView
        view = scrollView

        // Observe selection changes for cursor position
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewSelectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        // Observe preferences changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Set up line numbers (hidden by default)
        updateLineNumberVisibility()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateTextContainerInsets()
    }

    // MARK: - Document Loading

    /// Loads document content into the text view.
    func loadDocument(_ document: MarkdownDocument) {
        currentDocument = document
        textView.markdownDocument = document

        isSyncingContent = true

        textStorage.beginEditing()
        if textStorage.string != document.content {
            textStorage.replaceCharacters(
                in: NSRange(location: 0, length: textStorage.length),
                with: document.content
            )
        }
        textStorage.endEditing()

        // Rehighlight the full document
        textStorage.rehighlightAll()

        isSyncingContent = false

        // Restore cursor and scroll position
        let selectionRange = document.savedSelectionRange
        if selectionRange.location + selectionRange.length <= (textView.string as NSString).length {
            textView.setSelectedRange(selectionRange)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scrollView.contentView.scroll(to: document.savedScrollPosition)
            self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
        }

        updateMetrics()
    }

    // MARK: - NSTextStorageDelegate

    nonisolated func textStorage(_ textStorage: NSTextStorage,
                                  didProcessEditing editedMask: NSTextStorageEditActions,
                                  range editedRange: NSRange,
                                  changeInLength delta: Int) {
        MainActor.assumeIsolated {
            guard editedMask.contains(.editedCharacters), !isSyncingContent else { return }

            if let document = currentDocument, !document.isLoadingContent {
                document.content = textStorage.string
                document.updateChangeCount(.changeDone)
            }

            updateMetrics()
        }
    }

    // MARK: - Spatial Layout

    private func updateTextContainerInsets() {
        let availableWidth = scrollView.bounds.width
        let gutterWidth = lineNumberGutter?.ruleThickness ?? 0
        let effectiveWidth = availableWidth - gutterWidth
        let maxContentWidth = LayoutConstants.editorMaxContentWidth
        let horizontalPadding = max(LayoutConstants.editorHorizontalPadding,
                                     (effectiveWidth - maxContentWidth) / 2)

        // Bottom overscroll: allow last line to reach vertical center
        let bottomInset = max(scrollView.bounds.height / 2, 100)

        textView.textContainerInset = NSSize(
            width: horizontalPadding,
            height: LayoutConstants.editorTopPadding
        )

        // Set additional bottom inset for overscroll
        let currentInset = textView.textContainerInset
        textView.textContainerInset = NSSize(width: currentInset.width, height: currentInset.height)

        // Use a more reliable way to set bottom overscroll
        if let textContainer = textView.textContainer {
            textContainer.size = NSSize(
                width: effectiveWidth - horizontalPadding * 2,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        // Bottom overscroll via additional text inset
        textView.textInsetBottomOverscroll = bottomInset
    }

    // MARK: - Font and Style

    private func applyFontAndParagraphStyle() {
        let font = AppPreferences.shared.editorFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = EditorDefaults.lineHeightMultiple

        textView.font = font
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    // MARK: - Line Numbers

    private func updateLineNumberVisibility() {
        let showLineNumbers = AppPreferences.shared.showLineNumbers

        if showLineNumbers {
            if lineNumberGutter == nil {
                let gutter = LineNumberGutter(textView: textView, scrollView: scrollView)
                scrollView.verticalRulerView = gutter
                lineNumberGutter = gutter
            }
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        } else {
            scrollView.rulersVisible = false
            scrollView.hasVerticalRuler = false
        }

        updateTextContainerInsets()
    }

    // MARK: - Cursor Position and Metrics

    @objc private func textViewSelectionDidChange(_ notification: Notification) {
        updateMetrics()
        textView.needsDisplay = true  // Redraw for current line highlight
    }

    private func updateMetrics() {
        guard let metrics = documentMetrics else { return }

        let text = textView.string as NSString
        let selectedRange = textView.selectedRange()

        // Compute line and column
        var line = 1
        var column = 1
        let cursorLocation = min(selectedRange.location, text.length)

        for i in 0..<cursorLocation {
            if text.character(at: i) == 0x0A { // newline
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        metrics.line = line
        metrics.column = column

        // Word and character counts
        let content = textView.string
        metrics.characterCount = content.count
        metrics.wordCount = countWords(in: content)
    }

    private func countWords(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        var count = 0
        let nsText = text as NSString
        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.byWords, .substringNotRequired]
        ) { _, _, _, _ in
            count += 1
        }
        return count
    }

    // MARK: - Preferences Updates

    @objc private func preferencesDidChange(_ notification: Notification) {
        applyFontAndParagraphStyle()
        textStorage.rehighlightAll()
        updateLineNumberVisibility()
        textView.isContinuousSpellCheckingEnabled = AppPreferences.shared.spellCheck

        if !AppPreferences.shared.wordWrap {
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
        } else {
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
        }
    }
}

// MARK: - Bottom Overscroll Extension

extension MarkdownTextView {
    /// Additional bottom inset for allowing the last line to scroll to center.
    var textInsetBottomOverscroll: CGFloat {
        get { return 0 }
        set {
            guard let scrollView = enclosingScrollView else { return }
            let existingTop = scrollView.contentInsets.top
            let contentInsets = NSEdgeInsets(top: existingTop, left: 0, bottom: newValue, right: 0)
            scrollView.contentInsets = contentInsets
        }
    }
}
