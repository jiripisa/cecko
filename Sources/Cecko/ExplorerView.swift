import CeckoCore
import SwiftUI

/// The sidebar: the root folder's files and folders.
struct ExplorerView: View {

    @Environment(\.theme) private var theme
    @Bindable var workspace: Workspace

    @State private var renaming: URL?
    @State private var newName = ""

    var body: some View {
        List(selection: $workspace.selection) {
            Section {
                OutlineGroup(workspace.tree, children: \.children) { node in
                    row(node)
                }
            } header: {
                Text(header)
                    .font(theme.uiFont(.caption).weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText.color)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(theme.isGlass ? .automatic : .hidden)
        .background(ThemedBackground(area: .sidebar))
        .contextMenu {
            Button(String(localized: "New File")) { workspace.newFile(near: nil) }
            Button(String(localized: "New Folder")) { workspace.newFolder(near: nil) }
        }
        .onChange(of: workspace.selection) { _, url in
            guard let url, !isFolder(url) else { return }
            workspace.openFile(url)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .alert(String(localized: "Rename"), isPresented: Binding(
            get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(String(localized: "Name"), text: $newName)
            Button(String(localized: "Rename")) {
                if let url = renaming { workspace.rename(url, to: newName) }
                renaming = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { renaming = nil }
        }
    }

    private var header: String {
        let name = workspace.rootURL?.lastPathComponent ?? ""
        switch theme.id {
        case .hacker: return "> ls ./" + name
        case .cyberpunk: return "// " + name.uppercased()
        default: return name
        }
    }

    private func row(_ node: FileNode) -> some View {
        Label {
            Text(node.name)
                .font(theme.uiFont(.body))
                .foregroundStyle(theme.isGlass ? Color.primary : theme.colors.text.color)
        } icon: {
            Image(systemName: icon(for: node))
                .foregroundStyle(iconColor(for: node))
        }
        .tag(node.url)
        .contextMenu {
            Button(String(localized: "New File")) { workspace.newFile(near: node.url) }
            Button(String(localized: "New Folder")) { workspace.newFolder(near: node.url) }
            Divider()
            Button(String(localized: "Rename…")) {
                newName = node.name
                renaming = node.url
            }
            Button(String(localized: "Show in Finder")) { workspace.revealInFinder(node.url) }
            Divider()
            Button(String(localized: "Move to Trash"), role: .destructive) { workspace.moveToTrash(node.url) }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 2) {
            Button { workspace.newFile(near: workspace.selection) } label: {
                Image(systemName: "doc.badge.plus")
            }
            .help(String(localized: "New File"))
            Button { workspace.newFolder(near: workspace.selection) } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help(String(localized: "New Folder"))
            Spacer()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(theme.isGlass ? Color.secondary : theme.colors.secondaryText.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func icon(for node: FileNode) -> String {
        if node.isDirectory { return "folder" }
        if FileOperations.isRunnable(node.url) { return "chevron.left.forwardslash.chevron.right" }
        if FileOperations.isHighlighted(node.url) { return "h.square" }
        return "doc"
    }

    private func iconColor(for node: FileNode) -> Color {
        if theme.isGlass { return node.isDirectory ? .accentColor : .secondary }
        return node.isDirectory ? theme.colors.accent.color : theme.colors.secondaryText.color
    }

    private func isFolder(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
