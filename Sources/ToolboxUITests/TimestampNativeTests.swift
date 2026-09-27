import AppKit
import SwiftUI
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func testTimestampNative() async throws {
        let model = TimestampToolModel()
        model.timeZoneID = "UTC"
        model.unit = .milliseconds
        let host = NSHostingView(rootView: TimestampToolView(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(300))
        host.layoutSubtreeIfNeeded()
        func field(_ placeholder: String) -> NSTextField {
            descendants(host, of: NSTextField.self).first { $0.isEditable && $0.placeholderString == placeholder }!
        }
        func type(_ value: String, into field: NSTextField) {
            window.makeFirstResponder(field)
            let editor = field.currentEditor() as! NSTextView
            editor.selectAll(nil)
            editor.insertText(value, replacementRange: editor.selectedRange())
        }
        type("-1", into: field("整数时间戳（毫秒）"))
        try await waitUntil { model.dateOutput == "1969-12-31 23:59:59.999" }
        type("1970-01-01T08:00:00.123+08:00", into: field("yyyy-MM-dd HH:mm:ss[.SSS]"))
        try await waitUntil { model.epochOutput == "123" }
        type("bad", into: field("整数时间戳（毫秒）"))
        try await waitUntil { model.isError && model.epochOutput == "123" }
        model.timeZoneID = "Asia/Shanghai"
        type("1900-01-01 00:00:00", into: field("yyyy-MM-dd HH:mm:ss[.SSS]"))
        try await waitUntil { model.dateError.isEmpty && model.epochOutput.hasPrefix("-") }
        model.timeZoneID = "UTC"
        type("1970-01-01T08:00:00.123+08:00", into: field("yyyy-MM-dd HH:mm:ss[.SSS]"))
        try await waitUntil { model.epochOutput == "123" }
        // Segmented modes occupy the second toolbar row, preserving the native click path.
        func clickAtTop(x: CGFloat, y: CGFloat) {
            let point = host.convert(NSPoint(x: x, y: host.isFlipped ? y : host.bounds.height - y), to: nil)
            func event(_ type: NSEvent.EventType) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
            }
            // AppKit segmented controls enter a tracking loop during mouseDown.
            NSApp.postEvent(event(.leftMouseDown), atStart: false)
            NSApp.postEvent(event(.leftMouseUp), atStart: false)
        }
        func selectMode(_ index: Int) {
            let control = descendants(host, of: NSSegmentedControl.self).first { $0.segmentCount == 3 }!
            let rect = control.convert(control.bounds, to: host)
            clickAtTop(x: rect.minX + rect.width * (CGFloat(index) + 0.5) / 3,
                       y: host.isFlipped ? rect.midY : host.bounds.height - rect.midY)
        }
        window.makeFirstResponder(nil)
        try await Task.sleep(for: .milliseconds(150))
        host.layoutSubtreeIfNeeded()
        selectMode(1)
        try await waitUntil { model.mode == .batch }
        try await Task.sleep(for: .milliseconds(100))
        let input = descendants(host, of: NSTextView.self).first { $0.accessibilityLabel() == "批量输入" }!
        input.insertText("0\nbad\n-1", replacementRange: NSRange(location: 0, length: 0))
        try await waitUntil { model.batchInput == "0\nbad\n-1" }
        // The conversion button is the trailing control in the timezone row.
        clickAtTop(x: 750, y: 81)
        try await waitUntil { model.batchOutput.contains("1969-12-31 23:59:59.999") }
        precondition(model.batchHasError)
        try await Task.sleep(for: .milliseconds(150))
        host.layoutSubtreeIfNeeded()
        selectMode(0)
        try await waitUntil { model.mode == .convert }
        precondition(model.epochInput == "bad" && model.epochOutput == "123")
        print("Native timestamp: typing, local year boundary, independent errors, mode retention and batch action passed")
    }
}
