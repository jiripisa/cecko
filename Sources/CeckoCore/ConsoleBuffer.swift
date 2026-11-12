import Foundation

public enum ConsoleSegmentKind: Equatable, Sendable {
    /// A compiler message; `line` is the line in the open file it points to,
    /// so the console can jump there (nil: no line, e.g. a linker error).
    case diagnostic(severity: Severity, line: Int?)
    /// What the program printed.
    case output
    /// What the student typed.
    case input
    /// Cecko's own lines ("Compiling…").
    case status
    /// Compile errors, crashes.
    case error
    /// "Program finished".
    case success
}

public struct ConsoleSegment: Equatable, Sendable {
    public var text: String
    public let kind: ConsoleSegmentKind

    public init(text: String, kind: ConsoleSegmentKind) {
        self.text = text
        self.kind = kind
    }
}

/// The console's contents as styled segments. It keeps only the newest
/// `limit` UTF-16 units, so a program printing in an endless loop cannot
/// exhaust memory or freeze the UI.
public struct ConsoleBuffer: Sendable {

    public static let defaultLimit = 200_000

    public let limit: Int
    public private(set) var segments: [ConsoleSegment] = []
    private var length = 0   // total UTF-16 units across segments
    /// UTF-16 units appended since the last clear (kept + trimmed).
    public private(set) var appendedLength = 0
    /// UTF-16 units dropped from the start because of the limit.
    public private(set) var trimmedLength = 0
    /// Changes on every clear, so a view knows to rebuild instead of append.
    public private(set) var generation = 0

    private static let ansi = try! NSRegularExpression(pattern: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]")

    public init(limit: Int = ConsoleBuffer.defaultLimit) {
        self.limit = limit
    }

    public mutating func append(_ text: String, kind: ConsoleSegmentKind) {
        var clean = text.replacingOccurrences(of: "\r\n", with: "\n")
        if clean.contains("\u{1B}") {
            let ns = clean as NSString
            clean = Self.ansi.stringByReplacingMatches(
                in: clean, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        }
        guard !clean.isEmpty else { return }

        if let last = segments.indices.last, segments[last].kind == kind {
            segments[last].text += clean
        } else {
            segments.append(ConsoleSegment(text: clean, kind: kind))
        }
        length += clean.utf16.count
        appendedLength += clean.utf16.count
        trim()
    }

    public mutating func clear() {
        segments.removeAll()
        length = 0
        appendedLength = 0
        trimmedLength = 0
        generation += 1
    }

    /// The text appended after `mark` (an earlier `appendedLength`), as
    /// segments. If that text was already trimmed, returns what is kept.
    public func segments(since mark: Int) -> [ConsoleSegment] {
        var offset = trimmedLength   // absolute offset of segments[0]
        var result: [ConsoleSegment] = []
        for segment in segments {
            let count = segment.text.utf16.count
            defer { offset += count }
            if offset + count <= mark { continue }
            if offset >= mark {
                result.append(segment)
            } else {
                let utf16 = segment.text.utf16
                let cut = utf16.index(utf16.startIndex, offsetBy: mark - offset)
                let start = cut.samePosition(in: segment.text)
                    ?? segment.text.rangeOfComposedCharacterSequence(at: cut).upperBound
                result.append(ConsoleSegment(text: String(segment.text[start...]), kind: segment.kind))
            }
        }
        return result
    }

    public var plainText: String {
        segments.map(\.text).joined()
    }

    private mutating func trim() {
        while length > limit, let first = segments.first {
            let excess = length - limit
            let firstLength = first.text.utf16.count
            if firstLength <= excess {
                segments.removeFirst()
                length -= firstLength
                trimmedLength += firstLength
            } else {
                // Cut at a character boundary at or after `excess` UTF-16 units.
                let text = first.text
                let cut = text.utf16.index(text.utf16.startIndex, offsetBy: excess)
                let start = cut.samePosition(in: text)
                    ?? text.rangeOfComposedCharacterSequence(at: cut).upperBound
                let kept = String(text[start...])
                length -= firstLength - kept.utf16.count
                trimmedLength += firstLength - kept.utf16.count
                segments[0].text = kept
            }
        }
    }
}
