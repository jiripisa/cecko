import Foundation
import Testing
@testable import CeckoCore

private let hasCompiler: Bool = {
    if case .available = Toolchain.detect() { return true }
    return false
}()

@Suite("Toolchain")
struct ToolchainTests {

    @Test("Compile arguments use the C++ standard, warnings and the compat headers")
    func argumentsContainShimAndStandard() throws {
        let dir = TempDir()
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let src = URL(fileURLWithPath: "/tmp/a b/x.cpp")
        let out = URL(fileURLWithPath: "/tmp/out/x")
        let args = toolchain.compileArguments(sources: [src], output: out)
        #expect(args == ["clang++", "-std=gnu++20", "-Wall", "-fno-color-diagnostics",
                         "-isystem", dir.url.appendingPathComponent("include").path,
                         "/tmp/a b/x.cpp", "-o", "/tmp/out/x"])
    }

    @Test("The bits/stdc++.h compatibility header is written")
    func compatHeaderWritten() throws {
        let dir = TempDir()
        _ = try Toolchain(supportDirectory: dir.url)
        let header = dir.url.appendingPathComponent("include/bits/stdc++.h")
        #expect(try String(contentsOf: header, encoding: .utf8) == CompatHeaders.bitsStdcpp)
    }

    @Test("A compiler is detected on this machine", .enabled(if: hasCompiler))
    func detectsCompiler() {
        guard case .available(let version) = Toolchain.detect() else {
            Issue.record("no compiler"); return
        }
        #expect(version.contains("clang"))
    }

    @Test("Hello world compiles and runs", .enabled(if: hasCompiler))
    func compilesHelloWorld() async throws {
        let dir = TempDir()
        let src = dir.file("hello.cpp", "#include <iostream>\nint main() { std::cout << \"Hello\\n\"; }\n")
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let out = try toolchain.makeOutputURL(for: src)
        let result = await toolchain.compile(sources: [src], output: out)
        #expect(result.succeeded)
        #expect(result.diagnostics.isEmpty)

        let r = ProcessRecorder()
        try r.start(PTYProcess(executable: out, currentDirectory: dir.url))
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "Hello\n")
    }

    @Test("A syntax error yields a diagnostic on its line", .enabled(if: hasCompiler))
    func compileErrorProducesDiagnostic() async throws {
        let dir = TempDir()
        let src = dir.file("bad.cpp", "#include <iostream>\nint main() {\n    int a = 1\n    return a;\n}\n")
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let result = await toolchain.compile(sources: [src], output: try toolchain.makeOutputURL(for: src))
        #expect(!result.succeeded)
        let errors = result.diagnostics.filter { $0.severity == .error }
        #expect(errors.count == 1)
        #expect(errors.first?.line == 3)
        #expect(errors.first?.file == src.path)
    }

    @Test("#include <bits/stdc++.h> compiles", .enabled(if: hasCompiler))
    func bitsStdcppCompiles() async throws {
        let dir = TempDir()
        let src = dir.file("gcc.cpp", """
        #include <bits/stdc++.h>
        using namespace std;
        int main() { vector<int> v{3, 1, 2}; sort(v.begin(), v.end()); cout << v[0] << setw(3) << endl; }
        """)
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let result = await toolchain.compile(sources: [src], output: try toolchain.makeOutputURL(for: src))
        #expect(result.succeeded, "\(result.rawOutput)")
    }

    @Test("A file in a path with spaces and diacritics compiles and runs", .enabled(if: hasCompiler))
    func compilesFileInPathWithSpacesAndDiacritics() async throws {
        let dir = TempDir()
        let src = dir.file("Škola/úkol 1.cpp", "#include <cstdio>\nint main() { printf(\"čau\\n\"); }\n")
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let out = try toolchain.makeOutputURL(for: src)
        #expect(out.lastPathComponent == "úkol 1")
        let result = await toolchain.compile(sources: [src], output: out)
        #expect(result.succeeded, "\(result.rawOutput)")

        let r = ProcessRecorder()
        try r.start(PTYProcess(executable: out, currentDirectory: src.deletingLastPathComponent()))
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "čau\n")
    }

    @Test("Program endings map to outcomes")
    func runOutcomeMapsSignals() {
        #expect(RunOutcome(.exited(0), stoppedByUser: false) == .finished)
        #expect(RunOutcome(.exited(2), stoppedByUser: false) == .failed(code: 2))
        #expect(RunOutcome(.signaled(SIGSEGV), stoppedByUser: false) == .crashed(signalName: "segmentation fault"))
        #expect(RunOutcome(.signaled(SIGABRT), stoppedByUser: false) == .crashed(signalName: "abort"))
        #expect(RunOutcome(.signaled(SIGFPE), stoppedByUser: false) == .crashed(signalName: "division by zero"))
        #expect(RunOutcome(.signaled(SIGBUS), stoppedByUser: false) == .crashed(signalName: "bus error"))
        #expect(RunOutcome(.signaled(SIGILL), stoppedByUser: false) == .crashed(signalName: "illegal instruction"))
        #expect(RunOutcome(.signaled(30), stoppedByUser: false) == .crashed(signalName: "signal 30"))
        #expect(RunOutcome(.signaled(SIGTERM), stoppedByUser: true) == .stopped)
        #expect(RunOutcome(.exited(0), stoppedByUser: true) == .finished)
    }
}

