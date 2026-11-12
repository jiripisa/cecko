import AppKit
import CeckoCore

/// The editor's text view: C++ highlighting, auto-indent, bracket pairing
/// and compile errors drawn on their lines.
final class CodeTextView: NSTextView {

    var palette: SyntaxPalette?
    var colors: ThemeColors?
    var highlightsSyntax = true
    var glow = false
    /// Errors and warnings of the last compile for this file (with lines).
    var diagnostics: [Diagnostic] = [] {
        didSet { needsDisplay = true }
    }

    // MARK: Highlighting

    func rehighlight() {
        guard let storage = textStorage, let palette else { return }
        let full = NSRange(location: 0, length: storage.length)
        var base: [NSAttributedString.Key: Any] = [
            .font: ThemeContext.editorFont,
            .foregroundColor: palette.text.nsColor,
        ]
        if glow { base[.shadow] = Self.glowShadow(palette.text.nsColor) }

        storage.beginEditing()
        storage.setAttributes(base, range: full)
        if highlightsSyntax {
            for token in CppTokenizer.tokenize(storage.string) {
                let color = color(for: token.kind, in: palette)
                storage.addAttribute(.foregroundColor, value: color, range: token.range)
                if glow { storage.addAttribute(.shadow, value: Self.glowShadow(color), range: token.range) }
            }
        }
        storage.endEditing()
        typingAttributes = base
    }

    private func color(for kind: TokenKind, in p: SyntaxPalette) -> NSColor {
        switch kind {
        case .keyword: p.keyword.nsColor
        case .type: p.type.nsColor
        case .string: p.string.nsColor
        case .character: p.character.nsColor
        case .number: p.number.nsColor
        case .comment: p.comment.nsColor
        case .preprocessor: p.preprocessor.nsColor
        }
    }

