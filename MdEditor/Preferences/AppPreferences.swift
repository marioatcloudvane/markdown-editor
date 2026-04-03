import AppKit
import Observation

/// Singleton observable preferences model backed by UserDefaults.
/// All editor, preview, and general preferences are accessed through this class.
/// Changes are immediately reflected in all open editors and previews.
@Observable
@MainActor
class AppPreferences {

    /// Shared singleton instance
    static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Editor Preferences

    var editorFontFamily: String {
        get { defaults.string(forKey: "editorFontFamily") ?? EditorDefaults.fontFamily }
        set { defaults.set(newValue, forKey: "editorFontFamily") }
    }

    var editorFontSize: CGFloat {
        get { CGFloat(defaults.double(forKey: "editorFontSize").nonZero ?? Double(EditorDefaults.fontSize)) }
        set { defaults.set(Double(newValue), forKey: "editorFontSize") }
    }

    var editorTabWidth: Int {
        get {
            let val = defaults.integer(forKey: "editorTabWidth")
            return val > 0 ? val : EditorDefaults.tabWidth
        }
        set { defaults.set(newValue, forKey: "editorTabWidth") }
    }

    var showLineNumbers: Bool {
        get { defaults.bool(forKey: "showLineNumbers") }
        set { defaults.set(newValue, forKey: "showLineNumbers") }
    }

    var wordWrap: Bool {
        get { defaults.object(forKey: "wordWrap") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "wordWrap") }
    }

    var spellCheck: Bool {
        get { defaults.object(forKey: "spellCheck") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "spellCheck") }
    }

    var autoContinueLists: Bool {
        get { defaults.object(forKey: "autoContinueLists") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoContinueLists") }
    }

    // MARK: - Preview Preferences

    var previewFontSize: CGFloat {
        get { CGFloat(defaults.double(forKey: "previewFontSize").nonZero ?? Double(PreviewDefaults.fontSize)) }
        set { defaults.set(Double(newValue), forKey: "previewFontSize") }
    }

    var codeBlockTheme: String {
        get { defaults.string(forKey: "codeBlockTheme") ?? "auto" }
        set { defaults.set(newValue, forKey: "codeBlockTheme") }
    }

    // MARK: - General Preferences

    var restoreTabsOnLaunch: Bool {
        get { defaults.object(forKey: "restoreTabsOnLaunch") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "restoreTabsOnLaunch") }
    }

    var defaultFileExtension: String {
        get { defaults.string(forKey: "defaultFileExtension") ?? "md" }
        set { defaults.set(newValue, forKey: "defaultFileExtension") }
    }

    var newWindowBehavior: String {
        get { defaults.string(forKey: "newWindowBehavior") ?? "tab" }
        set { defaults.set(newValue, forKey: "newWindowBehavior") }
    }

    // MARK: - Computed Properties

    /// The current editor font based on preferences.
    var editorFont: NSFont {
        let size = editorFontSize
        switch editorFontFamily {
        case "SF Mono":
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case "Menlo":
            return NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case "Fira Code":
            return NSFont(name: "FiraCode-Regular", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case "Source Code Pro":
            return NSFont(name: "SourceCodePro-Regular", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        default:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

// MARK: - Helper

private extension Double {
    /// Returns nil if the value is zero (for UserDefaults default handling).
    var nonZero: Double? {
        return self == 0 ? nil : self
    }
}
