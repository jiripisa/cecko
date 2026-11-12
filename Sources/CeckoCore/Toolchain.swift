import Foundation

public enum CompilerStatus: Equatable, Sendable {
    case available(version: String)
    case missing
}

public struct CompileResult: Sendable {
    public let succeeded: Bool
    public let diagnostics: [Diagnostic]
    public let rawOutput: String
}

/// The system C++ compiler (Apple clang from Xcode or the Command Line Tools).
public struct Toolchain: Sendable {

    private let includeDirectory: URL

    /// Writes the compatibility headers into `<supportDirectory>/include`.
    public init(supportDirectory: URL) throws {
        includeDirectory = supportDirectory.appendingPathComponent("include", isDirectory: true)
        let bits = includeDirectory.appendingPathComponent("bits", isDirectory: true)
        try FileManager.default.createDirectory(at: bits, withIntermediateDirectories: true)
        try Data(CompatHeaders.bitsStdcpp.utf8).write(to: bits.appendingPathComponent("stdc++.h"))
    }

    /// Whether a compiler is installed. Never runs `/usr/bin/clang++` or
    /// `xcrun` without developer tools: those shims pop up Apple's installer.
    public static func detect() -> CompilerStatus {
        guard let developerDir = run("/usr/bin/xcode-select", ["-p"]),
              FileManager.default.fileExists(atPath: developerDir.trimmingCharacters(in: .whitespacesAndNewlines)),
              run("/usr/bin/xcrun", ["--find", "clang++"]) != nil,
              let version = run("/usr/bin/xcrun", ["clang++", "--version"])
        else { return .missing }
        return .available(version: version.split(separator: "\n").first.map(String.init) ?? version)
    }

    /// Opens Apple's "install Command Line Developer Tools" dialog.
    public static func installCommandLineTools() {
        _ = run("/usr/bin/xcode-select", ["--install"])
    }

    /// Arguments for `/usr/bin/xcrun`. Takes a list of sources so a future
    /// "folder = one program" mode is an addition, not a rewrite.
    public func compileArguments(sources: [URL], output: URL) -> [String] {
        ["clang++", "-std=gnu++20", "-Wall", "-fno-color-diagnostics",
         "-isystem", includeDirectory.path]
            + sources.map(\.path)
            + ["-o", output.path]
    }

    /// A fresh temporary location for the program built from `source`, named
    /// after it; never inside the student's folder.
    public func makeOutputURL(for source: URL) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cecko-run-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(source.deletingPathExtension().lastPathComponent)
    }

    public func compile(sources: [URL], output: URL) async -> CompileResult {
        let prepared = Self.utf8Sources(for: sources, in: output.deletingLastPathComponent())
        var arguments = compileArguments(sources: prepared.sources, output: output)
        // A converted copy lives elsewhere: keep `#include "x.h"` finding the
        // headers next to the original.
        for dir in prepared.originalDirectories {
            arguments.insert(contentsOf: ["-iquote", dir.path], at: 1)
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                process.arguments = arguments
                process.currentDirectoryURL = sources.first?.deletingLastPathComponent()
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: CompileResult(
                        succeeded: false,
                        diagnostics: [Diagnostic(file: nil, line: nil, column: nil, severity: .error,
                                                 message: error.localizedDescription)],
                        rawOutput: error.localizedDescription))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(decoding: data, as: UTF8.self)
                continuation.resume(returning: CompileResult(
                    succeeded: process.terminationStatus == 0,
                    diagnostics: DiagnosticParser.parse(output),
                    rawOutput: output))
            }
        }
    }

    /// clang reads only UTF-8. A Windows-1250 file (Code::Blocks on Czech
    /// Windows) is compiled from a UTF-8 copy in `directory`; `#line` keeps
    /// errors pointing at the original file and line.
    static func utf8Sources(for sources: [URL], in directory: URL) -> (sources: [URL], originalDirectories: [URL]) {
        var result: [URL] = []
        var directories: [URL] = []
        for source in sources {
            guard let data = try? Data(contentsOf: source) else { result.append(source); continue }
            let decoded = SourceCodec.decode(data)
            guard decoded.encoding == .windows1250 else { result.append(source); continue }
            let copy = directory.appendingPathComponent("utf8-" + source.lastPathComponent)
            let escaped = source.path.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let text = "#line 1 \"\(escaped)\"\n" + decoded.text
            if (try? Data(text.utf8).write(to: copy)) != nil {
                result.append(copy)
                let dir = source.deletingLastPathComponent()
                if !directories.contains(dir) { directories.append(dir) }
            } else {
                result.append(source)
            }
        }
        return (result, directories)
    }

    /// Runs a tool and returns its output, or nil when it fails.
    private static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
