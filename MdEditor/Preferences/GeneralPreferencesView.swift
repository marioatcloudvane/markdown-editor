import SwiftUI

/// SwiftUI preferences view for general application settings.
struct GeneralPreferencesView: View {
    @State private var preferences = AppPreferences.shared

    private let fileExtensions = ["md", "markdown"]
    private let windowBehaviors = ["tab", "window"]
    private let windowBehaviorLabels: [String: String] = [
        "tab": "New Tab",
        "window": "New Window"
    ]

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Restore tabs on launch"), isOn: restoreBinding)

                Picker(String(localized: "Default file extension"), selection: extensionBinding) {
                    ForEach(fileExtensions, id: \.self) { ext in
                        Text(".\(ext)").tag(ext)
                    }
                }

                Picker(String(localized: "New window behavior"), selection: windowBehaviorBinding) {
                    ForEach(windowBehaviors, id: \.self) { behavior in
                        Text(windowBehaviorLabels[behavior] ?? behavior).tag(behavior)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 500, height: 200)
    }

    private var restoreBinding: Binding<Bool> {
        Binding(
            get: { preferences.restoreTabsOnLaunch },
            set: { preferences.restoreTabsOnLaunch = $0 }
        )
    }

    private var extensionBinding: Binding<String> {
        Binding(
            get: { preferences.defaultFileExtension },
            set: { preferences.defaultFileExtension = $0 }
        )
    }

    private var windowBehaviorBinding: Binding<String> {
        Binding(
            get: { preferences.newWindowBehavior },
            set: { preferences.newWindowBehavior = $0 }
        )
    }
}
