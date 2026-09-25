import AppKit
import SwiftUI
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func testLineNumbersAndEditing() throws {
        _ = NSApplication.shared
        var source = "😀中文\r\n第二行\n"
        let editor = CodeEditor(text: Binding(get: { source }, set: { source = $0 }),
                                highlights: [EditorHighlight(range: NSRange(location: 0, length: 2), background: .systemRed)])
        let coordinator = editor.makeCoordinator()
        let scroll = editor.makeScrollView(coordinator: coordinator)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 240),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        scroll.frame = NSRect(x: 0, y: 0, width: 500, height: 240)
        scroll.layoutSubtreeIfNeeded()
        let view = scroll.documentView as! EditorTextView
        let ruler = scroll.verticalRulerView as! EditorLineNumberRuler
        precondition(scroll.rulersVisible && ruler.clientView === view, "Line numbers must be a native attached ruler")
        precondition(view.lineStarts == [0, 6, 10], "CRLF is one break; offsets must use UTF-16 and include trailing blank lines")
        precondition(view.font?.pointSize == 13 && view.textContainerInset == NSSize(width: 8, height: 8))
        precondition(view.textContainer?.widthTracksTextView == false && scroll.hasHorizontalScroller)
        let layout = view.layoutManager!
        layout.ensureLayout(for: view.textContainer!)
        let first = view.lineRect(atUTF16Offset: 0)
        let second = view.lineRect(atUTF16Offset: 6)
        let trailing = view.lineRect(atUTF16Offset: 10)
        precondition(abs(second.minY - first.minY - 19) < 1, "Editor lines must retain compact, consistent spacing")
        precondition(trailing.minY > second.minY, "A final newline must have a distinct numbered blank line")
        view.setSelectedRange(NSRange(location: 0, length: 0))
        coordinator.textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification, object: view))
        precondition(layout.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) as? NSColor == .systemRed,
                     "Moving the current line must not replace difference highlights")
        view.insertText("x", replacementRange: NSRange(location: 0, length: 0))
        view.breakUndoCoalescing()
        coordinator.applyStyle()
        precondition(view.undoManager?.canUndo == true)
        view.undoManager?.undo()
        precondition(view.string == "😀中文\r\n第二行\n", "Line numbers and styling must not add undo operations")

        view.setMarkedText("拼", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 0, length: 0))
        let markedString = view.string
        let markedRange = view.markedRange()
        coordinator.applyStyle()
        precondition(view.hasMarkedText() && view.string == markedString && view.markedRange() == markedRange,
                     "Styling must preserve the input method composition")
        view.unmarkText()

        view.string = ""
        view.refreshLineNumbers()
        precondition(view.lineStarts == [0], "Empty editors display line 1")
        view.string = "a\r\nb\rc\nd\u{2028}e\u{2029}"
        view.refreshLineNumbers()
        precondition(view.lineStarts == [0, 3, 5, 7, 9, 11], "All native line separators must be numbered without splitting CRLF")

        view.string = (1...100).map { "line \($0)" }.joined(separator: "\n")
        view.refreshLineNumbers()
        layout.ensureLayout(for: view.textContainer!)
        view.sizeToFit()
        let offset = view.lineStarts[40]
        let initial = ruler.lineNumberRect(atUTF16Offset: offset).minY
        let oldOrigin = scroll.contentView.bounds.origin.y
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 300))
        scroll.reflectScrolledClipView(scroll.contentView)
        let movement = scroll.contentView.bounds.origin.y - oldOrigin
        precondition(movement > 0)
        precondition(abs(initial - ruler.lineNumberRect(atUTF16Offset: offset).minY - movement) < 1,
                     "Ruler labels must follow the text's vertical scroll offset")
        testRulerDrawingClipsToBounds(ruler)
        window.orderOut(nil)
    }

    @MainActor
    private static func testRulerDrawingClipsToBounds(_ ruler: EditorLineNumberRuler) {
        // Draw with an intentionally oversized dirty rect and no caller-provided clip,
        // reproducing the native window path that previously covered the editor.
        let padding = 16
        let width = Int(ceil(ruler.bounds.width)) + padding * 2
        let height = Int(ceil(ruler.bounds.height)) + padding * 2
        precondition(width > padding * 2 && height > padding * 2)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        NSColor(deviceRed: 1, green: 0, blue: 1, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)).fill()
        context.cgContext.translateBy(x: CGFloat(padding) - ruler.bounds.minX,
                                      y: CGFloat(padding) - ruler.bounds.minY)
        ruler.drawHashMarksAndLabels(in: ruler.bounds.insetBy(dx: -CGFloat(padding), dy: -CGFloat(padding)))

        func isMarker(x: Int, y: Int) -> Bool {
            let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
            return color.redComponent > 0.95 && color.greenComponent < 0.05 &&
                color.blueComponent > 0.95 && color.alphaComponent > 0.95
        }
        for y in 0..<height {
            for x in 0..<width where x < padding - 1 || x >= width - padding + 1 ||
                y < padding - 1 || y >= height - padding + 1 {
                precondition(isMarker(x: x, y: y),
                             "Ruler drawing must never cover neighboring editor or header pixels (\(x), \(y))")
            }
        }
        precondition(!isMarker(x: padding + 3, y: height / 2),
                     "The ruler must actually draw its background inside its bounds")

        // The ruler must also restore the caller's clip after drawing.
        NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
        NSRect(x: ruler.bounds.minX - 12, y: ruler.bounds.minY - 12, width: 8, height: 8).fill()
        precondition(!isMarker(x: 8, y: 8) || !isMarker(x: 8, y: height - 9),
                     "Ruler drawing must restore the caller's graphics state")
    }
}
