import AppKit
import SwiftUI

struct EditorHighlight: Equatable {
    let range: NSRange
    let background: NSColor
}

struct EditorSelection: Equatable {
    let id = UUID()
    let range: NSRange
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var highlights: [EditorHighlight] = []
    var isEditable = true
    var syntaxHighlighting = true
    var selection: EditorSelection?
    var accessibilityLabel = "文本编辑器"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        makeScrollView(coordinator: context.coordinator)
    }

    func makeScrollView(coordinator: Coordinator) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.delegate = coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = EditorTextView.lineHeight
        paragraph.maximumLineHeight = EditorTextView.lineHeight
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [.font: textView.font!, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = textView.maxSize
        textView.textContainer?.widthTracksTextView = false
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.string = text
        scrollView.documentView = textView
        let ruler = EditorLineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        textView.lineNumberRuler = ruler
        coordinator.textView = textView
        coordinator.applyStyle()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        textView.isEditable = isEditable
        textView.setAccessibilityLabel(accessibilityLabel)
        if textView.string != text, !textView.hasMarkedText() {
            let oldRange = NSRange(location: 0, length: (textView.string as NSString).length)
            if isEditable, textView.shouldChangeText(in: oldRange, replacementString: text) {
                textView.textStorage?.replaceCharacters(in: oldRange, with: text)
                textView.didChangeText()
            } else if !isEditable { textView.string = text }
        }
        context.coordinator.applyStyle()
        if let selection, context.coordinator.lastSelection != selection.id {
            context.coordinator.lastSelection = selection.id
            let length = (textView.string as NSString).length
            guard selection.range.location <= length, NSMaxRange(selection.range) <= length else { return }
            textView.setSelectedRange(selection.range)
            textView.scrollRangeToVisible(selection.range)
            textView.showFindIndicator(for: selection.range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?
        var lastSelection: UUID?
        private var styledText: String?
        private var styledHighlights: [EditorHighlight] = []
        private var styledSyntax: Bool?
        // One token scan prevents numbers/keywords inside strings being recolored.
        private static let tokens = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b|\b(?:true|false|null)\b"#)

        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView, !textView.hasMarkedText() else { return }
            if parent.text != textView.string { parent.text = textView.string }
            applyStyle()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            textView?.needsDisplay = true
            (textView as? EditorTextView)?.lineNumberRuler?.needsDisplay = true
        }

        func applyStyle() {
            (textView as? EditorTextView)?.refreshLineNumbers()
            guard let textView, let layout = textView.layoutManager, !textView.hasMarkedText() else { return }
            let source = textView.string
            guard source != styledText || parent.highlights != styledHighlights || parent.syntaxHighlighting != styledSyntax else { return }
            styledText = source
            styledHighlights = parent.highlights
            styledSyntax = parent.syntaxHighlighting
            let full = NSRange(location: 0, length: (source as NSString).length)
            layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
            if parent.syntaxHighlighting { applyJSONSyntax(source, layout: layout, range: full) }
            for highlight in parent.highlights where highlight.range.location >= 0 && NSMaxRange(highlight.range) <= full.length {
                layout.addTemporaryAttribute(.backgroundColor, value: highlight.background, forCharacterRange: highlight.range)
            }
        }

        private func applyJSONSyntax(_ source: String, layout: NSLayoutManager, range: NSRange) {
            let ns = source as NSString
            for match in Self.tokens.matches(in: source, range: range) {
                let token = ns.substring(with: match.range)
                let color: NSColor
                if token.hasPrefix("\"") {
                    var next = NSMaxRange(match.range)
                    while next < ns.length && [9, 10, 13, 32].contains(ns.character(at: next)) { next += 1 }
                    color = next < ns.length && ns.character(at: next) == 58 ? .systemBlue : .systemGreen
                } else if token == "true" || token == "false" || token == "null" { color = .systemOrange }
                else { color = .systemPurple }
                layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: match.range)
            }
        }
    }
}