@Suite("Toolchain Windows-1250")
struct ToolchainWindows1250Tests {

    @Test("A Windows-1250 file compiles without encoding warnings and prints UTF-8", .enabled(if: hasCompiler))
    func windows1250SourceRunsWithCzechOutput() async throws {
        let dir = TempDir()
        // #include <cstdio>\nint main() { printf("čí\n"); }   with č = E8, í = ED
        var bytes = Array("#include <cstdio>\nint main() { printf(\"".utf8)
        bytes += [0xE8, 0xED]
        bytes += Array("\\n\"); }\n".utf8)
        let src = dir.url.appendingPathComponent("ucitel.cpp")
        try Data(bytes).write(to: src)
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let out = try toolchain.makeOutputURL(for: src)
        let result = await toolchain.compile(sources: [src], output: out)
        #expect(result.succeeded, "\(result.rawOutput)")
        #expect(result.diagnostics.isEmpty, "\(result.rawOutput)")

        let r = ProcessRecorder()
        try r.start(PTYProcess(executable: out, currentDirectory: dir.url))
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "čí\n")
    }

    @Test("Errors in a Windows-1250 file point to the original file and line", .enabled(if: hasCompiler))
    func windows1250DiagnosticsKeepOriginalLocation() async throws {
        let dir = TempDir()
        dir.file("hlavicka.h", "int dvakrat(int x) { return 2 * x; }\n")
        var bytes = Array("#include \"hlavicka.h\"\n// ".utf8) + [0xE8] + Array("\nint main() {\n    int a = dvakrat(1)\n}\n".utf8)
        let src = dir.url.appendingPathComponent("chyba.cpp")
        try Data(bytes).write(to: src)
        bytes = []
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let result = await toolchain.compile(sources: [src], output: try toolchain.makeOutputURL(for: src))
        #expect(!result.succeeded)
        let errors = result.diagnostics.filter { $0.severity == .error }
        #expect(errors.count == 1, "\(result.rawOutput)")
        #expect(errors.first?.file == src.path)
        #expect(errors.first?.line == 4)
    }
}

@Suite("Toolchain C sources")
struct ToolchainCSourceTests {

    @Test("A .c file is compiled by the C compiler as C")
    func cSourceUsesCCompiler() throws {
        let dir = TempDir()
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let args = toolchain.compileArguments(sources: [URL(fileURLWithPath: "/tmp/a.c")],
                                              output: URL(fileURLWithPath: "/tmp/a"))
        #expect(Array(args.prefix(2)) == ["clang", "-std=gnu17"])
    }

    @Test("Valid C that is invalid C++ compiles", .enabled(if: hasCompiler))
    func cOnlyCodeCompiles() async throws {
        let dir = TempDir()
        let src = dir.file("pole.c", "#include <stdlib.h>\n#include <stdio.h>\nint main(void) { int *p = malloc(4 * sizeof(int)); p[0] = 7; printf(\"%d\\n\", p[0]); free(p); return 0; }\n")
        let toolchain = try Toolchain(supportDirectory: dir.url)
        let result = await toolchain.compile(sources: [src], output: try toolchain.makeOutputURL(for: src))
        #expect(result.succeeded, "\(result.rawOutput)")
        #expect(result.diagnostics.isEmpty, "\(result.rawOutput)")
    }
}
