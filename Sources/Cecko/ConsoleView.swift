import AppKit
import CeckoCore
import SwiftUI

/// The console under the editor: program output, compile messages, and an
/// input line while a program runs.
struct ConsoleView: View {

    @Environment(\.theme) private var theme
    let run: RunController
    let onJumpToLine: (Int) -> Void

    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ConsoleOutput(buffer: run.console, theme: theme, onJumpToLine: onJumpToLine)
            if run.state == .running {
                inputLine
            }
        }
        .background(ThemedBackground(area: .console))
        .onChange(of: run.state) { _, state in
            if state == .running {
                input = ""
                inputFocused = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(theme.id == .hacker ? "> stdout" : String(localized: "Console").uppercased())
                .font(theme.uiFont(.caption).weight(.semibold))
                .foregroundStyle(theme.colors.secondaryText.color)
            if run.state == .compiling {
                ProgressView().controlSize(.mini)
            }
            Spacer()
            Button {
                run.clearConsole()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.colors.secondaryText.color)
            .disabled(run.state != .idle)
            .help(String(localized: "Clear Console"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var inputLine: some View {
        HStack(spacing: 6) {
            Text(theme.id == .hacker ? "$" : "›")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.colors.inputText.color)
            TextField(String(localized: "Type input for the program and press Enter"), text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.colors.inputText.color)
                .focused($inputFocused)
                .onSubmit {
                    run.send(line: input)
                    input = ""
                    inputFocused = true
                }
                .onKeyPress(characters: ["d"], phases: .down) { press in
                    guard press.modifiers.contains(.control) else { return .ignored }
                    run.sendEOF()
                    return .handled
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(theme.colors.inputText.color.opacity(0.08))
    }
}

/// Read-only, selectable console text; diagnostic lines are links to their line.
private struct ConsoleOutput: NSViewRepresentable {

    let buffer: ConsoleBuffer
    let theme: ThemeContext
    let onJumpToLine: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 4)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onJumpToLine = onJumpToLine
        guard let textView = coordinator.textView, let storage = textView.textStorage else { return }
        guard coordinator.lastSegments != buffer.segments || coordinator.lastTheme != theme.id
                || coordinator.lastBackground != theme.colors.consoleBackground else { return }

        let wasAtBottom = scrollView.documentVisibleRect.maxY >= textView.bounds.maxY - 20
        storage.setAttributedString(attributed(buffer.segments))
        textView.linkTextAttributes = [.cursor: NSCursor.pointingHand]
        coordinator.lastSegments = buffer.segments
        coordinator.lastTheme = theme.id
        coordinator.lastBackground = theme.colors.consoleBackground
        if wasAtBottom { textView.scrollToEndOfDocument(nil) }
    }

    private func attributed(_ segments: [ConsoleSegment]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        let bold = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .semibold)
        let c = theme.colors
        for segment in segments {
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: c.text.nsColor]
            switch segment.kind {
            case .output:
                break
            case .input:
                attrs[.foregroundColor] = c.inputText.nsColor
                attrs[.font] = bold
            case .status:
                attrs[.foregroundColor] = c.secondaryText.nsColor
            case .success:
                attrs[.foregroundColor] = c.successText.nsColor
                attrs[.font] = bold
            case .error:
                attrs[.foregroundColor] = c.errorText.nsColor
                attrs[.font] = bold
            case .diagnostic(let severity, let line):
                attrs[.foregroundColor] = (severity == .error ? c.errorText : c.warningBubble).nsColor
                if let line {
                    attrs[.link] = URL(string: "cecko-line:\(line)")
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    attrs[.underlineColor] = (severity == .error ? c.errorText : c.warningBubble).nsColor.withAlphaComponent(0.4)
                }
            }
            if theme.id == .hacker {
                let shadow = NSShadow()
                shadow.shadowColor = (attrs[.foregroundColor] as? NSColor)?.withAlphaComponent(0.5)
                shadow.shadowBlurRadius = 5
                attrs[.shadow] = shadow
            }
            result.append(NSAttributedString(string: segment.text, attributes: attrs))
        }
        return result
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var onJumpToLine: ((Int) -> Void)?
        var lastSegments: [ConsoleSegment] = []
        var lastTheme: ThemeID?
        var lastBackground: RGBA?

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL, url.scheme == "cecko-line",
                  let line = Int(url.absoluteString.dropFirst("cecko-line:".count)) else { return false }
            onJumpToLine?(line)
            return true
        }
    }
}
