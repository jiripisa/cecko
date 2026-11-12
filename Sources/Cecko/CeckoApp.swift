import AppKit
import CeckoCore
import SwiftUI

@main
struct CeckoApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var updates = UpdateService()
    @State private var workspace = Workspace.shared

    var body: some Scene {
        Window("Cecko", id: "main") {
            ContentView(workspace: workspace)
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            // Auto-update: manual check next to About.
            CommandGroup(after: .appInfo) {
                Button(String(localized: "Check for Updates…")) { updates.checkNow() }
                    .disabled(!updates.canCheck)
                Button(String(localized: "Install “cecko” Command…")) { CommandLineInstaller.install() }
            }
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "New File")) { workspace.newFile(near: workspace.selection) }
                    .keyboardShortcut("n")
                    .disabled(workspace.rootURL == nil)
                Button(String(localized: "New Folder")) { workspace.newFolder(near: workspace.selection) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(workspace.rootURL == nil)
                Divider()
                Button(String(localized: "Change Root Folder…")) { workspace.chooseRootFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button(String(localized: "Save")) { workspace.document?.saveNow() }
                    .keyboardShortcut("s")
                    .disabled(workspace.document == nil)
            }
            TextEditingCommands()
            CommandMenu(String(localized: "Program")) {
                Button(String(localized: "Run")) { workspace.runOpenFile() }
                    .keyboardShortcut("r")
                    .disabled(!workspace.canRun)
                Button(String(localized: "Stop")) { workspace.run.stop() }
                    .keyboardShortcut(".")
                    .disabled(workspace.run.state != .running)
                Divider()
                Button(String(localized: "Clear Console")) { workspace.run.clearConsole() }
                    .keyboardShortcut("k")
            }
            CommandGroup(after: .toolbar) {
                Picker(String(localized: "Theme"), selection: $workspace.themeID) {
                    ForEach(ThemeID.allCases, id: \.self) { id in
                        Text(id.displayName).tag(id)
                    }
                }
                Divider()
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            // A folder wins over files; otherwise open the last file given.
            if let folder = urls.first(where: { $0.hasDirectoryPath }) {
                Workspace.shared.open(folder)
            } else if let file = urls.last {
                Workspace.shared.open(file)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            Workspace.shared.document?.saveNow()
            Workspace.shared.run.stop()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        MainActor.assumeIsolated { _ = Workspace.shared.document?.saveNow() }
    }
}
