import Foundation

public enum ThemeID: String, CaseIterable, Sendable {
    case glass, hacker, synthwave, cyberpunk
}

/// A colour as plain components, so themes can live in the core without AppKit.
public struct RGBA: Equatable, Sendable {
    public let r, g, b, a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// `"#33ff66"` or `"33FF66"`.
    public init(hex: String, alpha: Double = 1) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(digits, radix: 16) ?? 0
        self.init(r: Double((v >> 16) & 0xFF) / 255,
                  g: Double((v >> 8) & 0xFF) / 255,
                  b: Double(v & 0xFF) / 255,
                  a: alpha)
    }

    public func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }
}

public struct SyntaxPalette: Equatable, Sendable {
    public let text, keyword, type, string, character, number, comment, preprocessor, lineNumber: RGBA
}

public struct ThemeColors: Equatable, Sendable {
    /// Alpha 0 means "use the system material" (Glass sidebar).
    public let sidebarBackground: RGBA
    public let editorBackground: RGBA
    /// Second colour of a vertical gradient behind the editor (Synthwave), or nil.
    public let editorGradientEnd: RGBA?
    public let consoleBackground: RGBA
    public let text: RGBA
    public let secondaryText: RGBA
    public let accent: RGBA
    /// Colour of the Run button's label when the button is filled with `accent`.
    public let onAccent: RGBA
    public let selection: RGBA
    public let errorLine: RGBA
    public let errorBubble: RGBA
    public let warningLine: RGBA
    public let warningBubble: RGBA
    public let inputText: RGBA
    public let successText: RGBA
    public let errorText: RGBA
}

public struct ThemeAppearance: Equatable, Sendable {
    public let colors: ThemeColors
    public let syntax: SyntaxPalette
}

/// Everything that makes a theme, as data. The app turns it into SwiftUI and
/// AppKit colours and adds the visual effects.
public struct ThemeData: Sendable {
    public let id: ThemeID
    /// nil = follows the system Light/Dark appearance (Glass).
    public let isDark: Bool?
    public let light: ThemeAppearance
    public let dark: ThemeAppearance
    public let usesMonospacedUI: Bool
    /// Shown after a program finishes normally, instead of the plain message.
    public let successMessage: String?
    public let runLabel: String

    public func appearance(dark systemIsDark: Bool) -> ThemeAppearance {
        (isDark ?? systemIsDark) ? dark : light
    }

    /// The toolbar title for the open file, `relativePath` taken from the root folder.
    public func windowTitle(for relativePath: String) -> String {
        let name = (relativePath as NSString).lastPathComponent
        switch id {
        case .hacker: return "root@cecko:~/" + relativePath
        case .cyberpunk: return "// " + name.uppercased()
        case .glass, .synthwave: return name
        }
    }

    public static func named(_ id: ThemeID) -> ThemeData {
        switch id {
        case .glass: glass
        case .hacker: hacker
        case .synthwave: synthwave
        case .cyberpunk: cyberpunk
        }
    }

    // MARK: - The four themes (colours from the approved mockup)

