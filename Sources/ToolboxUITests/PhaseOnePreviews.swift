import Foundation
import SwiftUI
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func renderPhaseOnePreviews() async throws {
        let time = TimestampToolModel()
        time.timeZoneID = "Asia/Shanghai"
        time.epochInput = "0"
        time.dateInput = "2026-09-26 12:30:00"
        try await render(TimestampToolView(model: time), name: "timestamp-tool", size: NSSize(width: 780, height: 600))
        let uuid = UUIDToolModel()
        uuid.countInput = "5"
        uuid.generate()
        try await render(UUIDToolView(model: uuid), name: "uuid-tool", size: NSSize(width: 780, height: 600))
        let hash = HashToolModel()
        hash.input = "NsToolBox · 中文😀"
        try await render(HashToolView(model: hash), name: "hash-tool", size: NSSize(width: 780, height: 600), dark: true)
        let comparison = TextCompareModel()
        comparison.leftText = "name=NsToolBox\nversion=1\nimage=true\n"
        comparison.rightText = "name=NsToolBox\nversion=2\nimage=true\nfiles=true\n"
        try await waitUntil { !comparison.isProcessing }
        try await render(TextCompareView(model: comparison), name: "text-compare", size: NSSize(width: 780, height: 600))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NsToolBox-rename-preview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = ["素材一.txt", "素材二.txt"].map { directory.appendingPathComponent($0) }
        for file in files { try Data("preview".utf8).write(to: file) }
        let rename = BatchRenameModel()
        rename.importURLs(files)
        rename.options.prefix = "项目-"
        rename.options.numberingEnabled = true
        try await render(BatchRenameView(model: rename), name: "batch-rename", size: NSSize(width: 780, height: 600))
    }
}
