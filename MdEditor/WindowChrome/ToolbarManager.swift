import AppKit

/// Manages the NSToolbar, creating and configuring all toolbar items.
/// Handles toolbar state management including formatting button highlighting
/// and mode-dependent visibility.
@MainActor
class ToolbarManager: NSObject, NSToolbarDelegate {

    // MARK: - Properties

    private weak var windowController: MainWindowController?
    private var formattingButtons: [NSToolbarItem.Identifier: NSButton] = [:]
    private var formattingItems: [NSToolbarItem] = []
    private var segmentedControl: NSSegmentedControl?
    private var headingPopup: NSPopUpButton?

    // MARK: - Initialization

    init(windowController: MainWindowController) {
        self.windowController = windowController
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(modeDidTransition(_:)),
            name: .contentModeDidTransition,
            object: nil
        )
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .bold, .italic, .strikethrough,
            .flexibleSpace,
            .headingPicker,
            .bulletList, .numberedList,
            .flexibleSpace,
            .link, .code, .codeBlock,
            .blockquote,
            .flexibleSpace,
            .editPreviewToggle,
            .shareExport,
        ]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .bold:
            return makeFormattingItem(identifier: .bold,
                                     symbolName: "bold",
                                     tooltip: String(localized: "Bold (Cmd+B)"),
                                     action: #selector(FormattingResponder.toggleBold(_:)))
        case .italic:
            return makeFormattingItem(identifier: .italic,
                                     symbolName: "italic",
                                     tooltip: String(localized: "Italic (Cmd+I)"),
                                     action: #selector(FormattingResponder.toggleItalic(_:)))
        case .strikethrough:
            return makeFormattingItem(identifier: .strikethrough,
                                     symbolName: "strikethrough",
                                     tooltip: String(localized: "Strikethrough (Cmd+Shift+X)"),
                                     action: #selector(FormattingResponder.toggleStrikethrough(_:)))
        case .link:
            return makeFormattingItem(identifier: .link,
                                     symbolName: "link",
                                     tooltip: String(localized: "Link (Cmd+K)"),
                                     action: #selector(FormattingResponder.insertLink(_:)))
        case .code:
            return makeFormattingItem(identifier: .code,
                                     symbolName: "chevron.left.forwardslash.chevron.right",
                                     tooltip: String(localized: "Inline Code (Cmd+`)"),
                                     action: #selector(FormattingResponder.toggleInlineCode(_:)))
        case .codeBlock:
            return makeFormattingItem(identifier: .codeBlock,
                                     symbolName: "curlybraces",
                                     tooltip: String(localized: "Code Block (Cmd+Shift+C)"),
                                     action: #selector(FormattingResponder.insertCodeBlock(_:)))
        case .bulletList:
            return makeFormattingItem(identifier: .bulletList,
                                     symbolName: "list.bullet",
                                     tooltip: String(localized: "Bullet List (Cmd+Shift+8)"),
                                     action: #selector(FormattingResponder.toggleBulletList(_:)))
        case .numberedList:
            return makeFormattingItem(identifier: .numberedList,
                                     symbolName: "list.number",
                                     tooltip: String(localized: "Numbered List (Cmd+Shift+7)"),
                                     action: #selector(FormattingResponder.toggleNumberedList(_:)))
        case .headingPicker:
            return makeHeadingPickerItem()
        case .blockquote:
            return makeFormattingItem(identifier: .blockquote,
                                     symbolName: "text.quote",
                                     tooltip: String(localized: "Blockquote (Cmd+Shift+.)"),
                                     action: #selector(FormattingResponder.toggleBlockquote(_:)))
        case .editPreviewToggle:
            return makeEditPreviewToggle()
        case .shareExport:
            return makeShareExportItem()
        default:
            return nil
        }
    }

    // MARK: - Item Creation

    private func makeFormattingItem(identifier: NSToolbarItem.Identifier,
                                    symbolName: String,
                                    tooltip: String,
                                    action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        let button = NSButton(
            image: NSImage(systemSymbolName: symbolName,
                          accessibilityDescription: tooltip)
                ?? NSImage(named: NSImage.actionTemplateName)!,
            target: nil,
            action: action
        )
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.setAccessibilityLabel(tooltip)

        // Add tracking area for hover effect
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: HoverHandler(button: button),
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)

        item.view = button
        item.toolTip = tooltip
        item.label = tooltip.components(separatedBy: " (").first ?? tooltip
        formattingButtons[identifier] = button
        formattingItems.append(item)
        return item
    }

    private func makeEditPreviewToggle() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .editPreviewToggle)
        let control = NSSegmentedControl(
            labels: [String(localized: "Edit"), String(localized: "Markdown")],
            trackingMode: .selectOne,
            target: self,
            action: #selector(editPreviewToggleChanged(_:))
        )
        control.segmentStyle = .texturedRounded
        control.selectedSegment = 0
        control.setWidth(70, forSegment: 0)
        control.setWidth(70, forSegment: 1)
        segmentedControl = control
        item.view = control
        item.toolTip = String(localized: "Edit: WYSIWYG view — Markdown: raw source")
        item.label = String(localized: "Mode")
        return item
    }

    private func makeShareExportItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .shareExport)
        let button = NSButton(
            image: NSImage(systemSymbolName: "square.and.arrow.up",
                          accessibilityDescription: String(localized: "Export"))!,
            target: self,
            action: #selector(showExportMenu(_:))
        )
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        item.view = button
        item.toolTip = String(localized: "Export Document")
        item.label = String(localized: "Export")
        return item
    }

    private func makeHeadingPickerItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .headingPicker)
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 110, height: 24), pullsDown: false)
        popup.bezelStyle = .texturedRounded
        popup.addItem(withTitle: String(localized: "Paragraph"))
        popup.addItem(withTitle: String(localized: "Heading 1"))
        popup.addItem(withTitle: String(localized: "Heading 2"))
        popup.addItem(withTitle: String(localized: "Heading 3"))
        popup.addItem(withTitle: String(localized: "Heading 4"))
        popup.addItem(withTitle: String(localized: "Heading 5"))
        popup.addItem(withTitle: String(localized: "Heading 6"))
        popup.selectItem(at: 0)
        popup.target = self
        popup.action = #selector(headingPickerChanged(_:))
        popup.setAccessibilityLabel(String(localized: "Heading Level"))
        headingPopup = popup
        item.view = popup
        item.label = String(localized: "Heading")
        item.toolTip = String(localized: "Set heading level")
        formattingItems.append(item)
        return item
    }

    // MARK: - Actions

    @objc private func headingPickerChanged(_ sender: NSPopUpButton) {
        let level = sender.indexOfSelectedItem  // 0 = Paragraph, 1 = H1, ..., 6 = H6
        let selectors: [Selector] = [
            #selector(FormattingResponder.setHeading1(_:)),  // index 0: placeholder, handled below
            #selector(FormattingResponder.setHeading1(_:)),
            #selector(FormattingResponder.setHeading2(_:)),
            #selector(FormattingResponder.setHeading3(_:)),
            #selector(FormattingResponder.setHeading4(_:)),
            #selector(FormattingResponder.setHeading5(_:)),
            #selector(FormattingResponder.setHeading6(_:)),
        ]

        if level == 0 {
            // "Paragraph" means remove heading. In editing mode, call setHeading(level: 0).
            // In preview mode, use formatBlock P.
            if let wc = windowController {
                if wc.markdownDocument?.viewMode == .preview {
                    let webView = wc.splitViewController?.contentViewController?.previewViewController?.webView
                    webView?.evaluateJavaScript(
                        "document.execCommand('formatBlock', false, 'P')",
                        completionHandler: nil
                    )
                } else if let textView = wc.splitViewController?.contentViewController?.editorViewController?.textView {
                    FormattingCommands.setHeading(in: textView, level: 0)
                }
            }
        } else {
            NSApp.sendAction(selectors[level], to: nil, from: sender)
        }
    }

    @objc private func editPreviewToggleChanged(_ sender: NSSegmentedControl) {
        guard let document = windowController?.markdownDocument else { return }
        // Segment 0 = "Edit" → WKWebView WYSIWYG (.preview)
        // Segment 1 = "Markdown" → NSTextView raw source (.editing)
        let newMode: ViewMode = sender.selectedSegment == 0 ? .preview : .editing
        document.viewMode = newMode
    }

    @objc private func showExportMenu(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Export as HTML..."),
                     action: #selector(AppDelegate.exportAsHTML(_:)),
                     keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Export as PDF..."),
                     action: #selector(AppDelegate.exportAsPDF(_:)),
                     keyEquivalent: "")

        let point = NSPoint(x: 0, y: sender.bounds.height)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    // MARK: - State Management

    /// Updates the toolbar state to match the given document.
    func updateForDocument(_ document: MarkdownDocument) {
        // Segment 0 = "Edit" (.preview/WKWebView), Segment 1 = "Markdown" (.editing/NSTextView)
        segmentedControl?.selectedSegment = document.viewMode == .preview ? 0 : 1
        updateFormattingButtonsVisibility(for: document.viewMode, animated: false)
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        updateFormattingButtonHighlights(for: textView)
    }

    @objc private func modeDidTransition(_ notification: Notification) {
        guard let mode = notification.userInfo?["mode"] as? ViewMode else { return }
        updateFormattingButtonsVisibility(for: mode, animated: true)
        segmentedControl?.selectedSegment = mode == .preview ? 0 : 1
    }

    private func updateFormattingButtonsVisibility(for mode: ViewMode, animated: Bool) {
        let targetAlpha: CGFloat = (mode == .preview) ? 1.0 : 0.0
        let isEnabled = (mode == .preview)

        for item in formattingItems {
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = LayoutConstants.modeTransitionDuration
                    item.view?.animator().alphaValue = targetAlpha
                }
            } else {
                item.view?.alphaValue = targetAlpha
            }
            item.isEnabled = isEnabled
        }
    }

    private func updateFormattingButtonHighlights(for textView: NSTextView) {
        let range = textView.selectedRange()
        let text = textView.string as NSString

        // Bold detection
        let isBold = FormattingDetector.isWrapped(in: text, range: range, marker: "**")
        formattingButtons[.bold]?.contentTintColor = isBold ? .controlAccentColor : .secondaryLabelColor

        // Italic detection
        let isItalic = FormattingDetector.isWrapped(in: text, range: range, marker: "*")
        formattingButtons[.italic]?.contentTintColor = isItalic ? .controlAccentColor : .secondaryLabelColor

        // Strikethrough detection
        let isStrikethrough = FormattingDetector.isWrapped(in: text, range: range, marker: "~~")
        formattingButtons[.strikethrough]?.contentTintColor = isStrikethrough ? .controlAccentColor : .secondaryLabelColor

        // Code detection
        let isCode = FormattingDetector.isWrapped(in: text, range: range, marker: "`")
        formattingButtons[.code]?.contentTintColor = isCode ? .controlAccentColor : .secondaryLabelColor

        // Heading detection and popup sync
        let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
        let lineText = text.substring(with: lineRange)

        let headingLevel: Int
        if let match = lineText.range(of: #"^(#{1,6})\s"#, options: .regularExpression) {
            headingLevel = lineText[match].filter { $0 == "#" }.count
        } else {
            headingLevel = 0
        }
        headingPopup?.selectItem(at: headingLevel)

        // List detection
        let trimmedLine = lineText.trimmingCharacters(in: .whitespaces)
        let isBulletList = trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ")
        formattingButtons[.bulletList]?.contentTintColor = isBulletList ? .controlAccentColor : .secondaryLabelColor

        let isNumberedList = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
        formattingButtons[.numberedList]?.contentTintColor = isNumberedList ? .controlAccentColor : .secondaryLabelColor

        // Blockquote detection
        let isBlockquote = trimmedLine.hasPrefix("> ")
        formattingButtons[.blockquote]?.contentTintColor = isBlockquote ? .controlAccentColor : .secondaryLabelColor
    }
}

