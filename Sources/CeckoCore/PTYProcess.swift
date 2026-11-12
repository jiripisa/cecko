import Darwin
import Foundation

public enum Termination: Equatable, Sendable {
    case exited(Int32)
    case signaled(Int32)
}

/// Runs a program attached to a pseudo-terminal, so it behaves exactly as in
/// Terminal: stdout is a tty (line-buffered, prompts without a newline show
/// up at once) and stdin is read line by line.
///
/// Echo is switched off: the console shows what the student typed itself.
/// Output processing is off too, so `\n` arrives as `\n`.
public final class PTYProcess: @unchecked Sendable {

    private let executable: URL
    private let arguments: [String]
    private let currentDirectory: URL

    private let lock = NSLock()
    private var pid: pid_t = 0
    private var masterFD: Int32 = -1
    private var running = false
    private var readSource: DispatchSourceRead?
    private let writeQueue = DispatchQueue(label: "cecko.pty.write")
    private let readQueue = DispatchQueue(label: "cecko.pty.read")
    private var pendingBytes: [UInt8] = []   // an incomplete UTF-8 sequence

    public init(executable: URL, arguments: [String] = [], currentDirectory: URL) {
        self.executable = executable
        self.arguments = arguments
        self.currentDirectory = currentDirectory
    }

    public var isRunning: Bool { lock.withLock { running } }

    /// Starts the program. `onOutput` receives decoded text on a background
    /// queue; `onExit` comes once, after all output was delivered.
    public func start(onOutput: @escaping @Sendable (String) -> Void,
                      onExit: @escaping @Sendable (Termination) -> Void) throws {
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var tio = termios()
        tcgetattr(slave, &tio)
        tio.c_lflag &= ~tcflag_t(ECHO | ECHOE | ECHOK | ECHONL)
        tio.c_oflag &= ~tcflag_t(OPOST)
        tcsetattr(slave, TCSANOW, &tio)

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        for fd in Int32(0)...2 { posix_spawn_file_actions_adddup2(&actions, slave, fd) }
        posix_spawn_file_actions_addchdir(&actions, currentDirectory.path)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "dumb"
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var child: pid_t = 0
        let rc = posix_spawn(&child, executable.path, &actions, &attributes, argv, envp)
        close(slave)
        guard rc == 0 else {
            close(master)
            throw POSIXError(POSIXErrorCode(rawValue: rc) ?? .EIO)
        }

        lock.withLock {
            pid = child
            masterFD = master
            running = true
        }

        let finished = DispatchGroup()
        finished.enter()   // reader reached the end of output
        finished.enter()   // process exited

        let source = DispatchSource.makeReadSource(fileDescriptor: master, queue: readQueue)
        // The handlers hold `self` strongly: a running program keeps its
        // PTYProcess alive until it exits, even if the caller drops it.
        source.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 16 * 1024)
            let n = read(master, &buffer, buffer.count)
            if n > 0 {
                if let text = self.decode(Array(buffer[0..<n])) { onOutput(text) }
            } else {
                source.cancel()
            }
        }
        source.setCancelHandler {
            if let rest = self.flushPending() { onOutput(rest) }
            // No new writes may pick up the descriptor from now on; writes
            // already queued run before the close, so none can hit a reused fd.
            self.lock.withLock {
                self.masterFD = -1
                self.readSource = nil
            }
            self.writeQueue.async { close(master) }
            finished.leave()
        }
        lock.withLock { readSource = source }
        source.resume()

        let exitStatus = ExitStatusBox()
        let spawned = child
        Thread.detachNewThread {
            var status: Int32 = 0
            while waitpid(spawned, &status, 0) == -1 && errno == EINTR {}
            let signal = status & 0x7f
            exitStatus.value = signal == 0 ? .exited((status >> 8) & 0xff) : .signaled(signal)
            self.lock.withLock { self.running = false }
            // A grandchild may keep the terminal open; don't wait for it forever.
            self.readQueue.asyncAfter(deadline: .now() + 0.5) { source.cancel() }
            finished.leave()
        }

        finished.notify(queue: .global()) { onExit(exitStatus.value) }
    }

    /// Sends text to the program's stdin.
    public func send(_ text: String) {
        write(Array(text.utf8))
    }

    /// Ends the program's input (Ctrl+D in a terminal).
    public func sendEOF() {
        write([0x04])
    }

    /// Stops the program: SIGTERM to its process group, SIGKILL if it is
    /// still alive half a second later.
    public func terminate() {
        let target = lock.withLock { running ? pid : 0 }
        guard target > 0 else { return }
        kill(-target, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if self?.isRunning == true { kill(-target, SIGKILL) }
        }
    }

    private func write(_ bytes: [UInt8]) {
        let fd = lock.withLock { masterFD }
        guard fd >= 0 else { return }
        writeQueue.async {
            var offset = 0
            while offset < bytes.count {
                let n = bytes[offset...].withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
                if n <= 0 { if errno == EINTR { continue }; return }
                offset += n
            }
        }
    }

    /// Decodes as much complete UTF-8 as possible; keeps an incomplete
    /// trailing sequence for the next read.
    private func decode(_ bytes: [UInt8]) -> String? {
        var data = pendingBytes + bytes
        var keep = 0
        // Look back at most 3 bytes for the start of an unfinished sequence.
        for back in 1...min(3, data.count) {
            let b = data[data.count - back]
            if b & 0xC0 == 0x80 { continue }          // continuation byte
            if b & 0x80 == 0 { break }                // ASCII: nothing pending
            let needed = b & 0xE0 == 0xC0 ? 2 : b & 0xF0 == 0xE0 ? 3 : b & 0xF8 == 0xF0 ? 4 : 1
            if needed > back { keep = back }
            break
        }
        pendingBytes = Array(data.suffix(keep))
        data.removeLast(keep)
        return data.isEmpty ? nil : String(decoding: data, as: UTF8.self)
    }

    private func flushPending() -> String? {
        defer { pendingBytes = [] }
        return pendingBytes.isEmpty ? nil : String(decoding: pendingBytes, as: UTF8.self)
    }
}

/// The exit status handed from the waiting thread to the exit callback;
/// the dispatch group orders the write before the read.
private final class ExitStatusBox: @unchecked Sendable {
    var value = Termination.exited(0)
}
