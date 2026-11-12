import Foundation

/// How a source file is stored on disk. Code::Blocks on Czech Windows saves
/// files in Windows-1250, so Cecko reads both that and UTF-8 and writes a file
/// back in the encoding it came in.
public enum SourceEncoding: Equatable, Sendable {
    case utf8
    case utf8WithBOM
    case windows1250
}

public struct DecodedSource: Equatable, Sendable {
    public let text: String
    public let encoding: SourceEncoding

    public init(text: String, encoding: SourceEncoding) {
        self.text = text
        self.encoding = encoding
    }
}

public enum SourceCodec {

    private static let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let windows1250 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.windowsLatin2.rawValue)))

    /// Byte → character for Windows-1250. The five bytes the code page leaves
    /// undefined (0x81, 0x83, 0x88, 0x90, 0x98) map to the control characters
    /// with the same number, so every file round-trips byte for byte.
    private static let decodeTable: [Unicode.Scalar] = (0...255).map { byte in
        if let s = String(data: Data([UInt8(byte)]), encoding: windows1250),
           let scalar = s.unicodeScalars.first, s.unicodeScalars.count == 1 {
            return scalar
        }
        return Unicode.Scalar(UInt8(byte))
    }
    private static let encodeTable: [Unicode.Scalar: UInt8] = Dictionary(
        decodeTable.enumerated().map { ($0.element, UInt8($0.offset)) },
        uniquingKeysWith: { first, _ in first })

    /// Valid UTF-8 (with or without a BOM) is UTF-8; anything else is read as
    /// Windows-1250, where every byte maps to a character (see `decodeTable`).
    public static func decode(_ data: Data) -> DecodedSource {
        if data.starts(with: bom), let text = String(data: data.dropFirst(bom.count), encoding: .utf8) {
            return DecodedSource(text: text, encoding: .utf8WithBOM)
        }
        if let text = String(data: data, encoding: .utf8) {
            return DecodedSource(text: text, encoding: .utf8)
        }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: data.map { decodeTable[Int($0)] })
        return DecodedSource(text: String(scalars), encoding: .windows1250)
    }

    /// Encodes `text` as `encoding`. Text that Windows-1250 cannot represent
    /// (an emoji, say) is written as UTF-8 rather than losing characters.
    public static func encode(_ text: String, as encoding: SourceEncoding) -> Data {
        switch encoding {
        case .utf8:
            return Data(text.utf8)
        case .utf8WithBOM:
            return Data(bom) + Data(text.utf8)
        case .windows1250:
            var bytes: [UInt8] = []
            bytes.reserveCapacity(text.unicodeScalars.count)
            for scalar in text.unicodeScalars {
                guard let byte = encodeTable[scalar] else { return Data(text.utf8) }
                bytes.append(byte)
            }
            return Data(bytes)
        }
    }
}
