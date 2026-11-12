import AppKit
import CeckoCore
import SwiftUI

extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

/// The active theme resolved for the current Light/Dark appearance; what
/// every view reads from the environment.
struct ThemeContext {
    let data: ThemeData
    let appearance: ThemeAppearance

    var id: ThemeID { data.id }
    var colors: ThemeColors { appearance.colors }
    var syntax: SyntaxPalette { appearance.syntax }
    var isGlass: Bool { data.id == .glass }

    /// Font for the app's own labels; Hacker uses monospaced everywhere.
    func uiFont(_ style: Font.TextStyle) -> Font {
        data.usesMonospacedUI ? .system(style, design: .monospaced) : .system(style)
    }

    static let editorFontSize: CGFloat = 13
    static var editorFont: NSFont { .monospacedSystemFont(ofSize: editorFontSize, weight: .regular) }

    static let fallback = ThemeContext(data: .named(.glass), appearance: ThemeData.named(.glass).light)
}

private struct ThemeContextKey: EnvironmentKey {
    static let defaultValue = ThemeContext.fallback
}

extension EnvironmentValues {
    var theme: ThemeContext {
        get { self[ThemeContextKey.self] }
        set { self[ThemeContextKey.self] = newValue }
    }
}

extension ThemeID {
    /// The name shown in menus; theme names are the same in every language.
    var displayName: String {
        switch self {
        case .glass: "Glass"
        case .hacker: "Hacker"
        case .synthwave: "Synthwave"
        case .cyberpunk: "Cyberpunk"
        }
    }

    var symbol: String {
        switch self {
        case .glass: "drop"
        case .hacker: "terminal"
        case .synthwave: "sun.horizon"
        case .cyberpunk: "bolt"
        }
    }
}