    static let glass = ThemeData(
        id: .glass, isDark: nil,
        light: ThemeAppearance(
            colors: ThemeColors(
                sidebarBackground: RGBA(hex: "#FFFFFF", alpha: 0),
                editorBackground: RGBA(hex: "#FFFFFF"), editorGradientEnd: nil,
                consoleBackground: RGBA(hex: "#F7F7FA"),
                text: RGBA(hex: "#1D1D1F"), secondaryText: RGBA(hex: "#86868B"),
                accent: RGBA(hex: "#007AFF"), onAccent: RGBA(hex: "#FFFFFF"),
                selection: RGBA(hex: "#B3D7FF"),
                errorLine: RGBA(hex: "#FF3B30", alpha: 0.12), errorBubble: RGBA(hex: "#FF3B30"),
                warningLine: RGBA(hex: "#FFCC00", alpha: 0.18), warningBubble: RGBA(hex: "#C98F00"),
                inputText: RGBA(hex: "#007AFF"), successText: RGBA(hex: "#0A7D2C"),
                errorText: RGBA(hex: "#D70015")),
            syntax: SyntaxPalette(
                text: RGBA(hex: "#1D1D1F"), keyword: RGBA(hex: "#AD3DA4"), type: RGBA(hex: "#703DAA"),
                string: RGBA(hex: "#C41A16"), character: RGBA(hex: "#1C00CF"), number: RGBA(hex: "#1C00CF"),
                comment: RGBA(hex: "#5D6C79"), preprocessor: RGBA(hex: "#78492A"),
                lineNumber: RGBA(hex: "#A0A0A6"))),
        dark: ThemeAppearance(
            colors: ThemeColors(
                sidebarBackground: RGBA(hex: "#000000", alpha: 0),
                editorBackground: RGBA(hex: "#1F1F24"), editorGradientEnd: nil,
                consoleBackground: RGBA(hex: "#18181C"),
                text: RGBA(hex: "#E6E6E6"), secondaryText: RGBA(hex: "#8E8E93"),
                accent: RGBA(hex: "#0A84FF"), onAccent: RGBA(hex: "#FFFFFF"),
                selection: RGBA(hex: "#3F638B"),
                errorLine: RGBA(hex: "#FF453A", alpha: 0.18), errorBubble: RGBA(hex: "#FF453A"),
                warningLine: RGBA(hex: "#FFD60A", alpha: 0.16), warningBubble: RGBA(hex: "#B38F00"),
                inputText: RGBA(hex: "#64D2FF"), successText: RGBA(hex: "#32D74B"),
                errorText: RGBA(hex: "#FF453A")),
            syntax: SyntaxPalette(
                text: RGBA(hex: "#E6E6E6"), keyword: RGBA(hex: "#FF7AB2"), type: RGBA(hex: "#DABAFF"),
                string: RGBA(hex: "#FF8170"), character: RGBA(hex: "#D9C97C"), number: RGBA(hex: "#D9C97C"),
                comment: RGBA(hex: "#7F8C98"), preprocessor: RGBA(hex: "#FD8F3F"),
                lineNumber: RGBA(hex: "#747478"))),
        usesMonospacedUI: false, successMessage: nil, runLabel: "Run")

    static let hacker: ThemeData = {
        let a = ThemeAppearance(
            colors: ThemeColors(
                sidebarBackground: RGBA(hex: "#020802"),
                editorBackground: RGBA(hex: "#020802"), editorGradientEnd: nil,
                consoleBackground: RGBA(hex: "#010501"),
                text: RGBA(hex: "#33FF66"), secondaryText: RGBA(hex: "#1F9E45"),
                accent: RGBA(hex: "#33FF66"), onAccent: RGBA(hex: "#020802"),
                selection: RGBA(hex: "#33FF66", alpha: 0.3),
                errorLine: RGBA(hex: "#FF003C", alpha: 0.18), errorBubble: RGBA(hex: "#FF003C"),
                warningLine: RGBA(hex: "#FFD400", alpha: 0.15), warningBubble: RGBA(hex: "#FFD400"),
                inputText: RGBA(hex: "#FFFFFF"), successText: RGBA(hex: "#33FF66"),
                errorText: RGBA(hex: "#FF003C")),
            syntax: SyntaxPalette(
                text: RGBA(hex: "#33FF66"), keyword: RGBA(hex: "#B6FF00"), type: RGBA(hex: "#B6FF00"),
                string: RGBA(hex: "#00E5FF"), character: RGBA(hex: "#00E5FF"), number: RGBA(hex: "#FFD400"),
                comment: RGBA(hex: "#1F9E45"), preprocessor: RGBA(hex: "#4DFF88", alpha: 0.75),
                lineNumber: RGBA(hex: "#33FF66", alpha: 0.4)))
        return ThemeData(id: .hacker, isDark: true, light: a, dark: a,
                         usesMonospacedUI: true, successMessage: "ACCESS GRANTED_", runLabel: "[ RUN ]")
    }()

