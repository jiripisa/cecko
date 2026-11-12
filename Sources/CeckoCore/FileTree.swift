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

    /// The contents of `root`, recursively: folders first, then files, each
    /// sorted the way Finder sorts names. Hidden items and build artifacts are skipped.
    public static func scan(_ root: URL) throws -> [FileNode] {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: root,
                                              includingPropertiesForKeys: [.isDirectoryKey],
                                              options: [.skipsHiddenFiles])
        var nodes: [FileNode] = []
        for url in urls {
            let name = url.lastPathComponent
            if skippedNames.contains(name) || name.hasSuffix(".dSYM") { continue }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let children = isDir ? ((try? scan(url)) ?? []) : nil
            nodes.append(FileNode(url: url, isDirectory: isDir, children: children))
        }
        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}
