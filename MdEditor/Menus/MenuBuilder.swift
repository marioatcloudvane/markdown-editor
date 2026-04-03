import AppKit

/// Builds the complete main menu bar programmatically.
/// All formatting actions, file operations, and view toggles have
/// corresponding menu items with their keyboard shortcuts.
@MainActor
class MenuBuilder {

    /// The services menu, to be assigned to NSApp.servicesMenu after mainMenu is set.
    private(set) var servicesMenu: NSMenu?
    /// The windows menu, to be assigned to NSApp.windowsMenu after mainMenu is set.
    private(set) var windowsMenu: NSMenu?
    /// The help menu, to be assigned to NSApp.helpMenu after mainMenu is set.
    private(set) var helpMenu: NSMenu?

    /// Builds and returns the complete main menu.
    func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        mainMenu.addItem(buildAppMenu())
        mainMenu.addItem(buildFileMenu())
        mainMenu.addItem(buildEditMenu())
        mainMenu.addItem(buildFormatMenu())
        mainMenu.addItem(buildViewMenu())
        mainMenu.addItem(buildWindowMenu())
        mainMenu.addItem(buildHelpMenu())

        return mainMenu
    }

    // MARK: - App Menu

    private func buildAppMenu() -> NSMenuItem {
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: String(localized: "About Markdown Editor"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")

        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(withTitle: String(localized: "Preferences..."),
                        action: #selector(AppDelegate.showPreferences(_:)),
                        keyEquivalent: ",")

        appMenu.addItem(NSMenuItem.separator())

        let servicesItem = NSMenuItem(title: String(localized: "Services"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        self.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)

        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(withTitle: String(localized: "Hide Markdown Editor"),
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")

        let hideOthersItem = appMenu.addItem(withTitle: String(localized: "Hide Others"),
                                              action: #selector(NSApplication.hideOtherApplications(_:)),
                                              keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]

        appMenu.addItem(withTitle: String(localized: "Show All"),
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")

        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(withTitle: String(localized: "Quit Markdown Editor"),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        return appMenuItem
    }

    // MARK: - File Menu

    private func buildFileMenu() -> NSMenuItem {
        let fileMenu = NSMenu(title: String(localized: "File"))
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu

        fileMenu.addItem(withTitle: String(localized: "New"),
                         action: #selector(NSDocumentController.newDocument(_:)),
                         keyEquivalent: "n")

        let newTabItem = fileMenu.addItem(
            withTitle: String(localized: "New Tab"),
            action: #selector(NSDocumentController.newDocument(_:)),
            keyEquivalent: "t"
        )
        newTabItem.keyEquivalentModifierMask = [.command]

        fileMenu.addItem(withTitle: String(localized: "Open..."),
                         action: #selector(NSDocumentController.openDocument(_:)),
                         keyEquivalent: "o")

        // Open Recent submenu
        let recentItem = NSMenuItem(title: String(localized: "Open Recent"), action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent")
        recentMenu.performSelector(onMainThread: NSSelectorFromString("_setMenuName:"),
                                    with: "NSRecentDocumentsMenu", waitUntilDone: false)
        recentMenu.addItem(withTitle: String(localized: "Clear Menu"),
                           action: #selector(NSDocumentController.clearRecentDocuments(_:)),
                           keyEquivalent: "")
        recentItem.submenu = recentMenu
        fileMenu.addItem(recentItem)

        fileMenu.addItem(NSMenuItem.separator())

        fileMenu.addItem(withTitle: String(localized: "Close Tab"),
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")

        let closeAllItem = fileMenu.addItem(withTitle: String(localized: "Close All Tabs"),
                                             action: #selector(AppDelegate.closeAllTabs(_:)),
                                             keyEquivalent: "w")
        closeAllItem.keyEquivalentModifierMask = [.command, .option]

        fileMenu.addItem(NSMenuItem.separator())

        fileMenu.addItem(withTitle: String(localized: "Save"),
                         action: #selector(NSDocument.save(_:)),
                         keyEquivalent: "s")

        let saveAsItem = fileMenu.addItem(withTitle: String(localized: "Save As..."),
                                           action: #selector(NSDocument.saveAs(_:)),
                                           keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]

        let saveAllItem = fileMenu.addItem(withTitle: String(localized: "Save All"),
                                            action: #selector(AppDelegate.saveAllDocuments(_:)),
                                            keyEquivalent: "s")
        saveAllItem.keyEquivalentModifierMask = [.command, .option]

        fileMenu.addItem(NSMenuItem.separator())

        fileMenu.addItem(withTitle: String(localized: "Export as HTML..."),
                         action: #selector(AppDelegate.exportAsHTML(_:)),
                         keyEquivalent: "")

        fileMenu.addItem(withTitle: String(localized: "Export as PDF..."),
                         action: #selector(AppDelegate.exportAsPDF(_:)),
                         keyEquivalent: "")

        return fileMenuItem
    }

    // MARK: - Edit Menu

    private func buildEditMenu() -> NSMenuItem {
        let editMenu = NSMenu(title: String(localized: "Edit"))
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: String(localized: "Undo"),
                         action: Selector(("undo:")),
                         keyEquivalent: "z")

        let redoItem = editMenu.addItem(withTitle: String(localized: "Redo"),
                                         action: Selector(("redo:")),
                                         keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]

        editMenu.addItem(NSMenuItem.separator())

        editMenu.addItem(withTitle: String(localized: "Cut"),
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")

        editMenu.addItem(withTitle: String(localized: "Copy"),
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")

        editMenu.addItem(withTitle: String(localized: "Paste"),
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")

        let pasteMatchItem = editMenu.addItem(
            withTitle: String(localized: "Paste and Match Style"),
            action: #selector(NSTextView.pasteAsPlainText(_:)),
            keyEquivalent: "V"
        )
        pasteMatchItem.keyEquivalentModifierMask = [.command, .option, .shift]

        editMenu.addItem(withTitle: String(localized: "Select All"),
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")

        editMenu.addItem(NSMenuItem.separator())

        // Find submenu
        let findItem = NSMenuItem(title: String(localized: "Find"), action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")

        let findPanelItem = findMenu.addItem(withTitle: String(localized: "Find..."),
                                              action: #selector(NSTextView.performFindPanelAction(_:)),
                                              keyEquivalent: "f")
        findPanelItem.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)

        let findReplaceItem = findMenu.addItem(withTitle: String(localized: "Find and Replace..."),
                                                action: #selector(NSTextView.performFindPanelAction(_:)),
                                                keyEquivalent: "f")
        findReplaceItem.keyEquivalentModifierMask = [.command, .option]
        findReplaceItem.tag = Int(NSTextFinder.Action.showReplaceInterface.rawValue)

        let findNextItem = findMenu.addItem(withTitle: String(localized: "Find Next"),
                                             action: #selector(NSTextView.performFindPanelAction(_:)),
                                             keyEquivalent: "g")
        findNextItem.tag = Int(NSTextFinder.Action.nextMatch.rawValue)

        let findPrevItem = findMenu.addItem(withTitle: String(localized: "Find Previous"),
                                             action: #selector(NSTextView.performFindPanelAction(_:)),
                                             keyEquivalent: "G")
        findPrevItem.keyEquivalentModifierMask = [.command, .shift]
        findPrevItem.tag = Int(NSTextFinder.Action.previousMatch.rawValue)

        let useSelectionItem = findMenu.addItem(withTitle: String(localized: "Use Selection for Find"),
                                                 action: #selector(NSTextView.performFindPanelAction(_:)),
                                                 keyEquivalent: "e")
        useSelectionItem.tag = Int(NSTextFinder.Action.setSearchString.rawValue)

        findItem.submenu = findMenu
        editMenu.addItem(findItem)

        return editMenuItem
    }

    // MARK: - Format Menu

    private func buildFormatMenu() -> NSMenuItem {
        let formatMenu = NSMenu(title: String(localized: "Format"))
        let formatMenuItem = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
        formatMenuItem.submenu = formatMenu

        // Text formatting
        formatMenu.addItem(withTitle: String(localized: "Bold"),
                           action: #selector(FormattingResponder.toggleBold(_:)),
                           keyEquivalent: "b")

        formatMenu.addItem(withTitle: String(localized: "Italic"),
                           action: #selector(FormattingResponder.toggleItalic(_:)),
                           keyEquivalent: "i")

        let strikeItem = formatMenu.addItem(withTitle: String(localized: "Strikethrough"),
                                             action: #selector(FormattingResponder.toggleStrikethrough(_:)),
                                             keyEquivalent: "X")
        strikeItem.keyEquivalentModifierMask = [.command, .shift]

        formatMenu.addItem(withTitle: String(localized: "Inline Code"),
                           action: #selector(FormattingResponder.toggleInlineCode(_:)),
                           keyEquivalent: "`")

        formatMenu.addItem(NSMenuItem.separator())

        // Headings — collapsed into a submenu; shortcuts (Cmd+1…6) work from submenus too
        let headingMenuItem = NSMenuItem(title: String(localized: "Heading"), action: nil, keyEquivalent: "")
        let headingSubMenu = NSMenu(title: String(localized: "Heading"))
        let headingSelectors: [Selector] = [
            #selector(FormattingResponder.setHeading1(_:)),
            #selector(FormattingResponder.setHeading2(_:)),
            #selector(FormattingResponder.setHeading3(_:)),
            #selector(FormattingResponder.setHeading4(_:)),
            #selector(FormattingResponder.setHeading5(_:)),
            #selector(FormattingResponder.setHeading6(_:)),
        ]
        for level in 1...6 {
            headingSubMenu.addItem(withTitle: String(localized: "Heading \(level)"),
                                   action: headingSelectors[level - 1],
                                   keyEquivalent: "\(level)")
        }
        headingMenuItem.submenu = headingSubMenu
        formatMenu.addItem(headingMenuItem)

        formatMenu.addItem(NSMenuItem.separator())

        // Lists
        let bulletItem = formatMenu.addItem(withTitle: String(localized: "Bullet List"),
                                             action: #selector(FormattingResponder.toggleBulletList(_:)),
                                             keyEquivalent: "8")
        bulletItem.keyEquivalentModifierMask = [.command, .shift]

        let numberedItem = formatMenu.addItem(withTitle: String(localized: "Numbered List"),
                                               action: #selector(FormattingResponder.toggleNumberedList(_:)),
                                               keyEquivalent: "7")
        numberedItem.keyEquivalentModifierMask = [.command, .shift]

        let taskItem = formatMenu.addItem(withTitle: String(localized: "Task List"),
                                           action: #selector(FormattingResponder.toggleTaskList(_:)),
                                           keyEquivalent: "9")
        taskItem.keyEquivalentModifierMask = [.command, .shift]

        formatMenu.addItem(NSMenuItem.separator())

        // Block elements
        let blockquoteItem = formatMenu.addItem(withTitle: String(localized: "Blockquote"),
                                                 action: #selector(FormattingResponder.toggleBlockquote(_:)),
                                                 keyEquivalent: ".")
        blockquoteItem.keyEquivalentModifierMask = [.command, .shift]

        let codeBlockItem = formatMenu.addItem(withTitle: String(localized: "Code Block"),
                                                action: #selector(FormattingResponder.insertCodeBlock(_:)),
                                                keyEquivalent: "C")
        codeBlockItem.keyEquivalentModifierMask = [.command, .shift]

        formatMenu.addItem(NSMenuItem.separator())

        // Insert elements
        formatMenu.addItem(withTitle: String(localized: "Insert Link..."),
                           action: #selector(FormattingResponder.insertLink(_:)),
                           keyEquivalent: "k")

        let imageItem = formatMenu.addItem(withTitle: String(localized: "Insert Image..."),
                                            action: #selector(FormattingResponder.insertImage(_:)),
                                            keyEquivalent: "I")
        imageItem.keyEquivalentModifierMask = [.command, .shift]

        let tableItem = formatMenu.addItem(withTitle: String(localized: "Insert Table"),
                                            action: #selector(FormattingResponder.insertTable(_:)),
                                            keyEquivalent: "t")
        tableItem.keyEquivalentModifierMask = [.command, .option]

        let hrItem = formatMenu.addItem(withTitle: String(localized: "Insert Horizontal Rule"),
                                         action: #selector(FormattingResponder.insertHorizontalRule(_:)),
                                         keyEquivalent: "-")
        hrItem.keyEquivalentModifierMask = [.command, .shift]

        return formatMenuItem
    }

    // MARK: - View Menu

    private func buildViewMenu() -> NSMenuItem {
        let viewMenu = NSMenu(title: String(localized: "View"))
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = viewMenu

        let editModeItem = viewMenu.addItem(withTitle: String(localized: "Edit (WYSIWYG)"),
                                             action: #selector(ViewModeActions.switchToPreview(_:)),
                                             keyEquivalent: "E")
        editModeItem.keyEquivalentModifierMask = [.command, .shift]

        let markdownModeItem = viewMenu.addItem(withTitle: String(localized: "Markdown Source"),
                                                 action: #selector(ViewModeActions.switchToEditing(_:)),
                                                 keyEquivalent: "M")
        markdownModeItem.keyEquivalentModifierMask = [.command, .shift]

        viewMenu.addItem(NSMenuItem.separator())

        let lineNumbersItem = viewMenu.addItem(
            withTitle: String(localized: "Show Line Numbers"),
            action: #selector(ViewModeActions.toggleLineNumbers(_:)),
            keyEquivalent: ""
        )
        lineNumbersItem.state = AppPreferences.shared.showLineNumbers ? .on : .off

        let wordWrapItem = viewMenu.addItem(
            withTitle: String(localized: "Toggle Word Wrap"),
            action: #selector(ViewModeActions.toggleWordWrap(_:)),
            keyEquivalent: ""
        )
        wordWrapItem.state = AppPreferences.shared.wordWrap ? .on : .off

        viewMenu.addItem(NSMenuItem.separator())

        viewMenu.addItem(withTitle: String(localized: "Increase Font Size"),
                         action: #selector(ViewModeActions.increaseFontSize(_:)),
                         keyEquivalent: "=")

        viewMenu.addItem(withTitle: String(localized: "Decrease Font Size"),
                         action: #selector(ViewModeActions.decreaseFontSize(_:)),
                         keyEquivalent: "-")

        viewMenu.addItem(withTitle: String(localized: "Reset Font Size"),
                         action: #selector(ViewModeActions.resetFontSize(_:)),
                         keyEquivalent: "0")

        viewMenu.addItem(NSMenuItem.separator())

        let fullScreenItem = viewMenu.addItem(
            withTitle: String(localized: "Enter Full Screen"),
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]

        return viewMenuItem
    }

    // MARK: - Window Menu

    private func buildWindowMenu() -> NSMenuItem {
        let windowMenu = NSMenu(title: String(localized: "Window"))
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(withTitle: String(localized: "Minimize"),
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")

        windowMenu.addItem(withTitle: String(localized: "Zoom"),
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")

        windowMenu.addItem(NSMenuItem.separator())

        // Tab navigation
        let nextTabItem = windowMenu.addItem(
            withTitle: String(localized: "Show Next Tab"),
            action: #selector(NSWindow.selectNextTab(_:)),
            keyEquivalent: "\t"
        )
        nextTabItem.keyEquivalentModifierMask = [.control]

        let prevTabItem = windowMenu.addItem(
            withTitle: String(localized: "Show Previous Tab"),
            action: #selector(NSWindow.selectPreviousTab(_:)),
            keyEquivalent: "\t"
        )
        prevTabItem.keyEquivalentModifierMask = [.control, .shift]

        // Hidden items register Ctrl+1–9 shortcuts without cluttering the menu
        for tabNumber in 1...9 {
            let tabItem = windowMenu.addItem(
                withTitle: String(localized: "Tab \(tabNumber)"),
                action: #selector(ViewModeActions.selectTab(_:)),
                keyEquivalent: "\(tabNumber)"
            )
            tabItem.keyEquivalentModifierMask = [.control]
            tabItem.tag = tabNumber
            tabItem.isHidden = true
        }

        windowMenu.addItem(NSMenuItem.separator())

        windowMenu.addItem(withTitle: String(localized: "Bring All to Front"),
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")

        self.windowsMenu = windowMenu

        return windowMenuItem
    }

    // MARK: - Help Menu

    private func buildHelpMenu() -> NSMenuItem {
        let helpMenu = NSMenu(title: String(localized: "Help"))
        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu

        helpMenu.addItem(withTitle: String(localized: "Markdown Editor Help"),
                         action: #selector(NSApplication.showHelp(_:)),
                         keyEquivalent: "?")

        helpMenu.addItem(withTitle: String(localized: "Markdown Syntax Guide"),
                         action: #selector(AppDelegate.openMarkdownSyntaxGuide(_:)),
                         keyEquivalent: "")

        self.helpMenu = helpMenu

        return helpMenuItem
    }
}

// MARK: - View Mode Actions

/// Responder chain actions for view menu items.
@objc protocol ViewModeActions {
    @objc func switchToEditing(_ sender: Any?)
    @objc func switchToPreview(_ sender: Any?)
    @objc func toggleLineNumbers(_ sender: Any?)
    @objc func toggleWordWrap(_ sender: Any?)
    @objc func increaseFontSize(_ sender: Any?)
    @objc func decreaseFontSize(_ sender: Any?)
    @objc func resetFontSize(_ sender: Any?)
    @objc func selectTab(_ sender: Any?)
}

// MARK: - MainWindowController ViewMode Actions

extension MainWindowController: @preconcurrency ViewModeActions {

    @objc func switchToEditing(_ sender: Any?) {
        markdownDocument?.viewMode = .editing
    }

    @objc func switchToPreview(_ sender: Any?) {
        markdownDocument?.viewMode = .preview
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        AppPreferences.shared.showLineNumbers.toggle()
    }

    @objc func toggleWordWrap(_ sender: Any?) {
        AppPreferences.shared.wordWrap.toggle()
    }

    @objc func increaseFontSize(_ sender: Any?) {
        let current = AppPreferences.shared.editorFontSize
        AppPreferences.shared.editorFontSize = min(current + 1, EditorDefaults.maxFontSize)
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        let current = AppPreferences.shared.editorFontSize
        AppPreferences.shared.editorFontSize = max(current - 1, EditorDefaults.minFontSize)
    }

    @objc func resetFontSize(_ sender: Any?) {
        AppPreferences.shared.editorFontSize = EditorDefaults.fontSize
    }

    @objc func selectTab(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else { return }
        let tabIndex = menuItem.tag - 1  // Tags are 1-based
        guard let tabbedWindows = window?.tabbedWindows,
              tabIndex >= 0 && tabIndex < tabbedWindows.count else { return }
        tabbedWindows[tabIndex].makeKeyAndOrderFront(nil)
    }
}
