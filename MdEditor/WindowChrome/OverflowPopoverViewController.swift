import AppKit

/// Popover view controller for the overflow formatting menu.
/// Displays less-common formatting options: Strikethrough, Blockquote,
/// Code Block, Horizontal Rule, Image, and Table.
@MainActor
class OverflowPopoverViewController: NSViewController {

    override func loadView() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let items: [(String, String, String, Selector)] = [
            ("strikethrough", String(localized: "Strikethrough"), "Cmd+Shift+X",
             #selector(FormattingResponder.toggleStrikethrough(_:))),
            ("text.quote", String(localized: "Blockquote"), "Cmd+Shift+.",
             #selector(FormattingResponder.toggleBlockquote(_:))),
            ("curlybraces", String(localized: "Code Block"), "Cmd+Shift+C",
             #selector(FormattingResponder.insertCodeBlock(_:))),
            ("minus", String(localized: "Horizontal Rule"), "Cmd+Shift+-",
             #selector(FormattingResponder.insertHorizontalRule(_:))),
            ("photo", String(localized: "Image"), "Cmd+Shift+I",
             #selector(FormattingResponder.insertImage(_:))),
            ("tablecells", String(localized: "Table"), "Cmd+Option+T",
             #selector(FormattingResponder.insertTable(_:))),
        ]

        for (symbolName, title, shortcut, action) in items {
            let button = makeButton(symbolName: symbolName,
                                    title: title,
                                    shortcut: shortcut,
                                    action: action)
            stackView.addArrangedSubview(button)
        }

        view = stackView
    }

    private func makeButton(symbolName: String,
                            title: String,
                            shortcut: String,
                            action: Selector) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .recessed
        button.isBordered = false
        button.target = nil
        button.action = action
        button.contentTintColor = .labelColor

        let icon = NSImage(systemSymbolName: symbolName,
                          accessibilityDescription: title)
            ?? NSImage(named: NSImage.actionTemplateName)!
        button.image = icon
        button.imagePosition = .imageLeft
        button.title = "  \(title)"
        button.font = NSFont.systemFont(ofSize: 13)
        button.alignment = .left
        button.setAccessibilityLabel(title)

        let shortcutLabel = NSTextField(labelWithString: shortcut)
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.font = NSFont.systemFont(ofSize: 11)
        shortcutLabel.textColor = .secondaryLabelColor

        container.addSubview(button)
        container.addSubview(shortcutLabel)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),

            shortcutLabel.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 16),
            shortcutLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            shortcutLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),

            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])

        return container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 260, height: 220)
    }
}