    static let synthwave: ThemeData = {
        let a = ThemeAppearance(
            colors: ThemeColors(
                sidebarBackground: RGBA(hex: "#170931"),
                editorBackground: RGBA(hex: "#1B0B3A"), editorGradientEnd: RGBA(hex: "#3D0F4F"),
                consoleBackground: RGBA(hex: "#120726"),
                text: RGBA(hex: "#F3E8FF"), secondaryText: RGBA(hex: "#A08CC8"),
                accent: RGBA(hex: "#FF4FD8"), onAccent: RGBA(hex: "#1B0B3A"),
                selection: RGBA(hex: "#FF4FD8", alpha: 0.3),
                errorLine: RGBA(hex: "#FF3C5A", alpha: 0.2), errorBubble: RGBA(hex: "#FF3C5A"),
                warningLine: RGBA(hex: "#FFD166", alpha: 0.15), warningBubble: RGBA(hex: "#E0A800"),
                inputText: RGBA(hex: "#36F9F6"), successText: RGBA(hex: "#7DFFB2"),
                errorText: RGBA(hex: "#FF3C5A")),
            syntax: SyntaxPalette(
                text: RGBA(hex: "#F3E8FF"), keyword: RGBA(hex: "#FF4FD8"), type: RGBA(hex: "#FF9A3C"),
                string: RGBA(hex: "#36F9F6"), character: RGBA(hex: "#36F9F6"), number: RGBA(hex: "#FFD166"),
                comment: RGBA(hex: "#8A7BB0"), preprocessor: RGBA(hex: "#C792EA"),
                lineNumber: RGBA(hex: "#F3E8FF", alpha: 0.35)))
        return ThemeData(id: .synthwave, isDark: true, light: a, dark: a,
                         usesMonospacedUI: false, successMessage: nil, runLabel: "RUN")
    }()

    static let cyberpunk: ThemeData = {
        let a = ThemeAppearance(
            colors: ThemeColors(
                sidebarBackground: RGBA(hex: "#0B0C10"),
                editorBackground: RGBA(hex: "#0B0C10"), editorGradientEnd: nil,
                consoleBackground: RGBA(hex: "#101118"),
                text: RGBA(hex: "#E6E6E6"), secondaryText: RGBA(hex: "#00F0FF"),
                accent: RGBA(hex: "#FCEE0A"), onAccent: RGBA(hex: "#0B0C10"),
                selection: RGBA(hex: "#00F0FF", alpha: 0.3),
                errorLine: RGBA(hex: "#FF2A6D", alpha: 0.18), errorBubble: RGBA(hex: "#FF2A6D"),
                warningLine: RGBA(hex: "#FCEE0A", alpha: 0.12), warningBubble: RGBA(hex: "#FCEE0A"),
                inputText: RGBA(hex: "#FCEE0A"), successText: RGBA(hex: "#00F0FF"),
                errorText: RGBA(hex: "#FF2A6D")),
            syntax: SyntaxPalette(
                text: RGBA(hex: "#E6E6E6"), keyword: RGBA(hex: "#FCEE0A"), type: RGBA(hex: "#FCEE0A"),
                string: RGBA(hex: "#00F0FF"), character: RGBA(hex: "#00F0FF"), number: RGBA(hex: "#FF2A6D"),
                comment: RGBA(hex: "#5C616B"), preprocessor: RGBA(hex: "#8A8F98"),
                lineNumber: RGBA(hex: "#E6E6E6", alpha: 0.35)))
        return ThemeData(id: .cyberpunk, isDark: true, light: a, dark: a,
                         usesMonospacedUI: false, successMessage: "// MISSION COMPLETE", runLabel: "RUN ▶")
    }()
}
