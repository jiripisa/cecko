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

    /// Valid UTF-8 (with or without a BOM) is UTF-8; anything else is read as
    /// Windows-1250, which maps every byte to a character.
    public static func decode(_ data: Data) -> DecodedSource {
        if data.starts(with: bom), let text = String(data: data.dropFirst(bom.count), encoding: .utf8) {
            return DecodedSource(text: text, encoding: .utf8WithBOM)
        }
        if let text = String(data: data, encoding: .utf8) {
            return DecodedSource(text: text, encoding: .utf8)
        }
        let text = String(data: data, encoding: windows1250)
            ?? String(decoding: data, as: UTF8.self)
        return DecodedSource(text: text, encoding: .windows1250)
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
            return text.data(using: windows1250, allowLossyConversion: false) ?? Data(text.utf8)
        }
    }
}
