import AppKit
import ImageIO
import UniformTypeIdentifiers
import SwiftUI
import ToolboxImages
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func testImageOperationIsolation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NsToolBox-isolation-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("no-person.png")
        let second = directory.appendingPathComponent("convert.png")
        let context = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        let destination = CGImageDestinationCreateWithURL(first as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        try FileManager.default.copyItem(at: first, to: second)
        let workspace = ImageWorkspaceModel()
        let model = workspace.activeModel
        var window: NSWindow?
        if CommandLine.arguments.contains("--render") {
            let host = NSHostingView(rootView: ImageWorkspaceView(workspace: workspace))
            let visible = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 640),
                                   styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            visible.contentView = host
            visible.center(); visible.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window = visible
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        defer { window?.orderOut(nil) }
        func select(_ route: ImageToolRoute) async throws {
            if let window, let host = window.contentView {
                let index = ImageToolRoute.allCases.firstIndex(of: route)!
                click(host.convert(NSPoint(x: CGFloat(index) * 104 + 52,
                                           y: host.isFlipped ? 17 : host.bounds.height - 17), to: nil), in: window)
            } else { workspace.select(route) }
            try await waitUntil { workspace.selectedTool == route }
        }
        defer { ImageToolRoute.allCases.forEach { workspace.model(for: $0).clearAll() } }
        model.options.cutout = .person
        model.importURLs([first])
        try await waitUntil { !model.isBusy }
        model.processAll()
        try await waitUntil { !model.isBusy }
        guard model.items[0].state == .failed else { throw isolationError("Fixture must fail person extraction") }
        let cutoutError = model.items[0].error
        try await select(.format)
        let converter = workspace.activeModel
        guard converter.items.isEmpty else { throw isolationError("A new tool must have its own image list") }
        converter.importURLs([second])
        try await waitUntil { !converter.isBusy }
        converter.options.format = .jpeg
        // Irrelevant settings must never enter a standalone format operation.
        converter.options.cutout = .person
        converter.options.resize = .dimensions
        converter.options.width = 0
        converter.processAll()
        try await waitUntil { !converter.isBusy }
        guard let converted = converter.items.last, converted.state == .ready,
              converted.resultURL?.pathExtension == "jpg" else {
            throw isolationError("Format conversion must not run prior person extraction: " + (converter.items.last?.error ?? "no result"))
        }
        guard converter.items[0].resultWidth == 512, converter.items[0].resultHeight == 512 else {
            throw isolationError("Format conversion must preserve the original size")
        }
        try await select(.cutout)
        guard workspace.activeModel.items.count == 1, workspace.activeModel.items[0].error == cutoutError,
              workspace.activeModel.options.cutout == .person else {
            throw isolationError("Returning to cutout must preserve only that tool's state")
        }
        try await select(.format)
        workspace.useSelectedResult(in: .resize)
        let resizer = workspace.activeModel
        try await waitUntil { !resizer.isBusy }
        guard resizer.tool == .resize, resizer.items.count == 1,
              resizer.selectedItem?.name == "convert.jpg", !resizer.hasResults else {
            throw isolationError("Explicit handoff must select its independent input and wait for user execution")
        }
        let transferredSource = resizer.items[0].sourceURL!
        let transferredBytes = try Data(contentsOf: transferredSource)
        converter.options.format = .png
        converter.clearAll()
        guard try Data(contentsOf: transferredSource) == transferredBytes else {
            throw isolationError("Clearing the previous tool must not delete transferred input")
        }
        resizer.options.percentage = 50
        resizer.options.cutout = .person
        resizer.options.format = .png
        resizer.processAll()
        try await waitUntil { !resizer.isBusy }
        guard resizer.items[0].resultWidth == 256, resizer.items[0].resultFormat == .jpeg else {
            throw isolationError("Resizing must preserve input format and ignore cutout")
        }
        workspace.useSelectedResult(in: .compress)
        let compressor = workspace.activeModel
        try await waitUntil { !compressor.isBusy }
        compressor.options.cutout = .person
        compressor.options.resize = .percentage
        compressor.options.percentage = 1
        compressor.processAll()
        try await waitUntil { !compressor.isBusy }
        guard compressor.items[0].state == .ready, compressor.items[0].resultWidth == 256 else {
            throw isolationError("Compression must not resize or segment people")
        }
        try await select(.resize)
        resizer.options.percentage = 25
        resizer.processAll()
        try await waitUntil { !resizer.isBusy }
        workspace.useSelectedResult(in: .compress)
        try await waitUntil { !compressor.isBusy }
        guard compressor.items.count == 2, compressor.selectedItem?.info?.width == 128 else {
            throw isolationError("A regenerated result must import as a new snapshot and become selected")
        }
        try await select(.cutout)
        let gray = directory.appendingPathComponent("light-gray.png")
        context.setFillColor(CGColor(gray: 0.85, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        let grayOutput = CGImageDestinationCreateWithURL(gray as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(grayOutput, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(grayOutput))
        model.importURLs([gray])
        try await waitUntil { !model.isBusy }
        model.selection = model.items.last!.id
        model.options.cutout = .whiteBackground
        model.options.whiteTolerance = 0.2
        model.processAll()
        try await waitUntil { !model.isBusy }
        guard let data = model.selectedItem?.resultURL.flatMap({ try? Data(contentsOf: $0) }),
              let bitmap = NSBitmapImageRep(data: data), bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0 else {
            throw isolationError("Cutout must apply the selected white tolerance and export real transparency")
        }
        if CommandLine.arguments.contains("--render") {
            try await render(ImageWorkspaceView(workspace: workspace), name: "white-background-tool",
                             size: NSSize(width: 780, height: 640))
        }
        print("Image operation isolation: failed cutout then format, independent state, explicit snapshots, resize and compression passed")
    }

    static func isolationError(_ message: String) -> NSError {
        NSError(domain: "ImageOperationTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
