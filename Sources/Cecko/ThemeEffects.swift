import CeckoCore
import SwiftUI

/// Background of a content area (sidebar, editor, console) for the theme,
/// including its effects. Glass returns nothing for the sidebar, so the
/// system's Liquid Glass sidebar shows through.
struct ThemedBackground: View {
    enum Area { case sidebar, editor, console }

    @Environment(\.theme) private var theme
    let area: Area

    var body: some View {
        ZStack {
            base
            if theme.id == .synthwave && area == .sidebar {
                SynthwaveSun()
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var base: some View {
        let c = theme.colors
        switch area {
        case .sidebar:
            if c.sidebarBackground.a > 0 { c.sidebarBackground.color } else { Color.clear }
        case .editor:
            if let end = c.editorGradientEnd {
                LinearGradient(colors: [c.editorBackground.color, end.color], startPoint: .top, endPoint: .bottom)
            } else {
                c.editorBackground.color
            }
        case .console:
            c.consoleBackground.color
        }
    }
}

/// Hacker: thin dark lines like an old CRT monitor, drawn over the content.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                             with: .color(.black.opacity(0.22)))
                y += 3
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Synthwave: a striped retro sun sinking behind the bottom of the sidebar.
struct SynthwaveSun: View {
    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width * 0.8, 180)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3),
                                                  Color(red: 1, green: 0.31, blue: 0.85)],
                                         startPoint: .top, endPoint: .bottom))
                    .mask(
                        VStack(spacing: 0) {
                            ForEach(0..<9) { i in
                                Rectangle().frame(height: d / 9 - CGFloat(i) * 0.9)
                                Spacer().frame(height: CGFloat(i) * 0.9)
                            }
                        }
                    )
                    .frame(width: d, height: d)
                    .shadow(color: Color(red: 1, green: 0.31, blue: 0.85).opacity(0.6), radius: 24)
            }
            .position(x: geo.size.width / 2, y: geo.size.height + d * 0.15)
            .opacity(0.35)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Cyberpunk: a rectangle with the top-right and bottom-left corners cut off.
struct CutCornerShape: Shape {
    var cut: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            p.closeSubpath()
        }
    }
}

extension View {
    /// The theme's frame around a content panel: Cyberpunk cuts corners and
    /// draws a neon border, Hacker adds scanlines, Synthwave a thin neon edge.
    @ViewBuilder
    func themedPanel(_ theme: ThemeContext) -> some View {
        switch theme.id {
        case .cyberpunk:
            self.clipShape(CutCornerShape())
                .overlay(CutCornerShape().stroke(theme.colors.accent.color, lineWidth: 1.5))
        case .hacker:
            self.overlay(Scanlines())
                .overlay(Rectangle().stroke(theme.colors.accent.color.opacity(0.35), lineWidth: 1))
        case .synthwave:
            self.overlay(Rectangle().stroke(theme.colors.accent.color.opacity(0.45), lineWidth: 1))
        case .glass:
            self
        }
    }
}
