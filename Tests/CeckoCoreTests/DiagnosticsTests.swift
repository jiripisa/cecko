import Testing
@testable import CeckoCore

@Suite("Diagnostics")
struct DiagnosticsTests {

    @Test("A clang error with file, line and column")
    func parsesClangError() {
        let d = DiagnosticParser.parse("/tmp/a b/soucet.cpp:7:20: error: expected ';' after expression\n")
        #expect(d.count == 1)
        #expect(d[0].file == "/tmp/a b/soucet.cpp")
        #expect(d[0].line == 7)
        #expect(d[0].column == 20)
        #expect(d[0].severity == .error)
        #expect(d[0].message == "expected ';' after expression")
    }

    @Test("Warnings are parsed as warnings")
    func parsesWarning() {
        let d = DiagnosticParser.parse("x.cpp:3:9: warning: unused variable 'a' [-Wunused-variable]")
        #expect(d.count == 1)
        #expect(d[0].severity == .warning)
        #expect(d[0].message == "unused variable 'a' [-Wunused-variable]")
    }

    @Test("Notes attach to the previous diagnostic and are not counted")
    func notesAreAttachedNotCounted() {
        let output = """
        x.cpp:5:5: error: use of undeclared identifier 'cout'
        x.cpp:1:1: note: did you mean 'std::cout'?
        1 error generated.
        """
        let d = DiagnosticParser.parse(output)
        #expect(d.count == 1)
        #expect(d[0].notes == ["did you mean 'std::cout'?"])
    }

    @Test("A linker error has no location and is reported once")
    func linkerErrorHasNoLocation() {
        let output = """
        Undefined symbols for architecture arm64:
          "_main", referenced from:
              <initial-undefined>
        ld: symbol(s) not found for architecture arm64
        clang++: error: linker command failed with exit code 1 (use -v to see invocation)
        """
        let d = DiagnosticParser.parse(output)
        #expect(d.count == 1)
        #expect(d[0].file == nil)
        #expect(d[0].line == nil)
        #expect(d[0].severity == .error)
        #expect(d[0].message == "symbol(s) not found for architecture arm64")
        #expect(d[0].notes.contains { $0.contains("\"_main\"") })
    }

    @Test("A driver error without a linker error is kept")
    func driverErrorIsKept() {
        let d = DiagnosticParser.parse("clang++: error: no such file or directory: 'a.cpp'")
        #expect(d.count == 1)
        #expect(d[0].file == nil)
        #expect(d[0].message == "no such file or directory: 'a.cpp'")
    }

    @Test("Source echo and caret lines produce nothing")
    func ignoresSourceEchoAndCaretLines() {
        let output = """
        x.cpp:7:20: error: expected ';' after expression
            7 |     cin >> a >> b
              |                  ^
              |                  ;
        In file included from x.cpp:1:
        """
        #expect(DiagnosticParser.parse(output).count == 1)
    }

    @Test("A fatal error is an error")
    func fatalErrorIsError() {
        let d = DiagnosticParser.parse("x.cpp:2:10: fatal error: 'conio.h' file not found")
        #expect(d.count == 1)
        #expect(d[0].severity == .error)
        #expect(d[0].message == "'conio.h' file not found")
    }
}
