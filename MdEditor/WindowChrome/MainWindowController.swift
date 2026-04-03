import AppKit
import WebKit

/// NSWindowController managing the main document window.
/// Configures the unified titlebar/toolbar style, native document tabs,
/// frame persistence, and full-screen support.
@MainActor
class MainWindowController: NSWindowController, NSWindowDelegate {

    /// Manages toolbar items and their state
    private(set) var toolbarManager: ToolbarManager!

    /// The main split view controller (sidebar + content)
    private(set) var splitViewController: MainSplitViewController!

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .unifiedTitleAndToolbar,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: true
        )
        self.init(window: window)
        shouldCascadeWindows = false
        windowDidLoad()
    }

    // MARK: - Window Lifecycle

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else { return }

        // Configure window
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "MdEditorDocumentWindow"
        window.setFrameAutosaveName("MdEditorMainWindow")
        window.minSize = NSSize(width: 500, height: 400)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.backgroundColor = NSColor.textBackgroundColor

        // Set up the split view controller
        splitViewController = MainSplitViewController()
        contentViewController = splitViewController

        // Wire the document to the content layer
        if let document = document as? MarkdownDocument {
            splitViewController.setDocument(document)
        }

        // Set up toolbar
        toolbarManager = ToolbarManager(windowController: self)
        let toolbar = NSToolbar(identifier: "MdEditorToolbar")
        toolbar.delegate = toolbarManager
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar

        // Sync toolbar state with document
        if let document = document as? MarkdownDocument {
            toolbarManager.updateForDocument(document)
        }

        // Observe document edited state changes to update the tab's unsaved indicator
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentEditedStateDidChange(_:)),
            name: .documentEditedStateDidChange,
            object: nil
        )
    }

    // MARK: - Window Display

    override func showWindow(_ sender: Any?) {
        guard let window = window else {
            super.showWindow(sender)
            return
        }

        // Find any existing visible MdEditor window to tab into
        let target = NSApp.windows.first { w in
            w !== window &&
            w.tabbingIdentifier == "MdEditorDocumentWindow" &&
            w.isVisible &&
            !w.isMiniaturized
        }

        if let target = target {
            target.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            super.showWindow(sender)
        }
    }

    // MARK: - Document Access

    /// The markdown document associated with this window controller.
    var markdownDocument: MarkdownDocument? {
        return document as? MarkdownDocument
    }

    /// The content view controller managing editor/preview transitions.
    var contentViewController_: ContentViewController? {
        return splitViewController?.contentViewController
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        if let document = markdownDocument {
            toolbarManager?.updateForDocument(document)
            contentViewController_?.restoreDocumentState(document)
        }
        updateTabUnsavedIndicator()
    }

    func windowDidResignKey(_ notification: Notification) {
        if let document = markdownDocument {
            contentViewController_?.saveDocumentState(document)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let document = markdownDocument {
            contentViewController_?.saveDocumentState(document)
        }
    }

    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
        return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
    }

    // MARK: - Unsaved Indicator

    @objc private func documentEditedStateDidChange(_ notification: Notification) {
        guard let doc = notification.object as? MarkdownDocument,
              doc === markdownDocument else { return }
        updateTabUnsavedIndicator()
    }

    /// Shows or hides a small blue dot on the window's tab to indicate unsaved changes.
    private func updateTabUnsavedIndicator() {
        guard let window = window else { return }
        let isEdited = markdownDocument?.isDocumentEdited ?? false
        if isEdited {
            if window.tab.accessoryView == nil {
                let dot = UnsavedDotView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
                window.tab.accessoryView = dot
            }
        } else {
            window.tab.accessoryView = nil
        }
    }
}

/// Small blue dot drawn as a filled circle, used as a tab accessory view
/// to indicate unsaved changes.
private class UnsavedDotView: NSView {
    private static let dotSize: CGFloat = 8

    override var intrinsicContentSize: NSSize {
        return NSSize(width: Self.dotSize, height: Self.dotSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        let size = Self.dotSize
        let rect = NSRect(x: (bounds.width - size) / 2,
                          y: (bounds.height - size) / 2,
                          width: size, height: size).insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: rect)
        NSColor.systemBlue.withAlphaComponent(0.85).setFill()
        path.fill()
    }
}

