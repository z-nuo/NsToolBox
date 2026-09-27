import AppKit
import ImageIO
import ToolboxImages
@testable import ToolboxUI
import UniformTypeIdentifiers

extension StateTests {
    @MainActor
    static func testImageEditingSessions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NsToolBox-edit-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("color-grid.png")
        let pixels: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
                               255, 255, 0, 255, 255, 0, 255, 255, 0, 0, 0, 0]
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: 3, height: 2, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: 12, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let encoder = CGImageDestinationCreateWithURL(input as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(encoder, image, nil)
        guard CGImageDestinationFinalize(encoder) else { throw isolationError("Failed to create image editing fixture") }

        let workspace = ImageWorkspaceModel()
        workspace.select(.info)
        let info = workspace.activeModel
        info.importURLs([input])
        try await waitUntil { !info.isBusy }
        guard info.selectedItem?.info?.transparency == .containsTransparentPixels,
              info.selectedItem?.state == .read,
              info.selectedItem?.info?.width == 3, !info.canProcess, !info.hasResults else {
            throw isolationError("Information route must inspect actual pixels without a processing result")
        }
        workspace.select(.edit)
        let editor = workspace.activeModel
        guard editor.items.isEmpty else { throw isolationError("Editing must have a separate input list") }
        editor.importURLs([input])
        try await waitUntil { !editor.isBusy }
        editor.editOptions = ImageEditOptions(crop: ImagePixelRect(x: 1, y: 0, width: 2, height: 2), quarterTurns: 1)
        editor.processAll()
        try await waitUntil { !editor.isBusy }
        guard editor.selectedItem?.state == .ready, editor.selectedItem?.resultWidth == 2,
              editor.selectedItem?.resultHeight == 2, editor.selectedItem?.resultFormat == .png,
              let result = editor.selectedItem?.resultURL else {
            throw isolationError("Editing must produce previewable PNG with transformed dimensions: " + (editor.selectedItem?.error ?? "missing result"))
        }
        guard let source = CGImageSourceCreateWithURL(result as CFURL, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil), decoded.width == 2 else {
            throw isolationError("Edited result must be a real decodable file")
        }
        workspace.select(.info)
        guard workspace.activeModel.selectedItem?.info?.transparency == .containsTransparentPixels,
              !workspace.activeModel.hasResults else {
            throw isolationError("Switching tools must preserve independent information state")
        }
        if CommandLine.arguments.contains("--render") {
            workspace.select(.edit)
            try await render(ImageWorkspaceView(workspace: workspace), name: "image-edit-tool")
            workspace.select(.info)
            try await render(ImageWorkspaceView(workspace: workspace), name: "image-info-tool")
        }
        editor.clearAll(); info.clearAll()
    }
}
