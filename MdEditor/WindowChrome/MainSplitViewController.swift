import AppKit

/// NSSplitViewController containing only the content area.
/// The sidebar has been removed; documents open directly in the editor.
@MainActor
class MainSplitViewController: NSSplitViewController {

    // MARK: - Child View Controllers

    private(set) var contentViewController: ContentViewController!

    private var contentItem: NSSplitViewItem!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        contentViewController = ContentViewController()
        contentItem = NSSplitViewItem(viewController: contentViewController)
        contentItem.minimumThickness = 400

        addSplitViewItem(contentItem)
    }

    // MARK: - Document Management

    /// Sets the document on the content view controller.
    func setDocument(_ document: MarkdownDocument) {
        contentViewController.document = document
    }
}
