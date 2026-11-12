import Foundation
import Testing
@testable import CeckoCore

@Suite("SourceEncoding")
struct SourceEncodingTests {

    @Test("Valid UTF-8 is detected as UTF-8")
    func utf8Detected() {
        let text = "printf(\"Ahoj světe\");"
        let decoded = SourceCodec.decode(Data(text.utf8))
        #expect(decoded.encoding == .utf8)
        #expect(decoded.text == text)
    }

    @Test("A UTF-8 BOM is stripped and remembered")
    func bomIsStrippedAndRemembered() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("int x;".utf8)
        let decoded = SourceCodec.decode(data)
        #expect(decoded.encoding == .utf8WithBOM)
        #expect(decoded.text == "int x;")
        #expect(SourceCodec.encode(decoded.text, as: decoded.encoding) == data)
    }

    @Test("Bytes that are not UTF-8 are read as Windows-1250")
    func windows1250Detected() {
        let decoded = SourceCodec.decode(Data([0x9A, 0xE8]))
        #expect(decoded.encoding == .windows1250)
        #expect(decoded.text == "šč")
    }

    @Test("A Windows-1250 file saves back byte-identical")
    func windows1250RoundTrip() {
        // "Zadej číslo: " in Windows-1250
        let original = Data([0x5A, 0x61, 0x64, 0x65, 0x6A, 0x20, 0xE8, 0xED, 0x73, 0x6C, 0x6F, 0x3A, 0x20])
        let decoded = SourceCodec.decode(original)
        #expect(decoded.text == "Zadej číslo: ")
        #expect(SourceCodec.encode(decoded.text, as: decoded.encoding) == original)
    }

    @Test("An empty file is UTF-8")
    func emptyFileIsUtf8() {
        let decoded = SourceCodec.decode(Data())
        #expect(decoded.encoding == .utf8)
        #expect(decoded.text == "")
    }

    @Test("Text that Windows-1250 cannot hold is saved as UTF-8")
    func unrepresentableCharacterFallsBackToUtf8() {
        let text = "// 😀 č"
        #expect(SourceCodec.encode(text, as: .windows1250) == Data(text.utf8))
    }
}

@Suite("SourceEncoding undefined bytes")
struct SourceEncodingUndefinedByteTests {

    @Test("Bytes Windows-1250 leaves undefined survive a round trip")
    func undefinedBytesRoundTrip() {
        let original = Data([0x81, 0xE8, 0x83, 0x88, 0x90, 0x98, 0x9A])
        let decoded = SourceCodec.decode(original)
        #expect(decoded.encoding == .windows1250)
        #expect(decoded.text.contains("č"))
        #expect(decoded.text.contains("š"))
        #expect(!decoded.text.contains("\u{FFFD}"))
        #expect(SourceCodec.encode(decoded.text, as: .windows1250) == original)
    }

    @Test("Edited text with an undefined byte still saves in Windows-1250")
    func undefinedByteKeptAfterEdit() {
        let decoded = SourceCodec.decode(Data([0x81, 0x41]))
        let edited = decoded.text + "č"
        #expect(SourceCodec.encode(edited, as: .windows1250) == Data([0x81, 0x41, 0xE8]))
    }
}
