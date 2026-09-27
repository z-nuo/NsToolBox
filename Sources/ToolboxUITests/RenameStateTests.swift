import Foundation
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func testRenameState() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("NsToolBox-rename-state-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let first = directory.appendingPathComponent("one.txt")
        let second = directory.appendingPathComponent("two.txt")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)
        let model = BatchRenameModel()
        model.importURLs([first, second])
        model.options.numberingEnabled = true
        model.options.prefix = "new-"
        precondition(model.preview.map(\.newName) == ["new-one1.txt", "new-two2.txt"])
        model.move(from: IndexSet(integer: 1), to: 0)
        precondition(model.preview.map(\.newName) == ["new-two1.txt", "new-one2.txt"], "sequence follows list order")
        model.execute()
        precondition(model.records.filter(\.succeeded).count == 2 && model.canUndo, "successful actions retained for undo")
        precondition(model.preview.map(\.originalName) == ["new-two1.txt", "new-one2.txt"], "successful paths remain visible in the list")
        precondition(model.logText.contains("new-two1.txt"), "actual operations are exportable")
        let logURL = directory.appendingPathComponent("operations.tsv")
        try model.exportLog(to: logURL)
        let exportedLog = try String(contentsOf: logURL, encoding: .utf8)
        precondition(exportedLog.contains("new-two1.txt"), "export writes actual operation log")
        model.execute()
        precondition(model.preview.map(\.originalName) == ["new-new-two11.txt", "new-new-one22.txt"], "second rename uses current paths")
        model.clear()
        precondition(model.canUndo && model.records.count == 4, "clearing selection preserves both undo steps")
        model.undoLast()
        precondition(manager.fileExists(atPath: first.path) && manager.fileExists(atPath: second.path), "undo after clearing selection restores files")
        precondition(!model.canUndo, "completed undo leaves no pending work")
        precondition(Set(model.records.map(\.id)).count == model.records.count, "execution and undo have distinct log identities")
        print("ToolboxUITests: rename state passed")
    }
}
