import SwiftUI

/// SwiftUI preferences view for editor-related settings.
/// Changes are applied immediately to all open editors.
struct EditorPreferencesView: View {
    @State private var preferences = AppPreferences.shared

    private let fontFamilies = ["SF Mono", "Menlo", "Fira Code", "Source Code Pro", "System Monospaced"]
    private let tabWidths = [2, 4, 8]

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Font Family"), selection: fontFamilyBinding) {
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }

                HStack {
                    Text(String(localized: "Font Size"))
                    Spacer()
                    Stepper(
                        "\(Int(preferences.editorFontSize)) pt",
                        value: fontSizeBinding,
                        in: Int(EditorDefaults.minFontSize)...Int(EditorDefaults.maxFontSize)
                    )
                }

                Picker(String(localized: "Tab Width"), selection: tabWidthBinding) {
                    ForEach(tabWidths, id: \.self) { width in
                        Text("\(width) spaces").tag(width)
                    }
                }
            }

            Section {
                Toggle(String(localized: "Show Line Numbers"), isOn: lineNumbersBinding)
                Toggle(String(localized: "Word Wrap"), isOn: wordWrapBinding)
                Toggle(String(localized: "Spell Check"), isOn: spellCheckBinding)
                Toggle(String(localized: "Auto-continue Lists"), isOn: autoListBinding)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 500, height: 340)
    }

    // MARK: - Bindings

    private var fontFamilyBinding: Binding<String> {
        Binding(
            get: { preferences.editorFontFamily },
            set: { preferences.editorFontFamily = $0 }
        )
    }

    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: { Int(preferences.editorFontSize) },
            set: { preferences.editorFontSize = CGFloat($0) }
        )
    }

    private var tabWidthBinding: Binding<Int> {
        Binding(
            get: { preferences.editorTabWidth },
            set: { preferences.editorTabWidth = $0 }
        )
    }

    private var lineNumbersBinding: Binding<Bool> {
        Binding(
            get: { preferences.showLineNumbers },
            set: { preferences.showLineNumbers = $0 }
        )
    }

    private var wordWrapBinding: Binding<Bool> {
        Binding(
            get: { preferences.wordWrap },
            set: { preferences.wordWrap = $0 }
        )
    }

    private var spellCheckBinding: Binding<Bool> {
        Binding(
            get: { preferences.spellCheck },
            set: { preferences.spellCheck = $0 }
        )
    }

    private var autoListBinding: Binding<Bool> {
        Binding(
            get: { preferences.autoContinueLists },
            set: { preferences.autoContinueLists = $0 }
        )
    }
}