    private static func glowShadow(_ color: NSColor) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = 5
        shadow.shadowOffset = .zero
        return shadow
    }

    // MARK: Typing helpers

    override func insertNewline(_ sender: Any?) {
        let location = selectedRange().location
        let edit = EditorAssist.newline(in: string, at: location)
        insert(edit.replacement, caretAt: edit.caretOffset)
    }

    override func insertTab(_ sender: Any?) {
        insertText(EditorAssist.indentUnit, replacementRange: selectedRange())
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard let typed = insertString as? String, typed.count == 1, let ch = typed.first,
              replacementRange.location == NSNotFound || replacementRange == selectedRange(),
              selectedRange().length == 0 else {
            super.insertText(insertString, replacementRange: replacementRange)
            return
        }
        let location = selectedRange().location

        if EditorAssist.shouldSkipTyped(ch, in: string, at: location) {
            setSelectedRange(NSRange(location: location + 1, length: 0))
            return
        }
        if ch == "}", let dedent = EditorAssist.dedentClosingBrace(in: string, at: location) {
            super.insertText(dedent.replacement, replacementRange: dedent.range)
            return
        }
        if let closing = EditorAssist.closingCharacter(for: ch), shouldAutoPair(ch, at: location) {
            insert(String(ch) + String(closing), caretAt: 1)
            return
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }

    /// Pairs only where it helps: before whitespace, a closing character or
    /// the end; quotes not right after a letter or digit (`don't`).
    private func shouldAutoPair(_ ch: Character, at location: Int) -> Bool {
        let ns = string as NSString
        if location < ns.length {
            let next = Character(UnicodeScalar(ns.character(at: location)) ?? " ")
            guard next.isWhitespace || ")]};,".contains(next) else { return false }
        }
        if ch == "\"" || ch == "'", location > 0 {
            let prev = Character(UnicodeScalar(ns.character(at: location - 1)) ?? " ")
            if prev.isLetter || prev.isNumber || prev == "\\" { return false }
        }
        return true
    }

    private func insert(_ text: String, caretAt offset: Int) {
        let start = selectedRange().location
        super.insertText(text, replacementRange: selectedRange())
        setSelectedRange(NSRange(location: start + offset, length: 0))
    }

    // MARK: Lines

    /// The rectangle of a 1-based line, in view coordinates.
    func rect(forLine line: Int) -> NSRect? {
        let ns = string as NSString
        guard let layoutManager, let textContainer,
              let index = characterIndex(ofLine: line, in: ns) else { return nil }
        var rect: NSRect
        if index == ns.length {
            // The empty last line after a final newline.
            rect = layoutManager.extraLineFragmentRect
            if rect.isEmpty { return nil }
        } else {
            let glyphs = layoutManager.glyphRange(
                forCharacterRange: ns.lineRange(for: NSRange(location: index, length: 0)), actualCharacterRange: nil)
            rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        }
        rect.origin.x = 0
        rect.size.width = bounds.width
        return rect.offsetBy(dx: 0, dy: textContainerOrigin.y)
    }

    /// Moves the caret to the start of a 1-based line and scrolls to it.
    func reveal(line: Int) {
        let ns = string as NSString
        let index = characterIndex(ofLine: line, in: ns) ?? ns.length
        let range = ns.lineRange(for: NSRange(location: index, length: 0))
        setSelectedRange(NSRange(location: range.location, length: 0))
        scrollRangeToVisible(range)
        window?.makeFirstResponder(self)
    }

    // MARK: Drawing compile errors

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let colors, let layoutManager, let textContainer else { return }
        let ns = string as NSString

        // One highlight and one bubble per line: errors win over warnings,
        // further messages on the same line show as "+N".
        let byLine = Dictionary(grouping: diagnostics.filter { $0.line != nil }, by: { $0.line! })
        for (line, list) in byLine {
            guard let lineRect = self.rect(forLine: line) else { continue }
            let sorted = list.sorted { ($0.severity == .error ? 0 : 1) < ($1.severity == .error ? 0 : 1) }
            let d = sorted[0]
            let isError = d.severity == .error
            (isError ? colors.errorLine : colors.warningLine).nsColor.setFill()
            lineRect.fill()
            (isError ? colors.errorBubble : colors.warningBubble).nsColor.setFill()
            NSRect(x: lineRect.minX, y: lineRect.minY, width: 3, height: lineRect.height).fill()

            // The bubble sits after the end of the line's text (without its newline).
            var textEnd = textContainerOrigin.x + 8
            if let charIndex = characterIndex(ofLine: line, in: ns), charIndex < ns.length {
                var contentsEnd = 0
                ns.getLineStart(nil, end: nil, contentsEnd: &contentsEnd, for: NSRange(location: charIndex, length: 0))
                if contentsEnd > charIndex {
                    let glyphs = layoutManager.glyphRange(
                        forCharacterRange: NSRange(location: charIndex, length: contentsEnd - charIndex),
                        actualCharacterRange: nil)
                    let used = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
                    textEnd = max(textEnd, textContainerOrigin.x + used.maxX)
                }
            }
            let message = sorted.count > 1 ? d.message + "  +\(sorted.count - 1)" : d.message
            drawBubble(message, x: textEnd + 18, lineRect: lineRect,
                       maxX: visibleRect.maxX - 8,
                       fill: (isError ? colors.errorBubble : colors.warningBubble).nsColor,
                       text: isError ? .white : .black)
        }
    }

    /// Draws the message in a rounded bubble from `x`, shortened with "…"
    /// so it ends before `maxX` (the visible edge of the editor).
    private func drawBubble(_ message: String, x: CGFloat, lineRect: NSRect, maxX: CGFloat,
                            fill: NSColor, text: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let attributed = NSAttributedString(string: message, attributes: [
            .font: font, .foregroundColor: text, .paragraphStyle: paragraph])
        let size = attributed.size()
        let width = min(size.width, max(maxX - x - 14, 40))
        let height = min(lineRect.height - 2, size.height + 2)
        let bubble = NSRect(x: x, y: lineRect.midY - height / 2, width: width + 14, height: height)
        fill.setFill()
        NSBezierPath(roundedRect: bubble, xRadius: 5, yRadius: 5).fill()
        attributed.draw(with: NSRect(x: bubble.minX + 7, y: bubble.midY - size.height / 2,
                                     width: width, height: size.height),
                        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    private func characterIndex(ofLine line: Int, in ns: NSString) -> Int? {
        var index = 0
        for _ in 1..<max(line, 1) {
            guard index < ns.length else { return nil }
            index = NSMaxRange(ns.lineRange(for: NSRange(location: index, length: 0)))
        }
        return index <= ns.length ? index : nil
    }
}
