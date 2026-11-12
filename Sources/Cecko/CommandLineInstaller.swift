import AppKit
import CeckoCore

/// Installs the `cecko` shell command: the script lives in Application
/// Support, and `/usr/local/bin/cecko` (on the default PATH) links to it.
/// Linking needs an administrator password, asked by macOS.
@MainActor
enum CommandLineInstaller {

    static let linkPath = "/usr/local/bin/" + CommandLineLauncher.commandName

    static func install() {
        do {
            let bin = Workspace.supportDirectory.appendingPathComponent("bin", isDirectory: true)
            try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            let script = bin.appendingPathComponent(CommandLineLauncher.commandName)
            let bundleID = Bundle.main.bundleIdentifier ?? "io.jp4.cecko"
            try Data(CommandLineLauncher.script(bundleIdentifier: bundleID).utf8).write(to: script)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

            let source = """
            do shell script "mkdir -p /usr/local/bin && ln -sf " & quoted form of "\(script.path)" & " \(linkPath)" with administrator privileges
            """
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                // -128: the user cancelled the password dialog.
                if (error[NSAppleScript.errorNumber] as? Int) == -128 { return }
                throw NSError(domain: "Cecko", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"])
            }
            let alert = NSAlert()
            alert.messageText = String(localized: "The “cecko” command is installed")
            alert.informativeText = String(localized: "In Terminal, type “cecko .” to open the current folder in Cecko.")
            alert.runModal()
        } catch {
            Workspace.shared.showError(String(localized: "The command could not be installed: \(error.localizedDescription)"))
        }
    }
}
