import Foundation

/// What inserting a snippet does: replace `range` with `replacement`, then
/// select `selection` (relative to `range.location`): the placeholder to
/// overwrite, such as `condition`.
public struct SnippetEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let selection: NSRange
}

/// A common construct (a for loop, an if-else, …) inserted from the editor's
/// context menu. Templates are indented with four spaces per level; `{{name}}`
/// marks the placeholder that ends up selected.
public struct Snippet: Identifiable, Sendable {

    public enum Group: Sendable { case loops, conditions, other }

    public let id: String
    /// The menu title in English; the app localizes it.
    public let title: String
    public let group: Group
    public let template: String

    /// The snippets for a C++ file, or for a C file (`printf`/`scanf`, no
    /// range-based for).
    public static func all(forC: Bool) -> [Snippet] {
        var list: [Snippet] = [
            Snippet(id: "for", title: "for loop", group: .loops,
                    template: "for (int i = 0; i < {{n}}; i++) {\n    \n}"),
        ]
        if !forC {
            list.append(Snippet(id: "forEach", title: "for loop over all items", group: .loops,
                                template: "for (int x : {{values}}) {\n    \n}"))
        }
        list += [
            Snippet(id: "while", title: "while loop", group: .loops,
                    template: "while ({{condition}}) {\n    \n}"),
            Snippet(id: "doWhile", title: "do-while loop", group: .loops,
                    template: "do {\n    \n} while ({{condition}});"),
            Snippet(id: "if", title: "if", group: .conditions,
                    template: "if ({{condition}}) {\n    \n}"),
            Snippet(id: "ifElse", title: "if-else", group: .conditions,
                    template: "if ({{condition}}) {\n    \n} else {\n    \n}"),
            Snippet(id: "ifElseIf", title: "if – else if – else", group: .conditions,
                    template: "if ({{condition}}) {\n    \n} else if (condition) {\n    \n} else {\n    \n}"),
            Snippet(id: "switch", title: "switch", group: .conditions,
                    template: "switch ({{value}}) {\n    case 1:\n        \n        break;\n    default:\n        \n        break;\n}"),
            Snippet(id: "function", title: "Function", group: .other,
                    template: "int {{name}}(int x) {\n    \n    return 0;\n}"),
            forC
                ? Snippet(id: "read", title: "Read input", group: .other, template: "scanf(\"%d\", &{{x}});")
                : Snippet(id: "read", title: "Read input", group: .other, template: "cin >> {{x}};"),
            forC
                ? Snippet(id: "print", title: "Print output", group: .other, template: "printf(\"%d\\n\", {{x}});")
                : Snippet(id: "print", title: "Print output", group: .other, template: "cout << {{x}} << endl;"),
        ]
        return list
    }

    /// Inserts the snippet in place of `selection` (UTF-16 offsets). Each line
    /// gets the current line's indentation; if the line has other code
    /// before or after the caret, the snippet goes onto lines of its own.
    public func edit(in text: String, selection: NSRange) -> SnippetEdit {
        let ns = text as NSString
        let location = min(selection.location, ns.length)
        let end = min(NSMaxRange(selection), ns.length)
        var lineStart = 0, contentsEnd = 0
        ns.getLineStart(&lineStart, end: nil, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
        let lineEnd = max(contentsEnd, end)
        // The line the selection ends on, for the code after it.
        var endContentsEnd = 0
        ns.getLineStart(nil, end: nil, contentsEnd: &endContentsEnd, for: NSRange(location: end, length: 0))

        let indent = Self.leadingWhitespace(ns.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart)))
        let before = ns.substring(with: NSRange(location: lineStart, length: location - lineStart))
        let after = ns.substring(with: NSRange(location: end, length: max(endContentsEnd, end) - end))

        var start = location
        var stop = end
        var prefix = ""
        var suffix = ""
        if !before.allSatisfy(Self.isSpace) {
            prefix = "\n" + indent
            while start > lineStart, Self.isSpaceUnit(ns.character(at: start - 1)) { start -= 1 }
        }
        if !after.allSatisfy(Self.isSpace) {
            suffix = "\n" + indent
            while stop < ns.length, Self.isSpaceUnit(ns.character(at: stop)) { stop += 1 }
        }

        // Expand the template: indentation and the placeholder.
        let indented = template.replacingOccurrences(of: "\n", with: "\n" + indent)
        let open = (indented as NSString).range(of: "{{")
        let close = (indented as NSString).range(of: "}}")
        let name = (indented as NSString).substring(with: NSRange(location: NSMaxRange(open),
                                                                  length: close.location - NSMaxRange(open)))
        let body = (indented as NSString).replacingCharacters(
            in: NSRange(location: open.location, length: NSMaxRange(close) - open.location), with: name)
        let prefixLength = (prefix as NSString).length

        return SnippetEdit(
            range: NSRange(location: start, length: stop - start),
            replacement: prefix + body + suffix,
            selection: NSRange(location: prefixLength + open.location, length: (name as NSString).length))
    }

    private static func isSpace(_ c: Character) -> Bool { c == " " || c == "\t" }
    private static func isSpaceUnit(_ c: unichar) -> Bool { c == 32 || c == 9 }

    private static func leadingWhitespace(_ line: String) -> String {
        String(line.prefix { isSpace($0) })
    }
}
