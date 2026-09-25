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
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
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
        context.coordinator.textView = textView
        context.coordinator.applyStyle()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != text, !textView.hasMarkedText() {
            let oldRange = NSRange(location: 0, length: (textView.string as NSString).length)
            if isEditable, textView.shouldChangeText(in: oldRange, replacementString: text) {
                textView.textStorage?.replaceCharacters(in: oldRange, with: text)
                textView.didChangeText()
            } else if !isEditable { textView.string = text }
        }
        textView.isEditable = isEditable
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

        func applyStyle() {
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
