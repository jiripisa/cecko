import Foundation

public enum TokenKind: Sendable {
    case keyword, type, string, character, number, comment, preprocessor
}

/// A highlighted span. `range` is in UTF-16 offsets, ready for `NSTextView`.
/// Plain text (identifiers, operators, whitespace) produces no token.
public struct Token: Equatable, Sendable {
    public let kind: TokenKind
    public let range: NSRange

    public init(kind: TokenKind, range: NSRange) {
        self.kind = kind
        self.range = range
    }
}

/// A single-pass C++ scanner, good enough for syntax highlighting of
/// beginner programs. It never fails: unknown input is just plain text.
public enum CppTokenizer {

    static let keywords: Set<String> = [
        "alignas", "alignof", "and", "and_eq", "asm", "break", "case", "catch", "class",
        "co_await", "co_return", "co_yield", "concept", "const", "consteval", "constexpr",
        "constinit", "const_cast", "continue", "decltype", "default", "delete", "do",
        "dynamic_cast", "else", "enum", "explicit", "export", "extern", "false", "for",
        "friend", "goto", "if", "inline", "mutable", "namespace", "new", "noexcept", "not",
        "not_eq", "nullptr", "operator", "or", "or_eq", "private", "protected", "public",
        "register", "reinterpret_cast", "requires", "return", "sizeof", "static",
        "static_assert", "static_cast", "struct", "switch", "template", "this",
        "thread_local", "throw", "true", "try", "typedef", "typeid", "typename", "union",
        "using", "virtual", "volatile", "while", "xor", "xor_eq", "NULL",
    ]

    /// Built-in types plus the standard-library names beginners use every day.
    static let types: Set<String> = [
        "auto", "bool", "char", "char8_t", "char16_t", "char32_t", "double", "float", "int",
        "long", "short", "signed", "unsigned", "void", "wchar_t", "size_t",
        "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
        "std", "string", "vector", "array", "map", "unordered_map", "set", "unordered_set",
        "pair", "tuple", "queue", "stack", "deque", "list",
        "cin", "cout", "cerr", "endl", "getline",
    ]

    public static func tokenize(_ text: String) -> [Token] {
        let s = Array(text.utf16)
        let n = s.count
        var tokens: [Token] = []
        var i = 0
        var atLineStart = true   // only whitespace since the last newline

        func add(_ kind: TokenKind, _ start: Int, _ end: Int) {
            tokens.append(Token(kind: kind, range: NSRange(location: start, length: end - start)))
        }
        func lineEnd(from j: Int) -> Int {
            var k = j
            while k < n, s[k] != 10 { k += 1 }
            return k
        }

        while i < n {
            let c = s[i]

            if c == 10 { atLineStart = true; i += 1; continue }
            if c == 32 || c == 9 || c == 13 { i += 1; continue }

            // Preprocessor directive: '#' first on the line, to the line end.
            if c == 35 /* # */ && atLineStart {
                let end = lineEnd(from: i)
                add(.preprocessor, i, end)
                i = end
                continue
            }
            atLineStart = false

            // Comments
            if c == 47 /* / */ && i + 1 < n {
                if s[i + 1] == 47 {
                    let end = lineEnd(from: i)
                    add(.comment, i, end)
                    i = end
                    continue
                }
                if s[i + 1] == 42 /* * */ {
                    var k = i + 2
                    while k + 1 < n, !(s[k] == 42 && s[k + 1] == 47) { k += 1 }
                    let end = min(n, k + 2)
                    add(.comment, i, end)
                    i = end
                    continue
                }
            }

            // String and character literals; unterminated ones stop at the line end.
            if c == 34 /* " */ || c == 39 /* ' */ {
                var k = i + 1
                while k < n, s[k] != c, s[k] != 10 {
                    k += (s[k] == 92 /* \ */ && k + 1 < n && s[k + 1] != 10) ? 2 : 1
                }
                let end = (k < n && s[k] == c) ? k + 1 : k
                add(c == 34 ? .string : .character, i, end)
                i = end
                continue
            }

            // Numbers: digits, or '.' followed by a digit.
            if isDigit(c) || (c == 46 && i + 1 < n && isDigit(s[i + 1])) {
                var k = i + 1
                while k < n {
                    let d = s[k]
                    if isIdentPart(d) || d == 46 || d == 39 /* digit separator */ {
                        k += 1
                    } else if (d == 43 || d == 45), let p = Optional(s[k - 1]),
                              p == 101 || p == 69 || p == 112 || p == 80 /* e E p P */ {
                        k += 1
                    } else {
                        break
                    }
                }
                add(.number, i, k)
                i = k
                continue
            }

            // Identifiers and keywords
            if isIdentStart(c) {
                var k = i + 1
                while k < n, isIdentPart(s[k]) { k += 1 }
                let word = String(utf16CodeUnits: Array(s[i..<k]), count: k - i)
                if keywords.contains(word) {
                    add(.keyword, i, k)
                } else if types.contains(word) {
                    add(.type, i, k)
                }
                i = k
                continue
            }

            i += 1
        }
        return tokens
    }

    private static func isDigit(_ c: UInt16) -> Bool { c >= 48 && c <= 57 }
    private static func isIdentStart(_ c: UInt16) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
    }
    private static func isIdentPart(_ c: UInt16) -> Bool { isIdentStart(c) || isDigit(c) }
}
