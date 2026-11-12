import AppKit
import CeckoCore
import Observation

/// The app's state: the root folder, its file tree, the open file, the
/// theme and the compiler. One per app (there is one window).
@MainActor
@Observable
final class Workspace {

    static let shared = Workspace()

    private(set) var rootURL: URL?
    private(set) var tree: [FileNode] = []
    private(set) var document: EditorDocument?
    /// A file that could not be opened as text.
    private(set) var unreadableFile: URL?
    var selection: URL?
    var themeID: ThemeID {
        didSet { UserDefaults.standard.set(themeID.rawValue, forKey: Keys.theme) }
    }
    private(set) var compilerStatus: CompilerStatus?
    /// A request for the editor to show a line; the id makes repeats distinct.
    private(set) var lineToReveal: (line: Int, id: UUID)?
    /// Changes when the editor should take keyboard focus (a run ended).
    private(set) var editorFocusRequest = UUID()
    private(set) var toolchain: Toolchain?

    let run = RunController()

    @ObservationIgnored private var watcher: FolderWatcher?

    private enum Keys {
        static let root = "rootFolderPath"
        static let theme = "theme"
        static let lastFile = "lastOpenFile"
        static let forceCompilerMissing = "forceCompilerMissing"
    }

    private init() {
        let defaults = UserDefaults.standard
        themeID = defaults.string(forKey: Keys.theme).flatMap(ThemeID.init(rawValue:)) ?? .glass
        toolchain = try? Toolchain(supportDirectory: Self.supportDirectory)
        if let path = defaults.string(forKey: Keys.root) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                setRoot(URL(fileURLWithPath: path, isDirectory: true))
                if let last = defaults.string(forKey: Keys.lastFile),
                   FileManager.default.fileExists(atPath: last) {
                    openFile(URL(fileURLWithPath: last))
                }
            }
        }
        checkCompiler()
    }

    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cecko", isDirectory: true)
    }

    // MARK: Root folder

    func setRoot(_ url: URL) {
        guard canLeaveDocument() else { return }
        let root = url.standardizedFileURL
        rootURL = root
        UserDefaults.standard.set(root.path, forKey: Keys.root)
        if let doc = document, !isInsideRoot(doc.url) { closeDocument() }
        tree = []
        watcher = FolderWatcher(url: root) { [weak self] paths in
            MainActor.assumeIsolated {
                guard let self, let rootPath = self.rootURL?.path else { return }
                // Resolve /private/tmp vs /tmp the same way as the root.
                let relevant = paths.contains {
                    FileTree.isRelevantChange(path: URL(fileURLWithPath: $0).standardizedFileURL.path, root: rootPath)
                }
                if relevant { self.refresh() }
            }
        }
        refresh()
    }

    func chooseRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose the folder where you keep your C++ programs.")
        panel.directoryURL = rootURL
        if panel.runModal() == .OK, let url = panel.url { setRoot(url) }
    }

    /// Opens a file or folder handed to the app (Finder, Dock, `cecko` command).
    /// A file outside the root folder makes its folder the new root.
    func open(_ url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if isDir.boolValue {
            setRoot(url)
            return
        }
        if !isInsideRoot(url) { setRoot(url.deletingLastPathComponent()) }
        openFile(url)
    }

    func isInsideRoot(_ url: URL) -> Bool {
        guard let root = rootURL?.path else { return false }
        return url.standardizedFileURL.path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    func relativePath(of url: URL) -> String {
        guard let root = rootURL, isInsideRoot(url) else { return url.lastPathComponent }
        return String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
    }

    @ObservationIgnored private var scanGeneration = 0

    /// Rescans the tree (off the main thread) and picks up changes to the
    /// open file made elsewhere.
    func refresh() {
        guard let root = rootURL else { return }
        scanGeneration += 1
        let generation = scanGeneration
        Task.detached(priority: .userInitiated) {
            let scanned = (try? FileTree.scan(root)) ?? []
            await MainActor.run {
                let ws = Workspace.shared
                guard ws.scanGeneration == generation, ws.rootURL == root else { return }
                if ws.tree != scanned { ws.tree = scanned }
            }
        }
        if let doc = document {
            if FileManager.default.fileExists(atPath: doc.url.path) {
                doc.reloadIfChangedOnDisk()
            } else {
                closeDocument()
            }
        }
    }

    // MARK: Open file

    func openFile(_ url: URL) {
        let url = url.standardizedFileURL
        guard url != document?.url else { return }
        guard canLeaveDocument() else {
            selection = document?.url
            return
        }
        if let doc = EditorDocument(url: url) {
            document = doc
            unreadableFile = nil
        } else {
            document = nil
            unreadableFile = url
        }
        selection = url
        UserDefaults.standard.set(url.path, forKey: Keys.lastFile)
    }

    func closeDocument() {
        document = nil
        unreadableFile = nil
        selection = nil
        UserDefaults.standard.removeObject(forKey: Keys.lastFile)
    }

    func focusEditor() {
        editorFocusRequest = UUID()
    }

    /// Shows a line of the file the last compile was about, opening that
    /// file first if another one is open.
    func reveal(line: Int) {
        if let file = run.diagnosticsFile, file != document?.url {
            openFile(file)
            guard document?.url == file else { return }
        }
        lineToReveal = (line, UUID())
    }

    /// Saves the open file before it is closed or replaced. When saving fails,
    /// asks whether to stay (and keep the edits) or throw the edits away.
    func canLeaveDocument() -> Bool {
        guard let doc = document, !doc.saveNow() else { return true }
        let alert = NSAlert()
        alert.messageText = String(localized: "“\(doc.url.lastPathComponent)” could not be saved.")
        alert.informativeText = doc.saveError ?? ""
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Keep Editing"))
        alert.addButton(withTitle: String(localized: "Discard Changes"))
        return alert.runModal() == .alertSecondButtonReturn
    }

    // MARK: File operations (explorer)

    /// The folder new items go into: the given folder, or the folder of the
    /// given file, or the root.
    func targetFolder(for url: URL?) -> URL? {
        guard let url else { return rootURL }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue ? url : url.deletingLastPathComponent()
    }

    func newFile(near url: URL?) {
        guard let dir = targetFolder(for: url) else { return }
        if let created = perform({ try FileOperations.createFile(in: dir, baseName: "program") }) {
            refresh()
            openFile(created)
        }
    }

    func newFolder(near url: URL?) {
        guard let dir = targetFolder(for: url) else { return }
        if perform({ try FileOperations.createFolder(in: dir, baseName: String(localized: "New Folder")) }) != nil {
            refresh()
        }
    }

    func rename(_ url: URL, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), trimmed != url.lastPathComponent else { return }
        let wasOpen = document?.url == url.standardizedFileURL
        let openInside = document.map { $0.url.path.hasPrefix(url.path + "/") } ?? false
        if wasOpen || openInside, let doc = document, !doc.saveNow() {
            showError(String(localized: "“\(doc.url.lastPathComponent)” could not be saved.") + " " + (doc.saveError ?? ""))
            return
        }
        if let renamed = perform({ try FileOperations.rename(url, to: trimmed) }) {
            if wasOpen {
                document = nil
                openFile(renamed)
            } else if openInside, let old = document?.url {
                let rest = String(old.path.dropFirst(url.path.count))
                document = nil
                openFile(URL(fileURLWithPath: renamed.path + rest))
            }
            refresh()
        }
    }

    func moveToTrash(_ url: URL) {
        let affectsOpen = document.map { $0.url == url.standardizedFileURL || $0.url.path.hasPrefix(url.path + "/") } ?? false
        // The copy in the Trash gets the last edits too.
        if affectsOpen { document?.saveNow() }
        if perform({ try FileOperations.moveToTrash(url) }) != nil {
            if affectsOpen { closeDocument() }
            refresh()
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func perform<T>(_ action: () throws -> T) -> T? {
        do {
            return try action()
        } catch FileOperationError.alreadyExists(let name) {
            showError(String(localized: "An item named “\(name)” already exists."))
        } catch {
            showError(error.localizedDescription)
        }
        return nil
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: Compiler

    func checkCompiler() {
        if UserDefaults.standard.bool(forKey: Keys.forceCompilerMissing) {
            compilerStatus = .missing
            return
        }
        Task.detached {
            let status = Toolchain.detect()
            await MainActor.run { Workspace.shared.compilerStatus = status }
        }
    }

    var canRun: Bool {
        guard case .available = compilerStatus, toolchain != nil,
              let doc = document, doc.isRunnable else { return false }
        return true
    }

    func runOpenFile() {
        guard canRun, let doc = document, let toolchain else { return }
        guard doc.saveNow() else {
            // Compiling the old file on disk would silently ignore the edits.
            showError(String(localized: "“\(doc.url.lastPathComponent)” could not be saved.") + " " + (doc.saveError ?? ""))
            return
        }
        run.run(file: doc.url, toolchain: toolchain, theme: ThemeData.named(themeID))
    }
}
