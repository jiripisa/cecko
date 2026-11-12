import CeckoCore
import SwiftUI

/// A banner above the editor when no C++ compiler is installed.
struct CompilerMissingView: View {

    @Environment(\.theme) private var theme
    let workspace: Workspace

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hammer.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(theme.colors.errorBubble.color)
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.id == .hacker ? "ERROR: compiler not found" : String(localized: "The C++ compiler is missing"))
                    .font(theme.uiFont(.headline))
                    .foregroundStyle(theme.isGlass ? Color.primary : theme.colors.text.color)
                Text("To run programs, Cecko needs Apple's free developer tools (Command Line Tools). Click Install, confirm the dialog and wait until the download finishes (a few minutes). Then click Check Again.")
                    .font(theme.uiFont(.callout))
                    .foregroundStyle(theme.isGlass ? Color.secondary : theme.colors.secondaryText.color)
                    .lineLimit(4)
                    .frame(maxWidth: 640, alignment: .leading)
                HStack(spacing: 10) {
                    ThemedActionButton(title: String(localized: "Install Developer Tools"), systemImage: "arrow.down.circle") {
                        Toolchain.installCommandLineTools()
                    }
                    Button(String(localized: "Check Again")) { workspace.checkCompiler() }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.errorLine.color)
        .background(theme.colors.editorBackground.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.isGlass ? 14 : 0))
        .padding(10)
    }
}
