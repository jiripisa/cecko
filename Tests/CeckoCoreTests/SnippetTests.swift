import Foundation
import Testing
@testable import CeckoCore

@Suite("Snippets")
struct SnippetTests {

    private func apply(_ e: SnippetEdit, to text: String) -> (String, String) {
        let ns = NSMutableString(string: text)
        ns.replaceCharacters(in: e.range, with: e.replacement)
        let selected = (ns as NSString).substring(with: NSRange(location: e.range.location + e.selection.location,
                                                                length: e.selection.length))
        return (ns as String, selected)
    }

    @Test("A for loop on an empty indented line keeps the indentation and selects n")
    func forLoopOnEmptyLine() throws {
        let text = "int main() {\n    \n}"
        let snippet = try #require(Snippet.all(forC: false).first { $0.id == "for" })
        let e = snippet.edit(in: text, selection: NSRange(location: 17, length: 0))
        let (result, selected) = apply(e, to: text)
        #expect(result == "int main() {\n    for (int i = 0; i < n; i++) {\n        \n    }\n}")
        #expect(selected == "n")
    }

    @Test("Inserting in the middle of a line moves the construct onto its own lines")
    func insertMidLine() throws {
        let text = "    int a; int b;"
        let snippet = try #require(Snippet.all(forC: false).first { $0.id == "if" })
        let e = snippet.edit(in: text, selection: NSRange(location: 10, length: 0))
        let (result, selected) = apply(e, to: text)
        #expect(result == "    int a;\n    if (condition) {\n        \n    }\n    int b;")
        #expect(selected == "condition")
    }

    @Test("if-else has both branches")
    func ifElse() throws {
        let snippet = try #require(Snippet.all(forC: false).first { $0.id == "ifElse" })
        let (result, _) = apply(snippet.edit(in: "", selection: NSRange(location: 0, length: 0)), to: "")
        #expect(result == "if (condition) {\n    \n} else {\n    \n}")
    }

    @Test("A selection is replaced by the construct")
    func replacesSelection() throws {
        let text = "x\ny"
        let snippet = try #require(Snippet.all(forC: false).first { $0.id == "while" })
        let (result, selected) = apply(snippet.edit(in: text, selection: NSRange(location: 0, length: 1)), to: text)
        #expect(result == "while (condition) {\n    \n}\ny")
        #expect(selected == "condition")
    }

    @Test("Snippet without a placeholder puts the caret inside the body")
    func caretWithoutPlaceholder() throws {
        let snippet = try #require(Snippet.all(forC: false).first { $0.id == "doWhile" })
        let e = snippet.edit(in: "", selection: NSRange(location: 0, length: 0))
        let (result, selected) = apply(e, to: "")
        #expect(result == "do {\n    \n} while (condition);")
        #expect(selected == "condition")
    }

    @Test("C files get printf and scanf instead of cout and cin")
    func cVariants() {
        let c = Snippet.all(forC: true)
        let cpp = Snippet.all(forC: false)
        #expect(c.first { $0.id == "print" }?.template.contains("printf") == true)
        #expect(c.first { $0.id == "read" }?.template.contains("scanf") == true)
        #expect(cpp.first { $0.id == "print" }?.template.contains("cout") == true)
        #expect(cpp.first { $0.id == "read" }?.template.contains("cin") == true)
        #expect(c.allSatisfy { !$0.template.contains("cout") && !$0.template.contains("cin >>") })
    }

    @Test("Every snippet has exactly one placeholder or caret mark")
    func everySnippetHasOneMark() {
        for s in Snippet.all(forC: false) + Snippet.all(forC: true) {
            let marks = s.template.components(separatedBy: "{{").count - 1
            #expect(marks == 1, "\(s.id)")
        }
    }
}

@Suite("Snippets next to emoji")
struct SnippetEmojiTests {
    @Test("Inserting right after an emoji does not crash")
    func afterEmoji() throws {
        let text = "// 😀"
        let snippet = try #require(Snippet.all(forC: false).first { $0.id == "if" })
        let e = snippet.edit(in: text, selection: NSRange(location: (text as NSString).length, length: 0))
        #expect(e.replacement.hasPrefix("\nif ("))
        let e2 = snippet.edit(in: "😀x", selection: NSRange(location: 0, length: 0))
        #expect(e2.replacement.hasSuffix("}\n"))
    }
}
