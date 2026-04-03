import AppKit

/// Main application delegate that configures the app lifecycle,
/// registers defaults, and sets up the document controller.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    /// The custom document controller must be created before the app finishes launching.
    private var documentController: DocumentController!

    // MARK: - Application Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Build the main menu FIRST — before the system sets its default menu.
        let menuBuilder = MenuBuilder()
        NSApp.mainMenu = menuBuilder.buildMainMenu()

        // Set special menus AFTER mainMenu is established to avoid
        // AppKit corrupting the menu structure when these are set while mainMenu is nil.
        NSApp.servicesMenu = menuBuilder.servicesMenu
        NSApp.windowsMenu = menuBuilder.windowsMenu
        NSApp.helpMenu = menuBuilder.helpMenu

        // Create the custom document controller BEFORE the app finishes launching.
        // NSDocumentController uses the first instance created as the shared controller.
        documentController = DocumentController()

        // Register default preferences
        UserDefaults.standard.register(defaults: [
            "editorFontFamily": EditorDefaults.fontFamily,
            "editorFontSize": EditorDefaults.fontSize,
            "editorTabWidth": EditorDefaults.tabWidth,
            "showLineNumbers": false,
            "wordWrap": true,
            "spellCheck": true,
            "autoContinueLists": true,
            "previewFontSize": PreviewDefaults.fontSize,
            "codeBlockTheme": "auto",
            "restoreTabsOnLaunch": true,
            "defaultFileExtension": "md",
            "newWindowBehavior": "tab"
        ])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable automatic window tabbing so documents group into one tab bar
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            do {
                _ = try documentController.openUntitledDocumentAndDisplay(true)
            } catch {
                NSApp.presentError(error)
            }
        }
        return true
    }

    // MARK: - Menu Actions

    @objc func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.showWindow(sender)
    }

    @objc func openFolder(_ sender: Any?) {
        documentController.openFolder(sender)
    }

    @objc func saveAllDocuments(_ sender: Any?) {
        documentController.saveAllDocuments()
    }

    @objc func closeAllTabs(_ sender: Any?) {
        documentController.closeAllDocuments()
    }

    @objc func exportAsHTML(_ sender: Any?) {
        guard let document = NSDocumentController.shared.currentDocument as? MarkdownDocument,
              let window = document.windowControllers.first?.window else { return }
        HTMLExporter.exportHTML(
            from: document.content,
            documentName: document.displayName ?? "Untitled",
            in: window
        )
    }

    @objc func exportAsPDF(_ sender: Any?) {
        guard let document = NSDocumentController.shared.currentDocument as? MarkdownDocument,
              let window = document.windowControllers.first?.window else { return }
        PDFExporter.exportPDF(
            from: document.content,
            documentName: document.displayName ?? "Untitled",
            in: window
        )
    }

    @objc func openMarkdownSyntaxGuide(_ sender: Any?) {
        let guideContent = MarkdownSyntaxGuide.content
        do {
            let document = try documentController.openUntitledDocumentAndDisplay(true) as! MarkdownDocument
            document.content = guideContent
            document.viewMode = .preview
            NotificationCenter.default.post(
                name: .documentContentDidLoad,
                object: document
            )
        } catch {
            NSApp.presentError(error)
        }
    }
}
