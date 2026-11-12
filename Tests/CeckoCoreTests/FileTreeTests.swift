import Foundation
import Testing
@testable import CeckoCore

/// A fresh temporary directory, removed when the value goes away.
final class TempDir {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cecko-tests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ path: String, _ contents: String = "") -> URL {
        let u = url.appendingPathComponent(path)
        try! FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! contents.write(to: u, atomically: true, encoding: .utf8)
        return u
    }

    @discardableResult
    func folder(_ path: String) -> URL {
        let u = url.appendingPathComponent(path, isDirectory: true)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
}

@Suite("FileTree")
struct FileTreeTests {

    @Test("Folders come first, then files, sorted case-insensitively")
    func foldersFirstThenFilesSorted() throws {
        let dir = TempDir()
        dir.file("b.cpp"); dir.file("A.cpp"); dir.folder("zeta"); dir.folder("Alfa")
        let names = try FileTree.scan(dir.url).map(\.name)
        #expect(names == ["Alfa", "zeta", "A.cpp", "b.cpp"])
    }

    @Test("Hidden files and build artifacts are skipped")
    func hiddenAndBuildArtifactsSkipped() throws {
        let dir = TempDir()
        dir.file(".DS_Store"); dir.folder(".git"); dir.folder(".build"); dir.folder("a.dSYM"); dir.file("a.cpp")
        #expect(try FileTree.scan(dir.url).map(\.name) == ["a.cpp"])
    }

    @Test("Node URLs are standardized, so they equal URLs opened elsewhere")
    func nodeURLsAreStandardized() throws {
        let dir = TempDir()
        dir.file("ukoly/a.cpp")
        let root = URL(fileURLWithPath: "/private" + dir.url.path, isDirectory: true)
        let nodes = try FileTree.scan(root)
        #expect(nodes.allSatisfy { $0.url == $0.url.standardizedFileURL })
        #expect(nodes[0].children?[0].url == dir.url.appendingPathComponent("ukoly/a.cpp").standardizedFileURL)
    }

    @Test("Folders carry their children")
    func nestedChildren() throws {
        let dir = TempDir()
        dir.file("ukoly/du1.cpp"); dir.folder("prazdna")
        let nodes = try FileTree.scan(dir.url)
        let ukoly = try #require(nodes.first { $0.name == "ukoly" })
        #expect(ukoly.isDirectory)
        #expect(ukoly.children?.map(\.name) == ["du1.cpp"])
        #expect(nodes.first { $0.name == "prazdna" }?.children == [])
    }
}

@Suite("FileOperations")
struct FileOperationsTests {

    @Test("A unique name gets a number when the name is taken")
    func uniqueNameAddsNumber() {
        let dir = TempDir()
        #expect(FileOperations.uniqueURL(in: dir.url, baseName: "novy", ext: "cpp").lastPathComponent == "novy.cpp")
        dir.file("novy.cpp")
        #expect(FileOperations.uniqueURL(in: dir.url, baseName: "novy", ext: "cpp").lastPathComponent == "novy 2.cpp")
        dir.file("novy 2.cpp")
        #expect(FileOperations.uniqueURL(in: dir.url, baseName: "novy", ext: "cpp").lastPathComponent == "novy 3.cpp")
        #expect(FileOperations.uniqueURL(in: dir.url, baseName: "slozka", ext: nil).lastPathComponent == "slozka")
    }

    @Test("A new .cpp file starts with the skeleton")
    func newCppFileHasSkeleton() throws {
        let dir = TempDir()
        let url = try FileOperations.createFile(in: dir.url, baseName: "novy")
        #expect(url.lastPathComponent == "novy.cpp")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text == FileOperations.cppSkeleton)
        #expect(text.contains("int main()"))
        #expect(text.contains("#include <iostream>"))
    }

    @Test("A new folder is created with a unique name")
    func newFolderIsCreated() throws {
        let dir = TempDir()
        let url = try FileOperations.createFolder(in: dir.url, baseName: "slozka")
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue)
    }

    @Test("Rename refuses to overwrite an existing file")
    func renameRefusesExistingTarget() throws {
        let dir = TempDir()
        let a = dir.file("a.cpp", "A")
        dir.file("b.cpp", "B")
        #expect(throws: (any Error).self) { try FileOperations.rename(a, to: "b.cpp") }
        let renamed = try FileOperations.rename(a, to: "c.cpp")
        #expect(renamed.lastPathComponent == "c.cpp")
        #expect(try String(contentsOf: renamed, encoding: .utf8) == "A")
    }

    @Test("Runnable and highlighted extensions")
    func runnableExtensions() {
        func u(_ n: String) -> URL { URL(fileURLWithPath: "/tmp/\(n)") }
        #expect(FileOperations.isRunnable(u("a.cpp")))
        #expect(FileOperations.isRunnable(u("a.CPP")))
        #expect(FileOperations.isRunnable(u("a.cc")))
        #expect(FileOperations.isRunnable(u("a.c")))
        #expect(!FileOperations.isRunnable(u("a.h")))
        #expect(FileOperations.isHighlighted(u("a.hpp")))
        #expect(!FileOperations.isHighlighted(u("a.txt")))
    }
}