// MARK: - FormattingResponder (WKWebView / Preview Mode)

extension MainWindowController: @preconcurrency FormattingResponder {

    // Only handle these when we're in preview mode (WKWebView).
    // In editing mode, MarkdownTextView is first responder and handles them directly.
    private var isInPreviewMode: Bool {
        return markdownDocument?.viewMode == .preview
    }

    private func execJS(_ command: String) {
        guard let webView = splitViewController?.contentViewController?.previewViewController?.webView else { return }
        webView.evaluateJavaScript(command, completionHandler: nil)
    }

    @objc func toggleBold(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('bold', false, null)")
    }

    @objc func toggleItalic(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('italic', false, null)")
    }

    @objc func insertLink(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("""
        (function(){
            var sel = window.getSelection();
            var url = 'https://';
            if (sel && sel.rangeCount > 0) {
                document.execCommand('createLink', false, url);
            }
        })()
        """)
    }

    @objc func toggleInlineCode(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("""
        (function(){
            var sel = window.getSelection();
            if (!sel || sel.rangeCount === 0) return;
            var range = sel.getRangeAt(0);
            if (range.collapsed) return;
            var code = document.createElement('code');
            try { range.surroundContents(code); } catch(e) {}
        })()
        """)
    }

    @objc func toggleBulletList(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('insertUnorderedList', false, null)")
    }

    @objc func toggleNumberedList(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('insertOrderedList', false, null)")
    }

    @objc func toggleTaskList(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('insertUnorderedList', false, null)")
    }

    @objc func cycleHeading(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("""
        (function(){
            var sel = window.getSelection();
            if (!sel || sel.rangeCount === 0) return;
            var node = sel.anchorNode;
            while (node && node.nodeType !== 1) node = node.parentNode;
            var tag = node ? node.tagName : '';
            var next = '';
            if (tag === 'H1') next = 'H2';
            else if (tag === 'H2') next = 'H3';
            else if (tag === 'H3') next = 'P';
            else next = 'H1';
            document.execCommand('formatBlock', false, next);
        })()
        """)
    }

    @objc func setHeading1(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'H1')")
    }

    @objc func setHeading2(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'H2')")
    }

    @objc func setHeading3(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'H3')")
    }

    @objc func setHeading4(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'H4')")
    }

    @objc func setHeading5(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'H5')")
    }

    @objc func setHeading6(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'H6')")
    }

    @objc func toggleStrikethrough(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('strikeThrough', false, null)")
    }

    @objc func toggleBlockquote(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'BLOCKQUOTE')")
    }

    @objc func insertCodeBlock(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('formatBlock', false, 'PRE')")
    }

    @objc func insertHorizontalRule(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('insertHorizontalRule', false, null)")
    }

    @objc func insertImage(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("document.execCommand('insertImage', false, 'image-url')")
    }

    @objc func insertTable(_ sender: Any?) {
        guard isInPreviewMode else { return }
        execJS("""
        (function(){
            var table = '<table><thead><tr><th>Column 1</th><th>Column 2</th><th>Column 3</th></tr></thead><tbody><tr><td></td><td></td><td></td></tr></tbody></table>';
            document.execCommand('insertHTML', false, table);
        })()
        """)
    }

    // Validate: enable formatting actions only in preview mode
    @objc func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let formattingSelectors: [Selector] = [
            #selector(toggleBold(_:)), #selector(toggleItalic(_:)),
            #selector(insertLink(_:)), #selector(toggleInlineCode(_:)),
            #selector(toggleBulletList(_:)), #selector(toggleNumberedList(_:)),
            #selector(toggleTaskList(_:)), #selector(cycleHeading(_:)),
            #selector(setHeading1(_:)), #selector(setHeading2(_:)),
            #selector(setHeading3(_:)), #selector(setHeading4(_:)),
            #selector(setHeading5(_:)), #selector(setHeading6(_:)),
            #selector(toggleStrikethrough(_:)), #selector(toggleBlockquote(_:)),
            #selector(insertCodeBlock(_:)), #selector(insertHorizontalRule(_:)),
            #selector(insertImage(_:)), #selector(insertTable(_:)),
        ]
        if let action = item.action, formattingSelectors.contains(action) {
            return isInPreviewMode
        }
        return true
    }
}
