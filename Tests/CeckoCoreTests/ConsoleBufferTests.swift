import Testing
@testable import CeckoCore

@Suite("ConsoleBuffer")
struct ConsoleBufferTests {

    @Test("Consecutive text of the same kind merges into one segment")
    func mergesSameKind() {
        var b = ConsoleBuffer()
        b.append("Zadej ", kind: .output)
        b.append("cislo: ", kind: .output)
        b.append("5\n", kind: .input)
        b.append("ok\n", kind: .output)
        #expect(b.segments == [
            ConsoleSegment(text: "Zadej cislo: ", kind: .output),
            ConsoleSegment(text: "5\n", kind: .input),
            ConsoleSegment(text: "ok\n", kind: .output),
        ])
    }

    @Test("ANSI escape sequences are removed")
    func stripsAnsiEscapes() {
        var b = ConsoleBuffer()
        b.append("\u{1B}[31mred\u{1B}[0m", kind: .output)
        #expect(b.plainText == "red")
    }

    @Test("CRLF becomes LF")
    func crlfBecomesLf() {
        var b = ConsoleBuffer()
        b.append("a\r\nb\r\n", kind: .output)
        #expect(b.plainText == "a\nb\n")
    }

    @Test("The buffer keeps only the newest text beyond its limit")
    func bufferIsCappedAtLimit() {
        var b = ConsoleBuffer(limit: 1000)
        b.append("start ", kind: .status)
        for _ in 0..<3000 { b.append("x", kind: .output) }
        b.append(String(repeating: "y", count: 297_000) + "END", kind: .output)
        #expect(b.plainText.count <= 1000)
        #expect(b.plainText.hasSuffix("END"))
        #expect(!b.plainText.contains("start"))
    }

    @Test("Clear empties the buffer")
    func clearEmpties() {
        var b = ConsoleBuffer()
        b.append("x", kind: .output)
        b.clear()
        #expect(b.segments.isEmpty)
        #expect(b.plainText == "")
    }
}

@Suite("ConsoleBuffer diagnostics")
struct ConsoleBufferDiagnosticTests {

    @Test("Diagnostic lines for different source lines stay separate")
    func diagnosticSegmentsWithDifferentLinesDoNotMerge() {
        var b = ConsoleBuffer()
        b.append("x.cpp:3: a\n", kind: .diagnostic(severity: .error, line: 3))
        b.append("x.cpp:5: b\n", kind: .diagnostic(severity: .error, line: 5))
        b.append("x.cpp:5: c\n", kind: .diagnostic(severity: .warning, line: 5))
        #expect(b.segments.count == 3)
        #expect(b.segments[1].kind == .diagnostic(severity: .error, line: 5))
    }
}
