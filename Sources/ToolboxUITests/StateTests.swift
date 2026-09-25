import AppKit
import SwiftUI
import ToolboxCore
@testable import ToolboxUI

@main
struct StateTests {
    @MainActor
    static func main() async throws {
        let model = JSONToolModel()
        model.mode = .compare
        model.leftText = #"{"x":1}"#
        model.rightText = #"{"x":2}"#
        try await waitUntil { model.differences.count == 1 }
        model.rightText = "{"
        precondition(model.differences.isEmpty, "Changing input must immediately clear stale source ranges")
        try await waitUntil { model.isError }
        precondition(model.outputText.isEmpty && model.differences.isEmpty)
        model.rightText = #"{"x":1.0}"#
        try await waitUntil { !model.isError && model.message == "两侧 JSON 相同" }
        model.mode = .format
        model.leftText = "[1,2]"
        model.leftText = "[3,4]"
        model.mode = .compress
        try await waitUntil { model.outputText == "[3,4]" }
        model.clear()
        try await Task.sleep(nanoseconds: 400_000_000)
        precondition(model.outputText.isEmpty && model.differences.isEmpty && !model.isError)
        let codec = EncodingToolModel(kind: .base64)
        codec.input = "中文"
        precondition(codec.output == "5Lit5paH")
        codec.isDecoding = true
        precondition(codec.input == "中文" && codec.output.isEmpty && codec.isError)
        codec.input = "5Lit5paH"
        precondition(codec.output == "中文" && !codec.isError)
        codec.clear()
        precondition(codec.input.isEmpty && codec.output.isEmpty && !codec.isError)
        try testEditorStylingAndUndo()
        try await renderPreviews()
        print("ToolboxUITests: state transitions, debounce, error recovery, editor styling, undo and native layout passed")
    }


    @MainActor
    static func testEditorStylingAndUndo() throws {
        _ = NSApplication.shared
        var source = #"{"key":"true 123","x":1}"#
        let editor = CodeEditor(text: Binding(get: { source }, set: { source = $0 }))
        let coordinator = editor.makeCoordinator()
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        view.allowsUndo = true
        view.isRichText = false
        view.string = source
        coordinator.textView = view
        coordinator.applyStyle()
        let layout = view.layoutManager!
        let keyRange = (source as NSString).range(of: "key")
        let stringRange = (source as NSString).range(of: "true 123")
        let keyColor = layout.temporaryAttribute(.foregroundColor, atCharacterIndex: keyRange.location, effectiveRange: nil) as? NSColor
        let stringColor = layout.temporaryAttribute(.foregroundColor, atCharacterIndex: stringRange.location, effectiveRange: nil) as? NSColor
        precondition(keyColor == NSColor.systemBlue, "Keys must retain their syntax color")
        precondition(stringColor == NSColor.systemGreen, "Keywords within strings must remain string-colored")
        view.insertText(" ", replacementRange: NSRange(location: 0, length: 0))
        view.breakUndoCoalescing()
        source = view.string
        coordinator.parent = CodeEditor(text: Binding(get: { source }, set: { source = $0 }))
        coordinator.applyStyle()
        precondition(view.undoManager?.canUndo == true, "Styling must not erase text undo")
        view.undoManager?.undo()
        precondition(view.string == #"{"key":"true 123","x":1}"#, "Undo must reverse the edit, not styling")
        window.orderOut(nil)
    }

    @MainActor
    static func renderPreviews() async throws {
        guard CommandLine.arguments.contains("--render") else { return }
        let model = JSONToolModel()
        model.mode = .compare
        model.leftText = "{\n  \"name\": \"NsToolBox\",\n  \"version\": 1,\n  \"tools\": [\"JSON\", \"Base64\"]\n}"
        model.rightText = "{\n  \"name\": \"NsToolBox\",\n  \"version\": 2,\n  \"tools\": [\"JSON\", \"Base64\", \"URL\"]\n}"
        try await waitUntil { model.differences.count == 2 }
        try await render(JSONToolView(model: model), name: "json-compare")
        try await render(ToolboxRootView(), name: "app-shell")
        let codec = EncodingToolModel(kind: .base64)
        codec.input = "NsToolBox · 你好，开发者！"
        try await render(EncodingToolView(model: codec), name: "base64")
    }

    @MainActor
    static func render<V: View>(_ content: V, name: String) async throws {
        let view = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 740), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderFront(nil)
        view.frame = NSRect(x: 0, y: 0, width: 1180, height: 740)
        try await Task.sleep(nanoseconds: 300_000_000)
        view.layoutSubtreeIfNeeded()
        if name == "app-shell" {
            func tables(_ view: NSView) -> [NSTableView] {
                (view as? NSTableView).map { [$0] } ?? view.subviews.flatMap(tables)
            }
            let tableRows = tables(view).map(\.numberOfRows)
            print("App sidebar table rows:", tableRows)
            precondition(tableRows.contains(3), "Sidebar must expose all three tools")
            func editors(_ view: NSView) -> [NSTextView] {
                (view as? NSTextView).map { [$0] } ?? view.subviews.flatMap(editors)
            }
            func editor(_ label: String) -> NSTextView? {
                editors(view).first { $0.accessibilityLabel() == label }
            }
            let table = tables(view).first { $0.numberOfRows == 3 }!
            let jsonInput = editor("JSON 输入")!
            jsonInput.insertText(#"{"saved":1}"#, replacementRange: NSRange(location: 0, length: 0))
            try await waitUntil { editor("格式化结果")?.string.contains("saved") == true }
            table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            try await waitUntil { editor("输入文本") != nil }
            editor("输入文本")!.insertText("hello", replacementRange: NSRange(location: 0, length: 0))
            try await waitUntil { editor("编码结果")?.string == "aGVsbG8=" }
            table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
            try await waitUntil { editor("输入文本")?.string == "" }
            editor("输入文本")!.insertText("a+b /", replacementRange: NSRange(location: 0, length: 0))
            try await waitUntil { editor("编码结果")?.string == "a%2Bb%20%2F" }
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            try await waitUntil { editor("JSON 输入")?.string == #"{"saved":1}"# }
            print("Native UI: sidebar switching, JSON/Base64/URL input/output and input retention passed")
        }
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        precondition(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
        window.orderOut(nil)
    }

    @MainActor
    static func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<150 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        preconditionFailure("Timed out waiting for UI state")
    }
}
