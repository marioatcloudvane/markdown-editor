import AppKit
import WebKit

/// Container view controller that manages the transition between
/// the editor (NSTextView) and preview (WKWebView) modes.
/// Both child view controllers are kept alive to preserve state.
@MainActor
class ContentViewController: NSViewController {

    // MARK: - Child View Controllers

    private(set) var editorViewController: EditorViewController!
    private(set) var previewViewController: PreviewViewController!
    private var statusBarHostingView: NSView!
    private var documentMetrics = DocumentMetrics()

    /// The currently displayed mode
    private var currentMode: ViewMode = .editing

    /// Reference to the current document
    weak var document: MarkdownDocument?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        // Create child view controllers
        editorViewController = EditorViewController()
        editorViewController.documentMetrics = documentMetrics

        previewViewController = PreviewViewController()
        previewViewController.onContentChange = { [weak self] markdown in
            guard let self, let document = self.document else { return }
            if document.content != markdown {
                document.content = markdown
                document.updateChangeCount(.changeDone)
            }
        }

        // Create status bar
        let statusBarView = StatusBarView(metrics: documentMetrics)
        let hostingView = NSHostingView(rootView: statusBarView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        statusBarHostingView = hostingView
        view.addSubview(statusBarHostingView)

        // Add editor as initial child
        addChild(editorViewController)
        editorViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editorViewController.view)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Status bar at bottom
            statusBarHostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarHostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarHostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusBarHostingView.heightAnchor.constraint(equalToConstant: LayoutConstants.statusBarHeight),

            // Editor fills space below toolbar (safeAreaLayoutGuide accounts for fullSizeContentView)
            editorViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            editorViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorViewController.view.bottomAnchor.constraint(equalTo: statusBarHostingView.topAnchor),
        ])

        // Observe view mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewModeDidChange(_:)),
            name: .documentViewModeDidChange,
            object: nil
        )
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let document = document {
            editorViewController.loadDocument(document)
            documentMetrics.isEditingMode = document.viewMode == .editing

            // If the document defaults to preview mode, transition immediately
            if document.viewMode != currentMode {
                performTransition(to: document.viewMode, animated: false)
            }
        }
    }

    // MARK: - Document State Management

    /// Saves the current editor state to the document for tab-switch preservation.
    func saveDocumentState(_ document: MarkdownDocument) {
        if currentMode == .editing {
            if let textView = editorViewController.textView {
                document.savedSelectionRange = textView.selectedRange()
                document.savedScrollPosition = editorViewController.scrollView.contentView.bounds.origin
            }
        }
    }

    /// Restores saved editor state from the document after a tab switch.
    func restoreDocumentState(_ document: MarkdownDocument) {
        self.document = document
        documentMetrics.isEditingMode = document.viewMode == .editing

        if document.viewMode != currentMode {
            performTransition(to: document.viewMode, animated: false)
        }

        if currentMode == .editing {
            editorViewController.loadDocument(document)
        } else {
            previewViewController.renderMarkdown(document.content, baseURL: document.fileURL)
        }
    }

    // MARK: - Mode Transition

    @objc private func viewModeDidChange(_ notification: Notification) {
        guard let document = notification.object as? MarkdownDocument,
              document === self.document else { return }
        performTransition(to: document.viewMode, animated: true)
    }

    /// Performs the cross-dissolve transition between editing and preview modes.
    func performTransition(to mode: ViewMode, animated: Bool) {
        guard mode != currentMode else { return }

        let previousMode = currentMode
        currentMode = mode
        documentMetrics.isEditingMode = (mode == .editing)

        if mode == .preview {
            transitionToPreview(animated: animated)
        } else {
            transitionToEditing(animated: animated, previousMode: previousMode)
        }

        // Notify toolbar to update formatting buttons
        NotificationCenter.default.post(
            name: .contentModeDidTransition,
            object: self,
            userInfo: ["mode": mode]
        )
    }

    private func transitionToPreview(animated: Bool) {
        guard let document = document else { return }

        // Save editor state
        saveDocumentState(document)

        // Compute scroll fraction for position preservation
        let scrollFraction: Double
        if !document.content.isEmpty {
            scrollFraction = Double(document.savedSelectionRange.location) / Double(document.content.count)
        } else {
            scrollFraction = 0
        }

        // Prepare preview
        let html = MarkdownRenderer.renderHTML(from: document.content)
        previewViewController.scrollFractionOnLoad = scrollFraction

        // Add preview view
        addChild(previewViewController)
        previewViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewViewController.view, positioned: .below, relativeTo: statusBarHostingView)

        NSLayoutConstraint.activate([
            previewViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            previewViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewViewController.view.bottomAnchor.constraint(equalTo: statusBarHostingView.topAnchor),
        ])

        previewViewController.loadHTML(html, baseURL: document.fileURL?.deletingLastPathComponent())

        if animated {
            previewViewController.view.alphaValue = 0
            let editorView = editorViewController.view
            let editorVC = editorViewController

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = LayoutConstants.modeTransitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                editorView.animator().alphaValue = 0
                self.previewViewController.view.animator().alphaValue = 1
            }, completionHandler: {
                editorView.removeFromSuperview()
                editorVC?.removeFromParent()
            })
        } else {
            editorViewController.view.removeFromSuperview()
            editorViewController.removeFromParent()
        }
    }

    private func transitionToEditing(animated: Bool, previousMode: ViewMode) {
        guard let document = document else { return }

        // Re-add editor view
        addChild(editorViewController)
        editorViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editorViewController.view, positioned: .below, relativeTo: statusBarHostingView)

        NSLayoutConstraint.activate([
            editorViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            editorViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorViewController.view.bottomAnchor.constraint(equalTo: statusBarHostingView.topAnchor),
        ])

        // Restore editor state
        editorViewController.loadDocument(document)

        if animated {
            editorViewController.view.alphaValue = 0
            let previewView = previewViewController.view
            let previewVC = previewViewController
            let editorView = editorViewController.view

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = LayoutConstants.modeTransitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                previewView.animator().alphaValue = 0
                editorView.animator().alphaValue = 1
            }, completionHandler: {
                previewView.removeFromSuperview()
                previewVC?.removeFromParent()
                editorView.alphaValue = 1
            })
        } else {
            previewViewController.view.removeFromSuperview()
            previewViewController.removeFromParent()
            editorViewController.view.alphaValue = 1
        }
    }
}

// MARK: - Additional Imports

import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the content view controller finishes a mode transition.
    static let contentModeDidTransition = Notification.Name("MdEditorContentModeDidTransition")
}
