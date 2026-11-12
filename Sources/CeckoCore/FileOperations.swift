import Foundation

public enum FileOperationError: Error, Equatable {
    case alreadyExists(String)
}

/// Creating, renaming and deleting files from the explorer.
public enum FileOperations {

    /// What a new `.cpp` file starts with.
    public static let cppSkeleton = """
    #include <iostream>
    using namespace std;

    int main() {

        return 0;
    }

    """

    static let runnableExtensions: Set<String> = ["cpp", "cc", "cxx", "c"]
    static let headerExtensions: Set<String> = ["h", "hpp", "hh", "hxx"]

    /// `baseName.ext` in `dir`, or `baseName 2.ext`, `baseName 3.ext`, … when taken.
    public static func uniqueURL(in dir: URL, baseName: String, ext: String?) -> URL {
        let fm = FileManager.default
        var n = 1
        while true {
            let name = n == 1 ? baseName : "\(baseName) \(n)"
            var url = dir.appendingPathComponent(name)
            if let ext { url = url.appendingPathExtension(ext) }
            if !fm.fileExists(atPath: url.path) { return url }
            n += 1
        }
    }

    /// Creates `baseName.cpp` (or a numbered variant) holding the skeleton.
    public static func createFile(in dir: URL, baseName: String) throws -> URL {
        let url = uniqueURL(in: dir, baseName: baseName, ext: "cpp")
        try Data(cppSkeleton.utf8).write(to: url, options: .withoutOverwriting)
        return url
    }

    public static func createFolder(in dir: URL, baseName: String) throws -> URL {
        let url = uniqueURL(in: dir, baseName: baseName, ext: nil)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    /// Renames within the same folder; never overwrites.
    public static func rename(_ url: URL, to newName: String) throws -> URL {
        let target = url.deletingLastPathComponent().appendingPathComponent(newName)
        // Same name except for case is a valid rename on a case-insensitive disk.
        let caseOnly = target.path.lowercased() == url.path.lowercased()
        if !caseOnly, FileManager.default.fileExists(atPath: target.path) {
            throw FileOperationError.alreadyExists(newName)
        }
        try FileManager.default.moveItem(at: url, to: target)
        return target
    }

    public static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Source files Run can compile on their own.
    public static func isRunnable(_ url: URL) -> Bool {
        runnableExtensions.contains(url.pathExtension.lowercased())
    }

    /// Files that get C++ syntax highlighting.
    public static func isHighlighted(_ url: URL) -> Bool {
        isRunnable(url) || headerExtensions.contains(url.pathExtension.lowercased())
    }
}
