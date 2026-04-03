import Foundation

/// Represents the display mode for a document.
/// Each document independently tracks whether it is in editing or preview mode.
enum ViewMode: Int {
    /// Raw markdown editing with syntax highlighting
    case editing = 0
    /// Rendered HTML preview of the markdown content
    case preview = 1

    /// Toggles between editing and preview modes.
    var toggled: ViewMode {
        switch self {
        case .editing: return .preview
        case .preview: return .editing
        }
    }
}
