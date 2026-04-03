import AppKit

/// Custom NSDocumentController that manages the document lifecycle,
/// untitled document numbering, and ensures a blank document is
/// always available when the last tab is closed.
@MainActor
class DocumentController: NSDocumentController {

    // MARK: - Untitled Numbering

    /// Monotonically incrementing counter for untitled documents.
    /// Never recycles within a session.
    private var nextUntitledNumber: Int = 1

    /// Flag to prevent re-entrant new-document creation when closing last tab.
    private var isHandlingLastClose: Bool = false

    /// Flag to indicate a Close All operation is in progress.
    private var isClosingAll: Bool = false

    // MARK: - Lifecycle

    override init() {
        super.init()
        observeDocumentChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeDocumentChanges()
    }

    // MARK: - Untitled Document Numbering

    /// Assigns the next untitled number to a document.
    func assignUntitledNumber(to document: MarkdownDocument) {
        document.untitledNumber = nextUntitledNumber
        nextUntitledNumber += 1
    }

    // MARK: - Document Lifecycle Overrides

    override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = try super.openUntitledDocumentAndDisplay(displayDocument)
        if let mdDocument = document as? MarkdownDocument, mdDocument.untitledNumber == nil {
            assignUntitledNumber(to: mdDocument)
        }
        return document
    }

    override func removeDocument(_ document: NSDocument) {
        super.removeDocument(document)
        // Do NOT reopen a new document when the last one closes.
        // The app sits empty; the user can open or create a new doc from the menu or dock.
        // applicationShouldHandleReopen handles the dock-click case.
    }

    // MARK: - Close All

    /// Closes all documents, showing save prompts for dirty ones.
    func closeAllDocuments() {
        isClosingAll = true
        closeAllDocuments(withDelegate: self,
                         didCloseAllSelector: #selector(didCloseAll(_:didCloseAll:contextInfo:)),
                         contextInfo: nil)
    }

    @objc private func didCloseAll(_ controller: NSDocumentController,
                                    didCloseAll: Bool,
                                    contextInfo: UnsafeMutableRawPointer?) {
        isClosingAll = false
    }

    // MARK: - Save All

    /// Saves all dirty documents, prompting Save As for untitled ones.
    func saveAllDocuments() {
        for document in documents {
            if document.isDocumentEdited {
                document.save(nil)
            }
        }
    }

    // MARK: - Open Folder

    /// Opens a folder and populates the sidebar with its file tree.
    /// - Parameter sender: The action sender.
    @objc func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a folder to open")
        panel.prompt = String(localized: "Open")

        guard let window = NSApp.mainWindow else {
            panel.begin { [weak self] response in
                if response == .OK, let url = panel.url {
                    self?.handleFolderSelection(url, window: nil)
                }
            }
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.handleFolderSelection(url, window: window)
            }
        }
    }

    private func handleFolderSelection(_ url: URL, window: NSWindow?) {
        let tree = FolderScanner.scanFolder(at: url)
        let fileCount = FolderScanner.countFiles(in: tree)

        if fileCount == 0 {
            let alert = NSAlert()
            alert.messageText = String(localized: "No Markdown Files Found")
            alert.informativeText = String(localized: "No Markdown files were found in \"\(url.lastPathComponent)\".")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "OK"))
            if let window = window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
            return
        }

        if fileCount > 50 {
            let alert = NSAlert()
            alert.messageText = String(localized: "Large Folder")
            alert.informativeText = String(localized: "This folder contains \(fileCount) Markdown files. Opening all of them may use significant memory. Continue?")
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Open All"))
            alert.addButton(withTitle: String(localized: "Cancel"))

            let response: NSApplication.ModalResponse
            if let window = window {
                response = alert.runModal()
            } else {
                response = alert.runModal()
            }
            if response != .alertFirstButtonReturn {
                return
            }
        }

        // Post notification to show sidebar with folder tree
        NotificationCenter.default.post(
            name: .folderDidOpen,
            object: self,
            userInfo: ["folderURL": url, "tree": tree]
        )
    }

    // MARK: - Document Change Observation

    private func observeDocumentChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentCountChanged),
            name: NSNotification.Name("NSDocumentControllerDidAddDocumentNotification"),
            object: nil
        )
    }

    @objc private func documentCountChanged() {
        // Refresh display names for all documents (handles disambiguation)
        for document in documents {
            for windowController in document.windowControllers {
                windowController.synchronizeWindowTitleWithDocumentName()
            }
        }
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    /// Posted when a folder is opened via Open Folder.
    static let folderDidOpen = Notification.Name("MdEditorFolderDidOpen")
}
