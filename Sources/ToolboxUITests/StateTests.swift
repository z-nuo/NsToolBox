import AppKit
import SwiftUI
import ToolboxCore
@testable import ToolboxUI

@main
struct StateTests {
    @MainActor
    static func main() {
        setbuf(stdout, nil)
        let application = NSApplication.shared
        application.setActivationPolicy(CommandLine.arguments.contains("--render") ? .regular : .accessory)
        Task { @MainActor in
            do {
                if let flag = CommandLine.arguments.firstIndex(of: "--image-termination-probe"),
                   CommandLine.arguments.indices.contains(flag + 1) {
                    try await imageTerminationProbe(directory: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
                } else { try await runTests() }
            }
            catch { print("ToolboxUITests failed:", error); exit(1) }
            application.stop(nil)
            application.postEvent(NSEvent.otherEvent(with: .applicationDefined, location: .zero,
                modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!, atStart: false)
        }
        application.run()
    }

    @MainActor
    static func runTests() async throws {
        if CommandLine.arguments.contains("--image-isolation-only") {
            try await testImageOperationIsolation()
            return
        }
        if CommandLine.arguments.contains("--image-previews-only") {
            try await testImageBatch()
            return
        }
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
        try testLineNumbersAndEditing()
        try await testModeAndInputRetention()
        try await testImageBatch()
        try await testImageOperationIsolation()
        try await renderPreviews()
        print("ToolboxUITests: state, debounce, errors, line numbers, styling and undo passed" + (CommandLine.arguments.contains("--render") ? "; native workflows passed" : ""))
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
        try await testWorkspaceInteraction()
        let model = JSONToolModel()
        model.mode = .compare
        model.leftText = "{\n  \"name\": \"NsToolBox\",\n  \"version\": 1,\n  \"tools\": [\"JSON\", \"Base64\"]\n}"
        model.rightText = "{\n  \"name\": \"NsToolBox\",\n  \"version\": 2,\n  \"tools\": [\"JSON\", \"Base64\", \"URL\"]\n}"
        try await waitUntil { model.differences.count == 2 }
        try await render(JSONToolView(model: model), name: "json-compare")
        try await render(ToolboxRootView(), name: "app-shell")
        try await render(ToolboxRootView(), name: "app-shell-dark-minimum", size: NSSize(width: 980, height: 640), dark: true)
        model.mode = .validate
        model.leftText = "{\n  \"a\":\n}"
        try await waitUntil { model.leftError != nil }
        try await render(JSONToolView(model: model), name: "json-validation", size: NSSize(width: 780, height: 570))
        let codec = EncodingToolModel(kind: .base64)
        codec.input = "NsToolBox · 你好，开发者！"
        try await render(EncodingToolView(model: codec), name: "base64")
    }

    @MainActor
    static func render<V: View>(_ content: V, name: String, size: NSSize = NSSize(width: 1180, height: 740), dark: Bool = false) async throws {
        let view = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = view
        window.title = "NsToolBox"
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApp.setActivationPolicy(.regular)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        view.frame = NSRect(origin: .zero, size: size)
        try await Task.sleep(nanoseconds: 300_000_000)
        view.layoutSubtreeIfNeeded()
        for child in descendants(view, of: NSScrollView.self) { child.layoutSubtreeIfNeeded(); child.documentView?.displayIfNeeded() }
        window.displayIfNeeded()
        if CommandLine.arguments.contains("--capture") {
            let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/previews")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l", String(window.windowNumber), destination.appendingPathComponent(name + "-window.png").path]
            try capture.run()
            capture.waitUntilExit()
            print("Window capture:", name, capture.terminationStatus)
        }
        if name == "app-shell" {
            let navigation = descendants(view, of: NSSplitView.self).first!
            precondition(navigation.subviews.count >= 2)
            precondition((120...200).contains(navigation.subviews[0].frame.width), "Category column width must be bounded")
            func editor(_ label: String) -> NSTextView? {
                descendants(view, of: NSTextView.self).first { $0.accessibilityLabel() == label }
            }
            func selectTool(_ label: String) {
                let index = ToolRoute.allCases.firstIndex { $0.rawValue == label }!
                let content = navigation.subviews[1]
                let point = content.convert(NSPoint(x: CGFloat(index) * 104 + 52,
                    y: content.isFlipped ? 17 : content.bounds.height - 17), to: nil)
                click(point, in: window)
            }
            precondition(editor("JSON 输入") == nil, "A new window must open the image workspace")
            let category = navigation.subviews[0]
            func selectGroup(atTop y: CGFloat) {
                click(category.convert(NSPoint(x: 64, y: category.isFlipped ? y : category.bounds.height - y), to: nil), in: window)
            }
            selectGroup(atTop: 52)
            try await waitUntil { editor("JSON 输入") != nil }
            let jsonInput = editor("JSON 输入")!
            jsonInput.insertText(#"{"saved":1}"#, replacementRange: NSRange(location: 0, length: 0))
            try await waitUntil { editor("格式化结果")?.string.contains("saved") == true }
            precondition(editor("格式化结果")?.isEditable == false)
            selectTool("Base64")
            try await waitUntil { editor("输入文本") != nil }
            editor("输入文本")!.insertText("hello", replacementRange: NSRange(location: 0, length: 0))
            try await waitUntil { editor("编码结果")?.string == "aGVsbG8=" }
            selectTool("URL")
            try await waitUntil { editor("输入文本")?.string == "" }
            editor("输入文本")!.insertText("a+b /", replacementRange: NSRange(location: 0, length: 0))
            try await waitUntil { editor("编码结果")?.string == "a%2Bb%20%2F" }
            selectTool("Base64")
            try await waitUntil { editor("输入文本")?.string == "hello" }
            selectTool("JSON")
            try await waitUntil { editor("JSON 输入")?.string == #"{"saved":1}"# }
            selectGroup(atTop: 84)
            try await waitUntil { editor("JSON 输入") == nil }
            selectGroup(atTop: 52)
            try await waitUntil { editor("JSON 输入")?.string == #"{"saved":1}"# }
            print("Native UI: category switching, top tabs, JSON/Base64/URL input/output and input retention passed")
        }

        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        precondition(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
        if name.hasPrefix("image-tools") { try assertImagePreviewColor(in: bitmap) }
        window.orderOut(nil)
    }

    @MainActor
    static func descendants<T: NSView>(_ view: NSView, of type: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, of: type) }
    }

    @MainActor
    static func click(_ point: NSPoint, in window: NSWindow) {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
            window.sendEvent(event)
        }
    }

    @MainActor
    static func testModeAndInputRetention() async throws {
        let model = JSONToolModel()
        model.leftText = #"{"x":1}"#
        model.rightText = #"{"x":2}"#
        model.mode = .compare
        try await waitUntil { model.differences.count == 1 }
        model.mode = .validate
        try await waitUntil { model.message == "JSON 有效" }
        precondition(model.rightText == #"{"x":2}"# && model.outputText.isEmpty)
        model.mode = .format
        try await waitUntil { model.outputText.contains("x") }
        model.mode = .compare
        try await waitUntil { model.differences.count == 1 }
        model.leftText = ""
        precondition(model.rightText == #"{"x":2}"#, "Clearing one side must preserve the other")
        precondition(model.differences.isEmpty, "Clearing a side invalidates old highlights immediately")
        model.leftText = "{"
        try await waitUntil { model.leftError != nil }
        precondition(model.leftError?.offset == 1)
    }

    @MainActor
    static func waitUntil(file: StaticString = #fileID, line: UInt = #line, _ condition: () -> Bool) async throws {
        for _ in 0..<150 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        preconditionFailure("Timed out waiting for UI state", file: file, line: line)
    }
}
