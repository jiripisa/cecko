import Foundation
import Testing
@testable import CeckoCore

/// Collects a process's output and termination across threads.
final class ProcessRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _output = ""
    private var _termination: Termination?

    var output: String { lock.withLock { _output } }
    var termination: Termination? { lock.withLock { _termination } }

    func start(_ p: PTYProcess) throws {
        try p.start(onOutput: { [self] text in lock.withLock { _output += text } },
                    onExit: { [self] t in lock.withLock { _termination = t } })
    }

    /// Polls `condition` until it holds or `seconds` pass.
    func wait(_ seconds: Double = 5, until condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }
}

@Suite("PTYProcess")
struct PTYProcessTests {

    private func shell(_ script: String) -> PTYProcess {
        PTYProcess(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script],
                   currentDirectory: FileManager.default.temporaryDirectory)
    }

    @Test("Output is captured and a clean exit reported")
    func capturesOutput() async throws {
        let r = ProcessRecorder()
        try r.start(shell("echo ahoj"))
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "ahoj\n")
        #expect(r.termination == .exited(0))
    }

    @Test("A prompt without a newline arrives before the program reads input")
    func promptWithoutNewlineArrivesBeforeInput() async throws {
        let p = shell(#"printf 'a: '; read x; echo "got $x""#)
        let r = ProcessRecorder()
        try r.start(p)
        #expect(await r.wait { r.output == "a: " })
        #expect(r.termination == nil)
        p.send("5\n")
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "a: got 5\n")
    }

    @Test("The program's stdout is a terminal")
    func stdoutIsATerminal() async throws {
        let r = ProcessRecorder()
        try r.start(shell("[ -t 0 ] && [ -t 1 ] && echo tty"))
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "tty\n")
    }

    @Test("A non-zero exit code is reported")
    func exitCodeIsReported() async throws {
        let r = ProcessRecorder()
        try r.start(shell("exit 3"))
        #expect(await r.wait { r.termination != nil })
        #expect(r.termination == .exited(3))
    }

    @Test("Terminate stops an endless loop")
    func terminateKillsRunningProcess() async throws {
        let p = shell("while :; do :; done")
        let r = ProcessRecorder()
        try r.start(p)
        try await Task.sleep(for: .milliseconds(100))
        #expect(p.isRunning)
        p.terminate()
        #expect(await r.wait(2) { r.termination != nil })
        if case .signaled = r.termination {} else { Issue.record("expected a signal, got \(String(describing: r.termination))") }
        #expect(!p.isRunning)
    }

    @Test("Multi-byte characters split across reads are decoded")
    func utf8SplitAcrossReadsIsDecoded() async throws {
        // 'č' is 0xC4 0x8D; print the two bytes separately with a pause between.
        let r = ProcessRecorder()
        try r.start(shell(#"printf '\304'; sleep 0.2; printf '\215\n'"#))
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "č\n")
    }

    @Test("EOF ends a program reading until end of input")
    func eofEndsInput() async throws {
        let p = shell("cat; echo konec")
        let r = ProcessRecorder()
        try r.start(p)
        try await Task.sleep(for: .milliseconds(100))
        p.send("x\n")
        #expect(await r.wait { r.output.contains("x") })
        p.sendEOF()
        #expect(await r.wait { r.termination != nil })
        #expect(r.output == "x\nkonec\n")
    }

    @Test("Input sent after the program ended is ignored safely")
    func sendAfterExitIsIgnored() async throws {
        let p = shell("exit 0")
        let r = ProcessRecorder()
        try r.start(p)
        #expect(await r.wait { r.termination != nil })
        try await Task.sleep(for: .milliseconds(700))   // past the reader's drain timeout
        p.send("late\n")
        p.sendEOF()
        #expect(!p.isRunning)
    }
}
