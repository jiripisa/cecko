import Foundation
import Testing
@testable import CeckoCore

@Suite("CppTokenizer")
struct CppTokenizerTests {

    /// The tokens as (kind, source text) pairs, which reads better in failures.
    private func pairs(_ text: String) -> [(TokenKind, String)] {
        let ns = text as NSString
        return CppTokenizer.tokenize(text).map { ($0.kind, ns.substring(with: $0.range)) }
    }

    @Test("Types, keywords and numbers in a declaration")
    func keywordAndTypeInDeclaration() {
        let p = pairs("int main() { return 0; }")
        #expect(p.count == 3)
        #expect(p[0] == (.type, "int"))
        #expect(p[1] == (.keyword, "return"))
        #expect(p[2] == (.number, "0"))
    }

    @Test("A string with an escaped quote is one token")
    func stringWithEscapedQuote() {
        let p = pairs(#"x = "a\"b";"#)
        #expect(p.count == 1)
        #expect(p[0] == (.string, #""a\"b""#))
    }

    @Test("Line and block comments, block spanning lines")
    func lineAndBlockComments() {
        let p = pairs("// x int\n/* a\n b */ int")
        #expect(p.count == 3)
        #expect(p[0] == (.comment, "// x int"))
        #expect(p[1] == (.comment, "/* a\n b */"))
        #expect(p[2] == (.type, "int"))
    }

    @Test("A preprocessor line is one token")
    func preprocessorLine() {
        let p = pairs("#include <iostream>\nint")
        #expect(p.count == 2)
        #expect(p[0] == (.preprocessor, "#include <iostream>"))
    }

    @Test("Character literals, also escaped")
    func characterLiteral() {
        let p = pairs(#"c = '\n'; d = 'x';"#)
        #expect(p.map(\.0) == [.character, .character])
        #expect(p[0].1 == #"'\n'"#)
    }

    @Test("Floats, hex and exponents are numbers")
    func numbersIncludingFloatsAndHex() {
        let p = pairs("a = 3.14 + 0xFF + 1e5 + 10;")
        #expect(p.map(\.1) == ["3.14", "0xFF", "1e5", "10"])
        #expect(p.allSatisfy { $0.0 == .number })
    }

    @Test("Identifiers that contain keywords are plain")
    func identifiersContainingKeywordsAreNotKeywords() {
        #expect(pairs("integer format x2 returnValue").isEmpty)
    }

    @Test("Ranges are UTF-16 offsets, also after diacritics")
    func utf16RangesWithDiacritics() {
        let tokens = CppTokenizer.tokenize("\"čau\" int")
        #expect(tokens.count == 2)
        #expect(tokens[1].range == NSRange(location: 6, length: 3))
    }

    @Test("An unterminated string ends at the end of the line")
    func unterminatedStringEndsAtLineEnd() {
        let p = pairs("s = \"abc\nint x;")
        #expect(p[0] == (.string, "\"abc"))
        #expect(p[1] == (.type, "int"))
    }

    @Test("std, cout, cin and endl are coloured as types")
    func streamNamesAreTypes() {
        let p = pairs("std::cout << x << std::endl;")
        #expect(p.map(\.1) == ["std", "cout", "std", "endl"])
        #expect(p.allSatisfy { $0.0 == .type })
    }
}
