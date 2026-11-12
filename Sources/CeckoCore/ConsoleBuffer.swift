import Foundation

public enum ConsoleSegmentKind: Sendable {
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
        trim()
    }

    public mutating func clear() {
        segments.removeAll()
        length = 0
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
            } else {
                // Cut at a character boundary at or after `excess` UTF-16 units.
                let text = first.text
                let cut = text.utf16.index(text.utf16.startIndex, offsetBy: excess)
                let start = cut.samePosition(in: text)
                    ?? text.rangeOfComposedCharacterSequence(at: cut).upperBound
                let kept = String(text[start...])
                length -= firstLength - kept.utf16.count
                segments[0].text = kept
            }
        }
    }
}
