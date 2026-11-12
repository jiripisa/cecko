import CeckoCore
import Foundation
import Observation

/// Run: save → compile → run in the console. Owns the console contents and
/// the compile diagnostics of the last run.
@MainActor
@Observable
final class RunController {

    enum State: Equatable { case idle, compiling, running }

    private(set) var state: State = .idle
    private(set) var console = ConsoleBuffer()
    /// Diagnostics of the last compile, shown in the editor of `diagnosticsFile`.
    private(set) var diagnostics: [Diagnostic] = []
    /// The source file the last compile (and its console links) was about.
    private(set) var diagnosticsFile: URL?

    @ObservationIgnored private var process: PTYProcess?
    @ObservationIgnored private var stopRequested = false
    @ObservationIgnored private var outputDirectory: URL?
    @ObservationIgnored private let pump = OutputPump()
    @ObservationIgnored private var exitWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var runTask: Task<Void, Never>?

    func run(file: URL, toolchain: Toolchain, theme: ThemeData) {
        runTask?.cancel()
        runTask = Task { await performRun(file: file, toolchain: toolchain, theme: theme) }
    }

    func stop() {
        guard state == .running, let process else { return }
        stopRequested = true
        process.terminate()
    }

    /// Sends a line the student typed and echoes it in the console.
    func send(line: String) {
        guard state == .running, let process else { return }
        flushPending()
        console.append(line + "\n", kind: .input)
        process.send(line + "\n")
    }

    func sendEOF() {
        guard state == .running else { return }
        process?.sendEOF()
    }

    func clearConsole() {
        guard state == .idle else { return }
        console.clear()
    }

    func clearDiagnostics() {
        diagnostics = []
    }

    // MARK: -

    private func performRun(file: URL, toolchain: Toolchain, theme: ThemeData) async {
        if state == .running {
            stop()
            await waitForExit()
        }
        guard !Task.isCancelled, state == .idle else { return }

        console.clear()
        diagnostics = []
        diagnosticsFile = file
        state = .compiling
        console.append(String(localized: "Compiling \(file.lastPathComponent)…") + "\n", kind: .status)

        let output: URL
        do {
            output = try toolchain.makeOutputURL(for: file)
        } catch {
            finishCompileFailure(message: error.localizedDescription)
            return
        }
        outputDirectory = output.deletingLastPathComponent()

        let result = await toolchain.compile(sources: [file], output: output)
        diagnostics = result.diagnostics.filter { $0.file == nil || $0.file == file.path }

        if !result.succeeded {
            let errors = result.diagnostics.filter { $0.severity == .error }.count
            console.append(String(localized: "Compilation failed: \(max(errors, 1)) errors") + "\n", kind: .error)
            appendDiagnostics(result.diagnostics, sourcePath: file.path)
            if result.diagnostics.isEmpty {
                console.append(result.rawOutput, kind: .output)
            }
            cleanUp()
            state = .idle
            return
        }

        appendDiagnostics(result.diagnostics, sourcePath: file.path)   // warnings
        console.append("▶ " + String(localized: "Running \(output.lastPathComponent)") + "\n", kind: .status)
        start(output, in: file.deletingLastPathComponent(), theme: theme)
    }

    private func start(_ executable: URL, in directory: URL, theme: ThemeData) {
        let process = PTYProcess(executable: executable, currentDirectory: directory)
        self.process = process
        stopRequested = false
        pump.onFlush = { [weak self] text in self?.console.append(text, kind: .output) }
        do {
            try process.start(
                onOutput: { [pump] text in pump.add(text) },
                onExit: { [weak self] termination in
                    Task { @MainActor in self?.finishRun(termination, theme: theme) }
                })
            state = .running
        } catch {
            console.append(error.localizedDescription + "\n", kind: .error)
            cleanUp()
            state = .idle
        }
    }

    private func finishRun(_ termination: Termination, theme: ThemeData) {
        flushPending()
        let outcome = RunOutcome(termination, stoppedByUser: stopRequested)
        if let text = console.segments.last?.text, !text.hasSuffix("\n") {
            console.append("\n", kind: .output)
        }
        switch outcome {
        case .finished:
            console.append((theme.successMessage ?? "✓ " + String(localized: "Program finished")) + "\n", kind: .success)
        case .failed(let code):
            console.append("✗ " + String(localized: "Program ended with exit code \(Int(code))") + "\n", kind: .error)
        case .crashed(let name):
            console.append("✗ " + String(localized: "Program crashed: \(name)") + "\n", kind: .error)
        case .stopped:
            console.append("■ " + String(localized: "Program stopped") + "\n", kind: .status)
        }
        process = nil
        cleanUp()
        state = .idle
        exitWaiters.forEach { $0.resume() }
        exitWaiters = []
    }

    private func finishCompileFailure(message: String) {
        console.append(message + "\n", kind: .error)
        cleanUp()
        state = .idle
    }

    private func appendDiagnostics(_ list: [Diagnostic], sourcePath: String) {
        for d in list {
            let inSource = d.file == sourcePath
            var location = ""
            if let file = d.file {
                location = (file as NSString).lastPathComponent
                if let line = d.line { location += ", " + String(localized: "line \(line)") }
                location += ": "
            }
            var text = location + d.message + "\n"
            for note in d.notes { text += "    " + note + "\n" }
            console.append(text, kind: .diagnostic(severity: d.severity, line: inSource ? d.line : nil))
        }
    }

    private func flushPending() {
        pump.flushNow()
    }

    private func waitForExit() async {
        guard state == .running else { return }
        await withCheckedContinuation { exitWaiters.append($0) }
    }

    private func cleanUp() {
        if let dir = outputDirectory {
            try? FileManager.default.removeItem(at: dir)
            outputDirectory = nil
        }
    }
}

/// Collects program output from the reader thread and hands it to the main
/// actor at most every 50 ms, so a program printing in a loop can't flood the UI.
private final class OutputPump: @unchecked Sendable {

    private let lock = NSLock()
    private var pending = ""
    private var pendingLength = 0
    private var scheduled = false
    // Set on the main actor before the program starts, read only there.
    nonisolated(unsafe) var onFlush: (@MainActor (String) -> Void)?

    func add(_ text: String) {
        let schedule: Bool = lock.withLock {
            pending += text
            pendingLength += text.utf16.count
            // The console keeps only its newest text anyway; don't pile up more.
            if pendingLength > 2 * ConsoleBuffer.defaultLimit {
                pending = String(pending.suffix(ConsoleBuffer.defaultLimit))
                pendingLength = pending.utf16.count
            }
            if scheduled { return false }
            scheduled = true
            return true
        }
        if schedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
                MainActor.assumeIsolated { flushNow() }
            }
        }
    }

    @MainActor func flushNow() {
        let text: String = lock.withLock {
            defer { pending = ""; pendingLength = 0; scheduled = false }
            return pending
        }
        if !text.isEmpty { onFlush?(text) }
    }
}
