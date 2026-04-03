import AppKit
import SwiftUI

/// Window controller for the Preferences panel.
/// Hosts three SwiftUI tabs (Editor, Preview, General) in a standard
/// macOS preferences window with a toolbar-style tab selector.
@MainActor
class PreferencesWindowController: NSWindowController, NSToolbarDelegate {

    /// Shared singleton instance
    static let shared = PreferencesWindowController()

    private enum Tab: String, CaseIterable {
        case editor = "Editor"
        case preview = "Preview"
        case general = "General"

        var toolbarItemIdentifier: NSToolbarItem.Identifier {
            return NSToolbarItem.Identifier("preferences.\(rawValue)")
        }

        var icon: String {
            switch self {
            case .editor: return "square.and.pencil"
            case .preview: return "eye"
            case .general: return "gearshape"
            }
        }

        var localizedTitle: String {
            switch self {
            case .editor: return String(localized: "Editor")
            case .preview: return String(localized: "Preview")
            case .general: return String(localized: "General")
            }
        }
    }

    private var currentTab: Tab = .editor

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        self.init(window: window)
        window.title = String(localized: "Preferences")
        window.center()
        window.isReleasedWhenClosed = false

        // Set up toolbar
        let toolbar = NSToolbar(identifier: "PreferencesToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.selectedItemIdentifier = Tab.editor.toolbarItemIdentifier
        window.toolbar = toolbar

        switchToTab(.editor)
    }

    // MARK: - Tab Switching

    private func switchToTab(_ tab: Tab) {
        currentTab = tab
        window?.toolbar?.selectedItemIdentifier = tab.toolbarItemIdentifier
        window?.title = tab.localizedTitle

        let contentView: NSView
        switch tab {
        case .editor:
            contentView = NSHostingView(rootView: EditorPreferencesView())
        case .preview:
            contentView = NSHostingView(rootView: PreviewPreferencesView())
        case .general:
            contentView = NSHostingView(rootView: GeneralPreferencesView())
        }

        // Animate size change
        let newSize = contentView.fittingSize
        let frameSize = NSSize(width: max(500, newSize.width), height: max(200, newSize.height))

        guard let window = window else { return }

        var frame = window.frame
        let oldHeight = frame.height
        frame.size.height = frameSize.height + (window.frame.height - (window.contentView?.frame.height ?? 0))
        frame.size.width = frameSize.width
        frame.origin.y += oldHeight - frame.height

        window.setFrame(frame, display: true, animate: true)
        window.contentView = contentView
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return Tab.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return Tab.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return Tab.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = Tab.allCases.first(where: { $0.toolbarItemIdentifier == itemIdentifier }) else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.localizedTitle
        item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.localizedTitle)
        item.target = self
        item.action = #selector(toolbarTabClicked(_:))
        item.tag = Tab.allCases.firstIndex(of: tab) ?? 0
        return item
    }

    @objc private func toolbarTabClicked(_ sender: NSToolbarItem) {
        let tab = Tab.allCases[sender.tag]
        switchToTab(tab)
    }
}
