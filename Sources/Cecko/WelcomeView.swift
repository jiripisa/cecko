import AppKit
import SwiftUI

/// Shown until a root folder is chosen.
struct WelcomeView: View {

    @Environment(\.theme) private var theme
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text(theme.id == .hacker ? "> cecko --init" : String(localized: "Welcome to Cecko"))
                .font(theme.uiFont(.largeTitle).weight(.bold))
                .foregroundStyle(theme.isGlass ? Color.primary : theme.colors.text.color)
            Text("Choose the folder where you keep your C++ programs. Cecko shows its files on the left; press Run to compile and start the open program.")
                .font(theme.uiFont(.body))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.isGlass ? Color.secondary : theme.colors.secondaryText.color)
                .frame(maxWidth: 420)
            ThemedActionButton(title: String(localized: "Choose Folder…"), systemImage: "folder") {
                workspace.chooseRootFolder()
            }
            .padding(.top, 6)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemedBackground(area: .editor))
    }
}

/// A prominent button in the theme's style (welcome and compiler screens).
struct ThemedActionButton: View {

    @Environment(\.theme) private var theme
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        if theme.isGlass {
            Button(action: action) {
                Label(title, systemImage: systemImage).padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(ThemedRunButtonStyle(theme: theme))
            .controlSize(.large)
        }
    }
}
