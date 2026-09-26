import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import ToolboxImages
@testable import ToolboxUI

extension StateTests {
    static func assertImagePreviewColor(in bitmap: NSBitmapImageRep) throws {
        // Sample the result pane only; labels, tab accents and the original image are outside it.
        var bluePixels = 0
        for y in stride(from: bitmap.pixelsHigh * 4 / 10, to: bitmap.pixelsHigh * 8 / 10, by: 4) {
            for x in stride(from: bitmap.pixelsWide * 7 / 10, to: bitmap.pixelsWide * 9 / 10, by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if color.blueComponent > color.redComponent + 0.3 { bluePixels += 1 }
            }
        }
        guard bluePixels > 100 else {
            throw NSError(domain: "ImagePreviewTest", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Result preview lost original blue pixels; found \(bluePixels)"])
        }
    }

    @MainActor
    static func imageTerminationProbe(directory: URL) async throws {
        let source = directory.appendingPathComponent("termination-source.png")
        try makeImageFixture(at: source)
        let model = ImageBatchModel()
        model.importURLs([source])
        try await waitUntil { !model.isBusy }
        let cache = model.items[0].sourceURL!.deletingLastPathComponent()
        try Data(cache.path.utf8).write(to: directory.appendingPathComponent("termination-cache.txt"))
        // Keep the model alive through an actual AppKit process termination, without relying on deinit.
        withExtendedLifetime(model) { NSApp.terminate(nil) }
    }

    @MainActor
    static func makeImageFixture(at url: URL) throws {
        let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 800,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.12, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 20, y: 15, width: 160, height: 70))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
    }

    @MainActor
    static func testImageBatch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NsToolBox-batch-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.png")
        let second = root.appendingPathComponent("second.png")
        let bad = root.appendingPathComponent("invalid.jpg")
        try makeImageFixture(at: source); try makeImageFixture(at: second)
        try Data("not an image".utf8).write(to: bad)
        let original = try Data(contentsOf: source)
        let model = ImageBatchModel()
        model.importURLs([source, source, bad, second])
        try await waitUntil { !model.isBusy }
        precondition(model.items.count == 3 && model.items.filter { $0.state == .failed }.count == 1)
        precondition(model.items[0].info?.width == 200 && model.items[0].info?.thumbnailData.isEmpty == true)
        let snapshot = model.items[0].sourceURL!
        precondition(snapshot != source && FileManager.default.fileExists(atPath: snapshot.path))
        model.importURLs([source])
        precondition(model.items.count == 3 && !model.isBusy)
        model.options.format = .jpeg
        model.options.resize = .percentage
        model.options.percentage = 50
        model.processAll()
        try await waitUntil { !model.isBusy }
        precondition(model.items.filter { $0.state == .ready }.count == 2, "An invalid item must not prevent other images from processing")
        precondition(model.items[0].resultWidth == 100 && model.items[0].resultHeight == 50)
        model.export(to: root.appendingPathComponent("does-not-exist"))
        try await waitUntil { !model.isBusy }
        precondition(model.items[0].error?.hasPrefix("导出失败") == true && model.hasResults)
        model.export(to: root)
        try await waitUntil { !model.isBusy }
        let firstExport = model.items[0].exportedURL!
        let firstBytes = try Data(contentsOf: firstExport)
        model.export(to: root)
        try await waitUntil { !model.isBusy }
        precondition(model.items[0].exportedURL != firstExport, "Repeated exports must not replace an existing file")
        let stillFirstBytes = try Data(contentsOf: firstExport)
        let stillOriginal = try Data(contentsOf: source)
        precondition(stillFirstBytes == firstBytes && stillOriginal == original)
        model.options.percentage = 25
        precondition(!model.hasResults && model.items[0].resultPreviewURL == nil)
        model.processAll(); model.cancel()
        try await waitUntil { !model.isBusy }
        precondition(!model.isCancelling && model.items.allSatisfy { $0.state != .processing })
        model.processAll()
        try await waitUntil { !model.isBusy }
        precondition(model.items[0].resultWidth == 50 && model.items[0].resultHeight == 25)
        if CommandLine.arguments.contains("--render") {
            try await render(ImageToolView(model: model), name: "image-tools", size: NSSize(width: 780, height: 640))
            model.selectedTool = .resize
            try await render(ImageToolView(model: model), name: "image-tools-dark", size: NSSize(width: 780, height: 640), dark: true)
        }
        model.selection = model.items[0].id
        model.removeSelected()
        precondition(!FileManager.default.fileExists(atPath: snapshot.path))
        model.clearAll()
        precondition(model.items.isEmpty && FileManager.default.fileExists(atPath: source.path))
        model.importURLs([second])
        try await waitUntil { !model.isBusy }
        let sessionDirectory = model.items[0].sourceURL!.deletingLastPathComponent()
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: NSApp)
        precondition(!FileManager.default.fileExists(atPath: sessionDirectory.path), "Termination notification must synchronously remove the session cache")
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = ["--image-termination-probe", root.path]
        try child.run()
        try await waitUntil { !child.isRunning }
        precondition(child.terminationStatus == 0)
        let childCache = try String(contentsOf: root.appendingPathComponent("termination-cache.txt"), encoding: .utf8)
        precondition(!FileManager.default.fileExists(atPath: childCache), "Actual AppKit termination must remove private source and result cache")
        print("Image batch: deduplication, invalid input isolation, resizing, retry, non-overwrite export, cancellation and cache cleanup passed")
    }
}
