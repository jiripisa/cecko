import Foundation

/// Text to insert at the caret; `caretOffset` is where the caret ends up,
/// relative to the start of the insertion.
public struct Edit: Equatable, Sendable {
    public let replacement: String
    public let caretOffset: Int

    public init(replacement: String, caretOffset: Int) {
        self.replacement = replacement
        self.caretOffset = caretOffset
    }
}

/// Small typing helpers: auto-indent and bracket pairing. All locations are
/// UTF-16 offsets, as `NSTextView` uses them.
public enum EditorAssist {

    public static let indentUnit = "    "

    /// What Enter inserts at `utf16Location`.
    public static func newline(in text: String, at utf16Location: Int) -> Edit {
        let ns = text as NSString
        let indent = indentation(ofLineContaining: utf16Location, in: ns)
        let before = previousNonSpace(in: ns, before: utf16Location)
        let after = utf16Location < ns.length ? ns.character(at: utf16Location) : nil

        guard before == 123 /* { */ else {
            return Edit(replacement: "\n" + indent, caretOffset: 1 + (indent as NSString).length)
        }
        let inner = indent + indentUnit
        let caret = 1 + (inner as NSString).length
        if after == 125 /* } */ {
            return Edit(replacement: "\n" + inner + "\n" + indent, caretOffset: caret)
        }
        return Edit(replacement: "\n" + inner, caretOffset: caret)
    }

    public static func closingCharacter(for opening: Character) -> Character? {
        switch opening {
        case "(": ")"
        case "[": "]"
        case "{": "}"
        case "\"": "\""
        case "'": "'"
        default: nil
        }
    }

    /// True when typing `ch` should only step over the identical character
    /// already at the caret (the one auto-inserted as a closing pair).
    public static func shouldSkipTyped(_ ch: Character, in text: String, at utf16Location: Int) -> Bool {
        guard [")", "]", "}", "\"", "'"].contains(ch) else { return false }
        let ns = text as NSString
        guard utf16Location < ns.length else { return false }
        return ns.substring(with: NSRange(location: utf16Location, length: 1)) == String(ch)
    }

    /// Typing `}` on a line that holds only whitespace before the caret
    /// replaces that whitespace with one indentation level less plus `}`.
    public static func dedentClosingBrace(in text: String, at utf16Location: Int) -> (range: NSRange, replacement: String)? {
        let ns = text as NSString
        let lineStart = ns.lineRange(for: NSRange(location: min(utf16Location, ns.length), length: 0)).location
        let leading = ns.substring(with: NSRange(location: lineStart, length: utf16Location - lineStart))
        guard !leading.isEmpty, leading.allSatisfy({ $0 == " " || $0 == "\t" }) else { return nil }
        let unit = (indentUnit as NSString).length
        let kept = leading.count >= unit ? String(leading.dropLast(unit)) : ""
        return (NSRange(location: lineStart, length: utf16Location - lineStart), kept + "}")
    }

    private static func indentation(ofLineContaining location: Int, in ns: NSString) -> String {
        let lineStart = ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0)).location
        var end = lineStart
        while end < location, end < ns.length {
            let c = ns.character(at: end)
            guard c == 32 || c == 9 else { break }
            end += 1
        }
        return ns.substring(with: NSRange(location: lineStart, length: end - lineStart))
    }

    private static func previousNonSpace(in ns: NSString, before location: Int) -> unichar? {
        var i = location - 1
        while i >= 0 {
            let c = ns.character(at: i)
            if c == 10 { return nil }
            if c != 32 && c != 9 { return c }
            i -= 1
        }
        return nil
    }
}
