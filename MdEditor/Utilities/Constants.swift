import AppKit

/// Central repository of layout constants and default configuration values
/// used throughout the application.
enum LayoutConstants {
    /// Minimum horizontal padding from text to window edge
    static let editorHorizontalPadding: CGFloat = 48
    /// Top padding from toolbar/tab area to first line of text
    static let editorTopPadding: CGFloat = 24
    /// Maximum content width for the editing canvas
    static let editorMaxContentWidth: CGFloat = 900
    /// Maximum content width for the rendered preview
    static let previewMaxContentWidth: CGFloat = 680
    /// Default sidebar width
    static let sidebarDefaultWidth: CGFloat = 220
    /// Minimum sidebar width
    static let sidebarMinWidth: CGFloat = 180
    /// Maximum sidebar width
    static let sidebarMaxWidth: CGFloat = 400
    /// Status bar height
    static let statusBarHeight: CGFloat = 22
    /// Cross-dissolve animation duration in seconds
    static let modeTransitionDuration: TimeInterval = 0.15
    /// Total transition time including easing
    static let modeTransitionTotalDuration: TimeInterval = 0.2
    /// Current line highlight alpha
    static let currentLineHighlightAlpha: CGFloat = 0.03
    /// Link color opacity
    static let linkColorOpacity: CGFloat = 0.7
}

enum EditorDefaults {
    /// Default editor font size in points
    static let fontSize: CGFloat = 14
    /// Minimum editor font size
    static let minFontSize: CGFloat = 10
    /// Maximum editor font size
    static let maxFontSize: CGFloat = 32
    /// Default line height multiplier
    static let lineHeightMultiple: CGFloat = 1.6
    /// Default tab width in spaces
    static let tabWidth: Int = 4
    /// Default font family name
    static let fontFamily: String = "SF Mono"
    /// Minimum undo depth
    static let minUndoDepth: Int = 100
}

enum PreviewDefaults {
    /// Default preview body font size
    static let fontSize: CGFloat = 15
    /// Preview line height multiplier
    static let lineHeightMultiple: CGFloat = 1.7
    /// Minimum preview font size
    static let minFontSize: CGFloat = 12
    /// Maximum preview font size
    static let maxFontSize: CGFloat = 28
}

/// Supported file extensions for markdown documents
enum SupportedExtensions {
    /// Extensions recognized when opening individual files
    static let openFile: [String] = ["md", "markdown", "mdown", "mkd", "txt"]
    /// Extensions recognized when scanning folders
    static let folderScan: [String] = ["md", "markdown", "mdown", "mkd"]
    /// Sidebar display extensions
    static let sidebarDisplay: [String] = ["md", "markdown", "txt", "text"]
    /// Extensions for which we hide the extension in tab/sidebar display
    static let hideExtension: Set<String> = ["md"]
}

/// Directories excluded from folder scanning
enum ExcludedDirectories {
    static let names: Set<String> = [
        "node_modules", ".git", "build", "dist", ".venv", "__pycache__"
    ]
}

/// Toolbar item identifiers
extension NSToolbarItem.Identifier {
    static let sidebarToggle = NSToolbarItem.Identifier("sidebarToggle")
    static let bold = NSToolbarItem.Identifier("bold")
    static let italic = NSToolbarItem.Identifier("italic")
    static let strikethrough = NSToolbarItem.Identifier("strikethrough")
    static let link = NSToolbarItem.Identifier("link")
    static let code = NSToolbarItem.Identifier("code")
    static let codeBlock = NSToolbarItem.Identifier("codeBlock")
    static let list = NSToolbarItem.Identifier("list")
    static let bulletList = NSToolbarItem.Identifier("bulletList")
    static let numberedList = NSToolbarItem.Identifier("numberedList")
    static let heading = NSToolbarItem.Identifier("heading")
    static let headingPicker = NSToolbarItem.Identifier("headingPicker")
    static let blockquote = NSToolbarItem.Identifier("blockquote")
    static let overflow = NSToolbarItem.Identifier("overflow")
    static let editPreviewToggle = NSToolbarItem.Identifier("editPreviewToggle")
    static let shareExport = NSToolbarItem.Identifier("shareExport")
    static let formattingGroup = NSToolbarItem.Identifier("formattingGroup")
}
