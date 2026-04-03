import SwiftUI

/// SwiftUI view for the status bar at the bottom of the editor window.
/// Displays cursor position, word count, character count, and encoding.
/// In preview mode, only word and character counts are shown.
struct StatusBarView: View {
    var metrics: DocumentMetrics

    var body: some View {
        HStack(spacing: 0) {
            Divider()
                .frame(height: 1)
                .overlay(Color(nsColor: .separatorColor))

            HStack(spacing: 16) {
                if metrics.isEditingMode {
                    Text("Line \(metrics.line), Col \(metrics.column)")
                        .statusBarStyle()
                }

                Spacer()

                Text("\(metrics.wordCount) words")
                    .statusBarStyle()

                Text("\(metrics.characterCount) characters")
                    .statusBarStyle()

                if metrics.isEditingMode {
                    Text("UTF-8")
                        .statusBarStyle()
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: LayoutConstants.statusBarHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    }
}

// MARK: - Style Modifier

extension Text {
    func statusBarStyle() -> some View {
        self
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
    }
}