/// Layout and drawing remain independent of text attributes, undo and marked text.
final class EditorTextView: NSTextView {
    static let lineHeight: CGFloat = 19
    weak var lineNumberRuler: EditorLineNumberRuler?
    private(set) var lineStarts: [Int] = [0]
    private var numberedText: String?

    override func didChangeText() {
        super.didChangeText()
        refreshLineNumbers()
    }

    func refreshLineNumbers() {
        guard numberedText != string else { return }
        numberedText = string
        let source = string as NSString
        var starts = [0]
        var position = 0
        while position < source.length {
            var end = 0
            var contentsEnd = 0
            source.getLineStart(nil, end: &end, contentsEnd: &contentsEnd,
                                for: NSRange(location: position, length: 0))
            if contentsEnd < end { starts.append(end) }
            guard end > position else { break }
            position = end
        }
        lineStarts = starts
        lineNumberRuler?.updateThickness()
        lineNumberRuler?.needsDisplay = true
        needsDisplay = true
    }

    func lineIndex(containingUTF16Offset offset: Int) -> Int {
        var lower = 0
        var upper = lineStarts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lineStarts[middle] <= offset { lower = middle + 1 }
            else { upper = middle }
        }
        return max(0, lower - 1)
    }

    func lineRect(atUTF16Offset offset: Int) -> NSRect {
        guard let layoutManager, let textContainer else { return .zero }
        layoutManager.ensureLayout(for: textContainer)
        let length = (string as NSString).length
        let rect: NSRect
        if offset < length {
            let glyph = layoutManager.glyphIndexForCharacter(at: offset)
            rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        } else if layoutManager.extraLineFragmentTextContainer != nil {
            rect = layoutManager.extraLineFragmentRect
        } else if length > 0 {
            let glyph = layoutManager.glyphIndexForCharacter(at: length - 1)
            rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        } else {
            rect = NSRect(x: 0, y: 0, width: 0, height: Self.lineHeight)
        }
        return rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard isEditable, selectedRange().length == 0 else { return }
        var line = lineRect(atUTF16Offset: selectedRange().location)
        line.origin.x = bounds.minX
        line.size.width = bounds.width
        NSColor.labelColor.withAlphaComponent(0.035).setFill()
        line.intersection(rect).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        lineNumberRuler?.needsDisplay = true
    }
}

final class EditorLineNumberRuler: NSRulerView {
    private weak var editor: EditorTextView?
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    override var isFlipped: Bool { true }

    init(textView: EditorTextView, scrollView: NSScrollView) {
        editor = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(viewportChanged),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        setAccessibilityElement(false)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func viewportChanged(_ notification: Notification) { needsDisplay = true }

    func updateThickness() {
        let digits = String(editor?.lineStarts.count ?? 1) as NSString
        let width = max(36, ceil(digits.size(withAttributes: [.font: numberFont]).width) + 16)
        if ruleThickness != width { ruleThickness = width }
    }

    func lineNumberRect(atUTF16Offset offset: Int) -> NSRect {
        guard let editor else { return .zero }
        return convert(editor.lineRect(atUTF16Offset: offset), from: editor)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        let drawingRect = bounds.intersection(rect)
        NSColor.controlBackgroundColor.setFill()
        drawingRect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: drawingRect.minY, width: 1, height: drawingRect.height).fill()
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        let visible = editor.visibleRect.offsetBy(dx: -editor.textContainerOrigin.x, dy: -editor.textContainerOrigin.y)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let firstLine = editor.lineIndex(containingUTF16Offset: characters.location)
        let currentLine = editor.lineIndex(containingUTF16Offset: editor.selectedRange().location)
        for index in firstLine..<editor.lineStarts.count {
            let line = lineNumberRect(atUTF16Offset: editor.lineStarts[index])
            if line.minY > rect.maxY { break }
            guard line.maxY >= rect.minY else { continue }
            let label = String(index + 1) as NSString
            let color: NSColor = editor.isEditable && index == currentLine ? .labelColor : .secondaryLabelColor
            let attributes: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: color]
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8,
                                   y: line.minY + (line.height - size.height) / 2), withAttributes: attributes)
        }
    }
}
