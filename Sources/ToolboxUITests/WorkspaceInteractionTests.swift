import AppKit
import SwiftUI
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func testWorkspaceInteraction() async throws {
        let model = JSONToolModel()
        model.leftText = #"{"left":1}"#
        model.rightText = #"{"left":2}"#
        let view = NSHostingView(rootView: JSONToolView(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(nanoseconds: 300_000_000)
        defer { window.orderOut(nil) }
        func pointFromTop(_ point: NSPoint) -> NSPoint {
            view.convert(NSPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y), to: nil)
        }
        func editor(_ title: String) -> NSTextView? {
            descendants(view, of: NSTextView.self).first { $0.accessibilityLabel() == title }
        }
        try await waitUntil { editor("格式化结果")?.string.contains("left") == true }
        model.mode = .compress
        try await waitUntil { editor("压缩结果")?.string == #"{"left":1}"# }
        precondition(editor("压缩结果")?.isEditable == false)
        model.mode = .compare
        try await waitUntil { editor("左侧 · 原始 JSON") != nil && editor("右侧 · 对比 JSON") != nil && model.differences.count == 1 }
        let left = editor("左侧 · 原始 JSON")!
        let right = editor("右侧 · 对比 JSON")!
        precondition(left.isEditable && right.isEditable)
        precondition(left.enclosingScrollView!.frame.width >= 280 && right.enclosingScrollView!.frame.width >= 280)
        try await Task.sleep(nanoseconds: 150_000_000)
        view.layoutSubtreeIfNeeded()
        let originalHeight = left.enclosingScrollView!.frame.height
        // Expand/collapse through real window events, rather than directly changing view state.
        let disclosurePoint = pointFromTop(NSPoint(x: 30, y: view.bounds.height - 24 - 14))
        click(disclosurePoint, in: window)
        try await waitUntil { left.enclosingScrollView!.frame.height < originalHeight - 100 }
        try await Task.sleep(nanoseconds: 100_000_000)
        // The disclosure moves up while open, so close it at the new position.
        let openPoint = pointFromTop(NSPoint(x: 30, y: view.bounds.height - 24 - 120 - 1 - 14))
        click(openPoint, in: window)
        try await waitUntil { abs(left.enclosingScrollView!.frame.height - originalHeight) < 2 }

        window.makeFirstResponder(left)
        left.undoManager?.removeAllActions()
        let scroll = left.enclosingScrollView!
        let clearPoint = scroll.convert(NSPoint(x: scroll.bounds.width - 24, y: scroll.isFlipped ? -14 : scroll.bounds.height + 14), to: nil)
        click(clearPoint, in: window)
        try await waitUntil { left.string.isEmpty }
        precondition(model.rightText == #"{"left":2}"#, "Panel clear must not touch the opposite input")
        left.undoManager?.undo()
        try await waitUntil { model.leftText == #"{"left":1}"# }
        try await waitUntil { !model.isProcessing && !model.isError }
        // Model completion precedes SwiftUI committing the button's enabled state.
        // Let that render pass finish before sending the actual click.
        try await Task.sleep(for: .milliseconds(100))
        view.layoutSubtreeIfNeeded()
        left.undoManager?.removeAllActions()
        right.undoManager?.removeAllActions()
        click(pointFromTop(NSPoint(x: view.bounds.width - 50, y: WorkspaceStyle.toolbarHeight / 2)), in: window)
        try await waitUntil { left.string.contains("\n") && right.string.contains("\n") }
        window.makeFirstResponder(left)
        left.undoManager?.undo()
        try await waitUntil { model.leftText == #"{"left":1}"# }

        model.mode = .validate
        model.leftText = "{\n  \"a\":\n}"
        try await waitUntil { model.leftError != nil && editor("JSON 输入") != nil }
        precondition(descendants(view, of: NSTextView.self).count == 1, "Validation report replaces the output editor")
        let input = editor("JSON 输入")!
        let split = descendants(view, of: NSSplitView.self).first!
        let report = split.subviews[1]
        // Report layout: header 28, padding 12, summary + detail + location button.
        click(report.convert(NSPoint(x: 100, y: report.isFlipped ? 107 : report.bounds.height - 107), to: nil), in: window)
        try await waitUntil { input.selectedRange().location == model.leftError?.offset }
        precondition(model.rightText == #"{"left":2}"# || model.rightText.contains("left"))
        print("Native UI: mode labels, read-only output, collapsible differences, panel clear/undo, format/undo and validation location passed")
    }
}
