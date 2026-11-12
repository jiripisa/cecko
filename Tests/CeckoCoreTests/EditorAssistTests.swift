import Foundation
import Testing
@testable import CeckoCore

@Suite("EditorAssist")
struct EditorAssistTests {

    @Test("Enter keeps the current line's indentation")
    func newlineKeepsIndentation() {
        let text = "    x;"
        #expect(EditorAssist.newline(in: text, at: 6) == Edit(replacement: "\n    ", caretOffset: 5))
    }

    @Test("Enter after an opening brace indents one level more")
    func newlineAfterBraceIndents() {
        let text = "int main() {"
        #expect(EditorAssist.newline(in: text, at: 12) == Edit(replacement: "\n    ", caretOffset: 5))
    }

    @Test("Enter between braces puts the closing brace on its own line")
    func newlineBetweenBracesSplits() {
        let text = "{}"
        #expect(EditorAssist.newline(in: text, at: 1) == Edit(replacement: "\n    \n", caretOffset: 5))
    }

    @Test("Enter between braces in an indented block keeps the outer indentation")
    func newlineBetweenIndentedBraces() {
        let text = "    if (x) {}"
        #expect(EditorAssist.newline(in: text, at: 12) == Edit(replacement: "\n        \n    ", caretOffset: 9))
    }

    @Test("Opening characters have their closing pair")
    func closingPairs() {
        #expect(EditorAssist.closingCharacter(for: "(") == ")")
        #expect(EditorAssist.closingCharacter(for: "[") == "]")
        #expect(EditorAssist.closingCharacter(for: "{") == "}")
        #expect(EditorAssist.closingCharacter(for: "\"") == "\"")
        #expect(EditorAssist.closingCharacter(for: "'") == "'")
        #expect(EditorAssist.closingCharacter(for: "x") == nil)
    }

    @Test("Typing a closing character in front of the same one just moves on")
    func skipTypedClosingParen() {
        #expect(EditorAssist.shouldSkipTyped(")", in: "f()", at: 2))
        #expect(!EditorAssist.shouldSkipTyped(")", in: "f(", at: 2))
        #expect(EditorAssist.shouldSkipTyped("\"", in: "\"\"", at: 1))
    }

    @Test("Typing } on a whitespace-only line removes one indentation level")
    func dedentClosingBrace() {
        let text = "{\n        "
        let result = EditorAssist.dedentClosingBrace(in: text, at: 10)
        #expect(result?.range == NSRange(location: 2, length: 8))
        #expect(result?.replacement == "    }")
        #expect(EditorAssist.dedentClosingBrace(in: "{\n    x", at: 7) == nil)
    }
}
