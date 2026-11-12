import AppKit
import CeckoCore
import SwiftUI

/// The SwiftUI wrapper around `CodeTextView` for the open document.
struct CodeEditor: NSViewRepresentable {

    let document: EditorDocument
    let theme: ThemeContext
    let diagnostics: [Diagnostic]
    let lineToReveal: (line: Int, id: UUID)?
    let focusRequest: UUID
    /// Called when the student edits; compile errors no longer match the text.
    let onEdit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CodeTextView(usingTextLayoutManager: false)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 6, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        let ruler = LineNumberRuler(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        load(into: textView, context: context)
        apply(theme: theme, to: textView, ruler: ruler, scrollView: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView, let ruler = coordinator.ruler else { return }

        if coordinator.documentID != ObjectIdentifier(document) || coordinator.reloadToken != document.reloadToken {
            load(into: textView, context: context)
        }
        if coordinator.themeKey != themeKey {
            apply(theme: theme, to: textView, ruler: ruler, scrollView: scrollView)
            coordinator.themeKey = themeKey
        }
        if textView.diagnostics != diagnostics.filter({ $0.line != nil }) {
            textView.diagnostics = diagnostics.filter { $0.line != nil }
        }
        if coordinator.focusRequest != focusRequest {
            let first = coordinator.focusRequest == nil
            coordinator.focusRequest = focusRequest
            if !first { DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) } }
        }
        if let request = lineToReveal, request.id != coordinator.revealedID {
            coordinator.revealedID = request.id
            DispatchQueue.main.async { textView.reveal(line: request.line) }
        }
    }

    private var themeKey: String {
        "\(theme.id.rawValue)-\(theme.colors.editorBackground)"
    }

    private func load(into textView: CodeTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isLoading = true
        textView.string = document.text
        textView.undoManager?.removeAllActions()
        textView.highlightsSyntax = document.isHighlighted
        textView.isCFile = document.url.pathExtension.lowercased() == "c"
        textView.rehighlight()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollToBeginningOfDocument(nil)
        coordinator.documentID = ObjectIdentifier(document)
        coordinator.reloadToken = document.reloadToken
        coordinator.isLoading = false
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
    }

    private func apply(theme: ThemeContext, to textView: CodeTextView, ruler: LineNumberRuler, scrollView: NSScrollView) {
        textView.palette = theme.syntax
        textView.colors = theme.colors
        textView.glow = theme.id == .hacker
        textView.drawsBackground = false
        textView.insertionPointColor = theme.colors.accent.nsColor
        textView.selectedTextAttributes = [.backgroundColor: theme.colors.selection.nsColor]
        textView.rehighlight()
        ruler.numberColor = theme.syntax.lineNumber.nsColor
        ruler.background = .clear
        scrollView.scrollerKnobStyle = theme.data.isDark == true ? .light : .default
        textView.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: CodeTextView?
        weak var ruler: LineNumberRuler?
        var documentID: ObjectIdentifier?
        var reloadToken = -1
        var themeKey = ""
        var revealedID: UUID?
        var focusRequest: UUID?
        var isLoading = false

        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isLoading, let textView else { return }
            MainActor.assumeIsolated {
                textView.rehighlight()
                parent.document.text = textView.string
                if !textView.diagnostics.isEmpty {
                    textView.diagnostics = []
                    parent.onEdit()
                }
            }
        }
    }
}
