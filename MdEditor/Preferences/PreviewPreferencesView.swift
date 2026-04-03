import SwiftUI

/// SwiftUI preferences view for preview-related settings.
struct PreviewPreferencesView: View {
    @State private var preferences = AppPreferences.shared

    private let codeBlockThemes = ["auto", "light", "dark"]
    private let themeLabels: [String: String] = [
        "auto": "Auto (match system)",
        "light": "Light",
        "dark": "Dark"
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(String(localized: "Preview Font Size"))
                    Spacer()
                    Stepper(
                        "\(Int(preferences.previewFontSize)) pt",
                        value: fontSizeBinding,
                        in: Int(PreviewDefaults.minFontSize)...Int(PreviewDefaults.maxFontSize)
                    )
                }

                Picker(String(localized: "Code Block Theme"), selection: themeBinding) {
                    ForEach(codeBlockThemes, id: \.self) { theme in
                        Text(themeLabels[theme] ?? theme).tag(theme)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 500, height: 180)
    }

    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: { Int(preferences.previewFontSize) },
            set: { preferences.previewFontSize = CGFloat($0) }
        )
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { preferences.codeBlockTheme },
            set: { preferences.codeBlockTheme = $0 }
        )
    }
}
