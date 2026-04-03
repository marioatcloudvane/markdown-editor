import AppKit

/// NSDocument subclass serving as the data model for markdown files.
/// Stores the raw markdown content as a plain String and handles
/// file I/O, auto-save, and dirty state management.
@MainActor
class MarkdownDocument: NSDocument {

    // MARK: - Document Content

    /// The raw markdown text content. This is the single source of truth.
    var content: String = ""

    // MARK: - Transient UI State (not persisted to disk)

    /// The current display mode for this document.
    /// .preview = WKWebView WYSIWYG editor (default, primary)
    /// .editing = NSTextView raw markdown source (secondary, reference only)
    var viewMode: ViewMode = .preview {
        didSet {
            NotificationCenter.default.post(
                name: .documentViewModeDidChange,
                object: self
            )
        }
    }

    /// Saved cursor selection range, preserved across tab switches.
    var savedSelectionRange: NSRange = NSRange(location: 0, length: 0)

    /// Saved scroll position, preserved across tab switches.
    var savedScrollPosition: NSPoint = .zero

    /// Assigned untitled number for display name. Nil if saved to disk.
    var untitledNumber: Int?

    /// Flag to suppress change tracking during programmatic content load.
    var isLoadingContent: Bool = false

    // MARK: - NSDocument Configuration

    override class var autosavesInPlace: Bool {
        return true
    }

    override class var autosavesDrafts: Bool {
        return true
    }

    override class var preservesVersions: Bool {
        return true
    }

    // MARK: - Display Name

    override var displayName: String! {
        get {
            if let fileURL = fileURL {
                let filename = fileURL.lastPathComponent
                let ext = fileURL.pathExtension.lowercased()
                let baseName: String
                if SupportedExtensions.hideExtension.contains(ext) {
                    baseName = fileURL.deletingPathExtension().lastPathComponent
                } else {
                    baseName = filename
                }

                // Check for duplicate names among open documents
                let documents = NSDocumentController.shared.documents
                let duplicates = documents.filter { doc in
                    guard let otherURL = doc.fileURL, doc !== self else { return false }
                    let otherBase: String
                    let otherExt = otherURL.pathExtension.lowercased()
                    if SupportedExtensions.hideExtension.contains(otherExt) {
                        otherBase = otherURL.deletingPathExtension().lastPathComponent
                    } else {
                        otherBase = otherURL.lastPathComponent
                    }
                    return otherBase == baseName
                }

                if !duplicates.isEmpty {
                    let parentFolder = fileURL.deletingLastPathComponent().lastPathComponent
                    return "\(baseName) (\(parentFolder))"
                }

                return baseName
            }

            if let number = untitledNumber {
                if number == 1 {
                    return String(localized: "Untitled")
                }
                return String(localized: "Untitled \(number)")
            }

            return String(localized: "Untitled")
        }
        set {
            super.displayName = newValue
        }
    }

    // MARK: - File I/O

    override nonisolated func data(ofType typeName: String) throws -> Data {
        let contentString = MainActor.assumeIsolated { content }
        guard let data = contentString.data(using: .utf8) else {
            throw NSError(
                domain: "MdEditor",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not encode document content as UTF-8."
                ]
            )
        }
        return data
    }

    override nonisolated func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "MdEditor",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "This file does not appear to be a UTF-8 text file and cannot be opened."
                ]
            )
        }
        MainActor.assumeIsolated {
            isLoadingContent = true
            content = string
            isLoadingContent = false

            // Notify that content was loaded so the editor can update
            NotificationCenter.default.post(
                name: .documentContentDidLoad,
                object: self
            )
        }
    }

    // MARK: - Window Controller

    override func makeWindowControllers() {
        let windowController = MainWindowController()
        addWindowController(windowController)
    }

    // MARK: - Change Tracking

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        NotificationCenter.default.post(name: .documentEditedStateDidChange, object: self)
    }

    // MARK: - Save Panel Configuration

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = [
            .init(filenameExtension: "md")!,
            .init(filenameExtension: "markdown")!,
            .init(filenameExtension: "txt")!
        ]
        savePanel.allowsOtherFileTypes = false
        if fileURL == nil {
            savePanel.nameFieldStringValue = "\(displayName ?? "Untitled").md"
        }
        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a document's view mode changes between editing and preview.
    static let documentViewModeDidChange = Notification.Name("MdEditorDocumentViewModeDidChange")
    /// Posted when document content is loaded from file.
    static let documentContentDidLoad = Notification.Name("MdEditorDocumentContentDidLoad")
    /// Posted when a document's edited (unsaved) state changes.
    static let documentEditedStateDidChange = Notification.Name("MdEditorDocumentEditedStateDidChange")
}
