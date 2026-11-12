import Foundation

public enum Severity: Sendable {
    case error, warning
}

/// One compiler message. `file`/`line`/`column` are nil for messages without a
/// source location, such as linker errors.
public struct Diagnostic: Equatable, Sendable {
    public let file: String?
    public let line: Int?
    public let column: Int?
    public let severity: Severity
    public let message: String
    public var notes: [String]

    public init(file: String?, line: Int?, column: Int?, severity: Severity,
                message: String, notes: [String] = []) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
        self.notes = notes
    }
}

/// Turns clang's text output (with `-fno-color-diagnostics`) into diagnostics.
/// Source echo, caret lines and "N errors generated." are skipped.
public enum DiagnosticParser {

    private static let located = try! NSRegularExpression(
        pattern: #"^(.+?):(\d+):(\d+): (fatal error|error|warning|note): (.*)$"#)
    private static let driver = try! NSRegularExpression(
        pattern: #"^(?:clang\+\+|clang|c\+\+|g\+\+): (?:fatal error|error): (.*)$"#)

    public static func parse(_ compilerOutput: String) -> [Diagnostic] {
        var result: [Diagnostic] = []
        var pendingLinkerNotes: [String] = []
        var inUndefinedSymbols = false
        var sawLinkerError = false
        var driverErrors: [Diagnostic] = []

        for rawLine in compilerOutput.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let ns = line as NSString
            let whole = NSRange(location: 0, length: ns.length)

            if let m = located.firstMatch(in: line, range: whole) {
                inUndefinedSymbols = false
                let kind = ns.substring(with: m.range(at: 4))
                let message = ns.substring(with: m.range(at: 5))
                if kind == "note" {
                    if !result.isEmpty { result[result.count - 1].notes.append(message) }
                    continue
                }
                result.append(Diagnostic(
                    file: ns.substring(with: m.range(at: 1)),
                    line: Int(ns.substring(with: m.range(at: 2))),
                    column: Int(ns.substring(with: m.range(at: 3))),
                    severity: kind == "warning" ? .warning : .error,
                    message: message))
                continue
            }

            if line.hasPrefix("Undefined symbols") {
                inUndefinedSymbols = true
                pendingLinkerNotes.append(line)
                continue
            }
            if line.hasPrefix("ld: ") {
                inUndefinedSymbols = false
                sawLinkerError = true
                var message = String(line.dropFirst(4))
                if message.hasPrefix("error: ") { message = String(message.dropFirst(7)) }
                result.append(Diagnostic(file: nil, line: nil, column: nil, severity: .error,
                                         message: message, notes: pendingLinkerNotes))
                pendingLinkerNotes = []
                continue
            }
            if inUndefinedSymbols, line.hasPrefix(" ") {
                pendingLinkerNotes.append(line.trimmingCharacters(in: .whitespaces))
                continue
            }
            if let m = driver.firstMatch(in: line, range: whole) {
                driverErrors.append(Diagnostic(file: nil, line: nil, column: nil, severity: .error,
                                               message: ns.substring(with: m.range(at: 1))))
                continue
            }
        }

        // "linker command failed" only repeats an ld error that was already reported.
        if sawLinkerError {
            driverErrors.removeAll { $0.message.hasPrefix("linker command failed") }
        }
        return result + driverErrors
    }
}
