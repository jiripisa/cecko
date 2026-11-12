import AppKit
import CeckoCore
import SwiftUI

/// The main window: explorer | editor over console, Run in the toolbar.
struct ContentView: View {

    @Bindable var workspace: Workspace
    @Environment(\.colorScheme) private var colorScheme

    private var theme: ThemeContext {
        let data = ThemeData.named(workspace.themeID)
        return ThemeContext(data: data, appearance: data.appearance(dark: colorScheme == .dark))
    }

    var body: some View {
        Group {
            if workspace.rootURL == nil {
                WelcomeView(workspace: workspace)
            } else {
                NavigationSplitView {
                    ExplorerView(workspace: workspace)
                        .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 380)
                } detail: {
                    detail
                }
            }
        }
        .fontDesign(theme.data.usesMonospacedUI ? .monospaced : .default)
        .tint(theme.isGlass ? nil : theme.colors.accent.color)
        .preferredColorScheme(theme.data.isDark == true ? .dark : nil)
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .toolbar { toolbar }
        // Last, so the toolbar items get the theme too.
        .environment(\.theme, theme)
        .frame(minWidth: 820, minHeight: 520)
    }

    private var title: String {
        guard let doc = workspace.document else { return "Cecko" }
        return theme.data.windowTitle(for: workspace.relativePath(of: doc.url))
    }

    private var subtitle: String {
        theme.id == .glass ? (workspace.rootURL?.lastPathComponent ?? "") : ""
    }

    private var detail: some View {
        EditorConsoleSplit {
            VStack(spacing: 0) {
                if workspace.compilerStatus == .missing {
                    CompilerMissingView(workspace: workspace)
                }
                editorArea
            }
        } console: {
            ConsoleView(run: workspace.run) { workspace.reveal(line: $0) }
                .themedPanel(theme)
        }
        .background(ThemedBackground(area: .editor))
    }

    @ViewBuilder private var editorArea: some View {
        if let doc = workspace.document {
            CodeEditor(document: doc, theme: theme, diagnostics: workspace.run.diagnostics,
                       lineToReveal: workspace.lineToReveal) { workspace.run.clearDiagnostics() }
                .background(ThemedBackground(area: .editor))
                .themedPanel(theme)
                .id(ObjectIdentifier(doc))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: workspace.unreadableFile == nil ? "chevron.left.forwardslash.chevron.right" : "doc.questionmark")
                .font(.system(size: 40))
            if let file = workspace.unreadableFile {
                Text("“\(file.lastPathComponent)” is not a text file.")
            } else {
                Text("Choose a file on the left, or create a new one.")
                ThemedActionButton(title: String(localized: "New File"), systemImage: "doc.badge.plus") {
                    workspace.newFile(near: nil)
                }
                .padding(.top, 6)
            }
        }
        .font(theme.uiFont(.body))
        .foregroundStyle(theme.isGlass ? Color.secondary : theme.colors.secondaryText.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemedBackground(area: .editor))
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker(String(localized: "Theme"), selection: $workspace.themeID) {
                    ForEach(ThemeID.allCases, id: \.self) { id in
                        Label(id.displayName, systemImage: id.symbol).tag(id)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(String(localized: "Theme"), systemImage: "paintpalette")
            }
            .help(String(localized: "Theme"))
        }
        if workspace.rootURL != nil {
            ToolbarItem(placement: .primaryAction) {
                RunButton(workspace: workspace)
            }
            .sharedBackgroundVisibility(theme.isGlass ? .automatic : .hidden)
        }
    }
}

/// Run, or Stop while a program runs, in the theme's style.
struct RunButton: View {

    @Environment(\.theme) private var theme
    let workspace: Workspace

    var body: some View {
        let run = workspace.run
        let isRunning = run.state == .running
        let label = isRunning ? "Stop" : theme.data.runLabel
        let image = isRunning ? "stop.fill" : "play.fill"
        Group {
            if theme.isGlass {
                Button {
                    isRunning ? run.stop() : workspace.runOpenFile()
                } label: {
                    Label(label, systemImage: image).labelStyle(.titleAndIcon)
                }
                .buttonStyle(.glassProminent)
                .tint(isRunning ? .red : .green)
            } else {
                Button {
                    isRunning ? run.stop() : workspace.runOpenFile()
                } label: {
                    Label(isRunning && theme.id == .hacker ? "[ STOP ]" : label, systemImage: image)
                }
                .buttonStyle(ThemedRunButtonStyle(theme: theme, danger: isRunning))
            }
        }
        .disabled(!isRunning && (!workspace.canRun || run.state == .compiling))
        .help(helpText)
    }

    private var helpText: String {
        if workspace.compilerStatus == .missing { return String(localized: "Install the C++ compiler first.") }
        if workspace.document?.isRunnable == false { return String(localized: "Only C and C++ source files can be run.") }
        return workspace.run.state == .running ? String(localized: "Stop the program (⌘.)") : String(localized: "Compile and run (⌘R)")
    }
}

/// The Run button of the dark themes.
struct ThemedRunButtonStyle: ButtonStyle {

    let theme: ThemeContext
    var danger = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let c = theme.colors
        let fill = danger ? c.errorBubble.color : c.accent.color
        let pressed = configuration.isPressed
        return Group {
            switch theme.id {
            case .hacker:
                configuration.label
                    .labelStyle(.titleOnly)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(pressed ? c.onAccent.color : fill)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(pressed ? fill : Color.clear)
                    .overlay(Rectangle().stroke(fill, lineWidth: 1))
                    .shadow(color: fill.opacity(0.7), radius: 6)
            case .synthwave:
                configuration.label
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(c.onAccent.color)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Capsule().fill(danger ? AnyShapeStyle(fill)
                        : AnyShapeStyle(LinearGradient(colors: [c.accent.color, Color(red: 1, green: 0.6, blue: 0.24)],
                                                       startPoint: .leading, endPoint: .trailing))))
                    .shadow(color: fill.opacity(pressed ? 0.3 : 0.8), radius: 10)
            case .cyberpunk:
                configuration.label
                    .labelStyle(.titleOnly)
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(c.onAccent.color)
                    .padding(.horizontal, 16).padding(.vertical, 5)
                    .background(Parallelogram().fill(fill.opacity(pressed ? 0.7 : 1)))
            case .glass:
                configuration.label
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
    }
}

private struct Parallelogram: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + 8, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Editor above, console below, with a draggable divider. The console's
/// height is remembered; the editor always keeps at least 160 points.
struct EditorConsoleSplit<Editor: View, Console: View>: View {

    @ViewBuilder let editor: Editor
    @ViewBuilder let console: Console

    @AppStorage("consoleHeight") private var consoleHeight: Double = 220
    @State private var dragStart: Double?
    @Environment(\.theme) private var theme

    private let minConsole: Double = 90
    private let minEditor: Double = 160

    var body: some View {
        GeometryReader { geo in
            let maxConsole = max(minConsole, geo.size.height - minEditor)
            let height = min(max(consoleHeight, minConsole), maxConsole)
            VStack(spacing: 0) {
                editor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                divider(maxConsole: maxConsole, current: height)
                console
                    .frame(height: height)
            }
        }
    }

    private func divider(maxConsole: Double, current: Double) -> some View {
        Rectangle()
            .fill(theme.isGlass ? Color(nsColor: .separatorColor) : theme.colors.accent.color.opacity(0.35))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStart ?? current
                        dragStart = start
                        consoleHeight = min(max(start - value.translation.height, minConsole), maxConsole)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .accessibilityHidden(true)
    }
}
