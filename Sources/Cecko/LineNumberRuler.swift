import AppKit

/// Line numbers to the left of the editor.
final class LineNumberRuler: NSRulerView {

    var numberColor: NSColor = .secondaryLabelColor { didSet { needsDisplay = true } }
    var background: NSColor = .clear { didSet { needsDisplay = true } }

    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: NSText.didChangeNotification, object: textView)
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func refresh() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        background.setFill()
        bounds.fill()
        guard let textView, let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let ns = textView.string as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: numberColor]
        let visible = textView.visibleRect
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let chars = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)

        // Line number of the first visible character.
        var line = 1
        var i = 0
        while i < chars.location {
            if ns.character(at: i) == 10 { line += 1 }
            i += 1
        }

        let origin = textView.textContainerOrigin.y - visible.minY
        var index = chars.location
        func draw(_ number: Int, in lineRect: NSRect) {
            let label = NSAttributedString(string: "\(number)", attributes: attributes)
            let size = label.size()
            let y = lineRect.minY + origin + (lineRect.height - size.height) / 2
            label.draw(at: NSPoint(x: ruleThickness - size.width - 10, y: y))
        }
        while index < NSMaxRange(chars) {
            let lineRange = ns.lineRange(for: NSRange(location: index, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: lineRange.location, length: 0),
                                                      actualCharacterRange: nil)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            draw(line, in: lineRect)
            line += 1
            index = NSMaxRange(lineRange)
        }
        // The empty line after a final newline.
        if NSMaxRange(chars) == ns.length, !layoutManager.extraLineFragmentRect.isEmpty {
            draw(line, in: layoutManager.extraLineFragmentRect)
        }
    }
}
