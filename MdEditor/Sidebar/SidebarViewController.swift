import AppKit

/// View controller hosting the NSOutlineView for the file tree sidebar.
/// Displays the folder structure with disclosure triangles for directories
/// and single-click file opening.
@MainActor
class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    // MARK: - Properties

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var rootNode: FolderNode?

    // MARK: - Lifecycle

    override func loadView() {
        // Visual effect view for sidebar vibrancy
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow

        // Outline view
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.floatsGroupRows = false
        outlineView.indentationPerLevel = 16
        outlineView.autoresizesOutlineColumn = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileTree"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(outlineViewClicked(_:))

        // Scroll view
        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])

        view = visualEffectView

        // Observe active document changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activeDocumentDidChange(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }

    // MARK: - Data Loading

    /// Loads a folder tree into the outline view.
    func loadTree(_ tree: FolderNode) {
        rootNode = tree
        outlineView.reloadData()

        // Expand the root level
        for child in tree.children where child.isFolder {
            outlineView.expandItem(child)
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootNode?.children.count ?? 0
        }
        if let node = item as? FolderNode {
            return node.children.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootNode!.children[index]
        }
        let node = item as! FolderNode
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? FolderNode {
            return node.isFolder
        }
        return false
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FolderNode else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("FileCell")
        let cellView: NSTableCellView

        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = NSTableCellView()
            cellView.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(imageView)
            cellView.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
        }

        cellView.textField?.stringValue = node.name

        if node.isFolder {
            cellView.imageView?.image = NSImage(systemSymbolName: "folder",
                                                 accessibilityDescription: String(localized: "Folder"))
            cellView.imageView?.contentTintColor = .secondaryLabelColor
        } else {
            cellView.imageView?.image = NSImage(systemSymbolName: "doc.text",
                                                 accessibilityDescription: String(localized: "Document"))
            cellView.imageView?.contentTintColor = .tertiaryLabelColor
        }

        return cellView
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }

    // MARK: - Actions

    @objc private func outlineViewClicked(_ sender: Any?) {
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0,
              let node = outlineView.item(atRow: clickedRow) as? FolderNode,
              !node.isFolder else { return }

        // Open the file (or switch to it if already open)
        NSDocumentController.shared.openDocument(
            withContentsOf: node.url,
            display: true
        ) { _, _, _ in }
    }

    @objc private func activeDocumentDidChange(_ notification: Notification) {
        // Highlight the file corresponding to the active document
        guard let document = NSDocumentController.shared.currentDocument as? MarkdownDocument,
              let fileURL = document.fileURL else { return }

        highlightFile(at: fileURL)
    }

    private func highlightFile(at url: URL) {
        guard let root = rootNode else { return }
        if let node = findNode(for: url, in: root) {
            let row = outlineView.row(forItem: node)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
    }

    private func findNode(for url: URL, in node: FolderNode) -> FolderNode? {
        if !node.isFolder && node.url.standardizedFileURL == url.standardizedFileURL {
            return node
        }
        for child in node.children {
            if let found = findNode(for: url, in: child) {
                return found
            }
        }
        return nil
    }
}