// MARK: - Hover Handler

/// Handles mouse hover effects on toolbar buttons.
@MainActor
private class HoverHandler: NSResponder {
    weak var button: NSButton?

    init(button: NSButton) {
        self.button = button
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseEntered(with event: NSEvent) {
        button?.isBordered = true
    }

    override func mouseExited(with event: NSEvent) {
        button?.isBordered = false
    }
}

// MARK: - Formatting Detection

/// Utility for detecting formatting state at a given text range.
enum FormattingDetector {
    /// Checks if the text at the given range is wrapped with the specified marker.
    static func isWrapped(in text: NSString, range: NSRange, marker: String) -> Bool {
        let markerLen = marker.count
        let start = range.location
        let end = range.location + range.length

        guard start >= markerLen, end + markerLen <= text.length else { return false }

        let before = text.substring(with: NSRange(location: start - markerLen, length: markerLen))
        let after = text.substring(with: NSRange(location: end, length: markerLen))

        return before == marker && after == marker
    }
}

// MARK: - Formatting Responder Protocol

/// Protocol for formatting actions dispatched through the responder chain.
@objc protocol FormattingResponder {
    @objc func toggleBold(_ sender: Any?)
    @objc func toggleItalic(_ sender: Any?)
    @objc func insertLink(_ sender: Any?)
    @objc func toggleInlineCode(_ sender: Any?)
    @objc func toggleBulletList(_ sender: Any?)
    @objc func toggleNumberedList(_ sender: Any?)
    @objc func toggleTaskList(_ sender: Any?)
    @objc func cycleHeading(_ sender: Any?)
    @objc func toggleStrikethrough(_ sender: Any?)
    @objc func toggleBlockquote(_ sender: Any?)
    @objc func insertCodeBlock(_ sender: Any?)
    @objc func insertHorizontalRule(_ sender: Any?)
    @objc func insertImage(_ sender: Any?)
    @objc func insertTable(_ sender: Any?)
    @objc func setHeading1(_ sender: Any?)
    @objc func setHeading2(_ sender: Any?)
    @objc func setHeading3(_ sender: Any?)
    @objc func setHeading4(_ sender: Any?)
    @objc func setHeading5(_ sender: Any?)
    @objc func setHeading6(_ sender: Any?)
}
