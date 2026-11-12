import Foundation

/// A file or folder under the root folder. `children` is nil for files.
public struct FileNode: Identifiable, Hashable, Sendable {
    public let url: URL
    public let isDirectory: Bool
    public var children: [FileNode]?

    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, isDirectory: Bool, children: [FileNode]?) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
}

public enum FileTree {

    /// Folder names never shown: build output and tool folders.
    static let skippedNames: Set<String> = [".build", "build", "DerivedData", "node_modules"]

    /// Folders macOS shows as single files; their insides are never scanned.
    static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "photoslibrary", "musiclibrary", "xcodeproj",
        "xcworkspace", "playground", "rtfd", "pages", "numbers", "key", "dSYM",
    ]

    /// How many items a scan lists at most; a beginner may pick their whole
    /// home folder, which must not freeze the app.
    public static let defaultLimit = 3000

    /// The contents of `root`, recursively: folders first, then files, each
    /// sorted the way Finder sorts names. Hidden items and build artifacts are
    /// skipped, packages (`.app`, …) are listed but not entered, and the scan
    /// stops after `limit` items.
    public static func scan(_ root: URL, limit: Int = defaultLimit) throws -> [FileNode] {
        var remaining = limit
        return try scan(root, remaining: &remaining)
    }

    private static func scan(_ root: URL, remaining: inout Int) throws -> [FileNode] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles])
        var entries: [(url: URL, isDir: Bool, isPackage: Bool)] = []
        for found in urls {
            // Standardized, so a node equals the same file reached another way
            // (`/private/tmp/…` vs `/tmp/…`).
            let url = found.standardizedFileURL
            let name = url.lastPathComponent
            if skippedNames.contains(name) || name.hasSuffix(".dSYM") { continue }
            let values = try? found.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            let isPackage = values?.isPackage == true
                || packageExtensions.contains(url.pathExtension)
            entries.append((url, values?.isDirectory == true && !isPackage, isPackage))
        }
        entries.sort { a, b in
            if a.isDir != b.isDir { return a.isDir }
            return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
        }
        var nodes: [FileNode] = []
        for entry in entries {
            guard remaining > 0 else { break }
            remaining -= 1
            let children = entry.isDir ? ((try? scan(entry.url, remaining: &remaining)) ?? []) : nil
            nodes.append(FileNode(url: entry.url, isDirectory: entry.isDir, children: children))
        }
        return nodes
    }

    /// Whether a file-system event at `path` can change what the explorer or
    /// the open file shows: not inside hidden folders, build output or packages.
    public static func isRelevantChange(path: String, root: String) -> Bool {
        let base = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(base) else { return path == root }
        let components = path.dropFirst(base.count).split(separator: "/").map(String.init)
        for (i, component) in components.enumerated() {
            if component.hasPrefix(".") || skippedNames.contains(component) { return false }
            let isLast = i == components.count - 1
            if !isLast, packageExtensions.contains((component as NSString).pathExtension) { return false }
        }
        return true
    }
}
