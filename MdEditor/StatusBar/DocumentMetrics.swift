import Foundation
import Observation

/// Observable model holding computed document metrics for the status bar.
/// Updated by the EditorViewController whenever the cursor moves or text changes.
@Observable
@MainActor
class DocumentMetrics {
    /// Current cursor line number (1-based)
    var line: Int = 1
    /// Current cursor column number (1-based)
    var column: Int = 1
    /// Total word count in the document
    var wordCount: Int = 0
    /// Total character count in the document
    var characterCount: Int = 0
    /// Whether the document is in editing mode (shows cursor position)
    var isEditingMode: Bool = true
}
