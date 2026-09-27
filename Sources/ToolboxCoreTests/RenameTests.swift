import Foundation
import ToolboxCore

extension CoreTestRunner {
    static func testBatchRename() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("NsToolBox-rename-tests-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        func file(_ name: String, _ value: String = "original") throws -> URL {
            let url = directory.appendingPathComponent(name)
            try Data(value.utf8).write(to: url)
            return url
        }
        let numberA = try file("number-a.txt")
        let numberB = try file("number-b.txt")
        let wideNumber = BatchRename.preview(urls: [numberA], options: BatchRenameOptions(numberingEnabled: true, numberStart: Int.max, numberPadding: 12))
        check(wideNumber[0].newName == "number-a\(Int.max).txt" && wideNumber[0].isReady, "large sequence number is not truncated")
        let overflow = BatchRename.preview(urls: [numberA, numberB], options: BatchRenameOptions(numberingEnabled: true, numberStart: Int.max))
        check(overflow[0].isReady && !overflow[1].isReady && overflow[1].issue == "序号超出可用范围", "sequence overflow is explicit")
        let padded = BatchRename.preview(urls: [numberA], options: BatchRenameOptions(numberingEnabled: true, numberStart: 9, numberPadding: 5))
        check(padded[0].newName == "number-a00009.txt", "sequence zero padding")
        let chinese = try file("中文😀.txt")
        let second = try file("second.txt")
        var options = BatchRenameOptions(prefix: "前-", suffix: "-后", searchText: "中文", replacementText: "汉字", numberingEnabled: true, numberStart: 3, numberPadding: 2)
        let preview = BatchRename.preview(urls: [chinese, second], options: options)
        check(preview.map(\.newName) == ["前-汉字😀-后03.txt", "前-second-后04.txt"], "rename preview preserves extensions and sorted numbering")
        check(preview.allSatisfy(\.isReady), "valid rename preview")
        let outcome = BatchRename.execute(preview: preview)
        check(outcome.filter(\.succeeded).count == 2 && outcome.allSatisfy(\.canUndo), "execute both files with original identities retained")
        check(!manager.fileExists(atPath: chinese.path), "original path no longer exists")
        let renamed = directory.appendingPathComponent("前-汉字😀-后03.txt")
        check(manager.fileExists(atPath: renamed.path), "renamed path exists")
        let undone = BatchRename.undo(records: outcome)
        check(undone.filter(\.succeeded).count == 2 && manager.fileExists(atPath: chinese.path), "session undo restores files")

        options = BatchRenameOptions(prefix: "z", searchText: "a", replacementText: "", numberingEnabled: false)
        let duplicate = BatchRename.preview(urls: [try file("a.txt"), try file("aa.txt")], options: options)
        check(duplicate.allSatisfy { !$0.isReady }, "duplicate targets are blocked")
        let occupied = try file("blocked.txt")
        let occupiedPreview = BatchRename.preview(urls: [second], options: BatchRenameOptions(prefix: "blocked", searchText: "second", replacementText: ""))
        check(!occupiedPreview[0].isReady && manager.fileExists(atPath: occupied.path), "existing target is blocked")

        let changing = try file("changing.txt")
        let stale = BatchRename.preview(urls: [changing], options: BatchRenameOptions(prefix: "new-"))
        try Data("changed".utf8).write(to: changing)
        let staleResult = BatchRename.execute(preview: stale)
        check(!staleResult[0].succeeded && manager.fileExists(atPath: changing.path), "external edits invalidate preview")

        let undoInput = try file("undo.txt")
        let undoPreview = BatchRename.preview(urls: [undoInput], options: BatchRenameOptions(prefix: "new-"))
        let undoRecord = BatchRename.execute(preview: undoPreview)
        let undoTarget = directory.appendingPathComponent("new-undo.txt")
        try manager.removeItem(at: undoTarget)
        try Data("replacement".utf8).write(to: undoTarget)
        let refusedUndo = BatchRename.undo(records: undoRecord)
        let replacementData = try Data(contentsOf: undoTarget)
        check(!refusedUndo[0].succeeded && String(data: replacementData, encoding: .utf8) == "replacement", "undo must leave replacement file untouched")

        let partA = try file("part-a.txt")
        let partB = try file("part-b.txt")
        let partialPreview = BatchRename.preview(urls: [partA, partB], options: BatchRenameOptions(prefix: "done-"))
        let occupiedDuringRun = try file("done-part-b.txt", "external")
        let partial = BatchRename.execute(preview: partialPreview)
        check(partial.map(\.succeeded) == [true, false], "partial execution reports each actual outcome")
        check(manager.fileExists(atPath: occupiedDuringRun.path) && manager.fileExists(atPath: partB.path), "competing target and failed source untouched")
        let partialUndo = BatchRename.undo(records: partial)
        check(partialUndo.count == 1 && partialUndo[0].succeeded && manager.fileExists(atPath: partA.path), "successful subset remains undoable")

        let occupiedOriginal = try file("undo-occupied.txt")
        let occupiedOriginalResult = BatchRename.execute(preview: BatchRename.preview(urls: [occupiedOriginal], options: BatchRenameOptions(prefix: "done-")))
        try Data("external".utf8).write(to: occupiedOriginal)
        let occupiedOriginalUndo = BatchRename.undo(records: occupiedOriginalResult)
        check(!occupiedOriginalUndo[0].succeeded && manager.fileExists(atPath: directory.appendingPathComponent("done-undo-occupied.txt").path), "undo refuses occupied original name")

        let chainOriginal = try file("chain.txt")
        let chainFirst = BatchRename.execute(preview: BatchRename.preview(urls: [chainOriginal], options: BatchRenameOptions(prefix: "first-")))
        let chainMiddle = directory.appendingPathComponent("first-chain.txt")
        let chainSecond = BatchRename.execute(preview: BatchRename.preview(urls: [chainMiddle], options: BatchRenameOptions(prefix: "second-")))
        var chainPending = chainFirst + chainSecond
        let chainUndo = BatchRename.undo(records: &chainPending)
        check(chainUndo.count == 2 && chainUndo.allSatisfy(\.succeeded) && chainPending.isEmpty && manager.fileExists(atPath: chainOriginal.path), "two-step rename chain undoes to original")

        let editedChainOriginal = try file("edited-chain.txt", "before")
        let editedChainFirst = BatchRename.execute(preview: BatchRename.preview(urls: [editedChainOriginal], options: BatchRenameOptions(prefix: "first-")))
        let editedChainMiddle = directory.appendingPathComponent("first-edited-chain.txt")
        try Data("modified between steps".utf8).write(to: editedChainMiddle)
        let editedChainSecond = BatchRename.execute(preview: BatchRename.preview(urls: [editedChainMiddle], options: BatchRenameOptions(prefix: "second-")))
        var editedChainPending = editedChainFirst + editedChainSecond
        let editedChainUndo = BatchRename.undo(records: &editedChainPending)
        check(editedChainUndo.map(\.succeeded) == [true, false], "later rename can undo but earlier pre-edit state cannot")
        check(editedChainPending.count == 1 && editedChainPending[0].operationID == editedChainFirst[0].operationID, "unsafe earlier undo stays pending")
        check(manager.fileExists(atPath: editedChainMiddle.path) && !manager.fileExists(atPath: editedChainOriginal.path), "external edit is not rolled back to original name")

        let symlink = directory.appendingPathComponent("link.txt")
        try manager.createSymbolicLink(at: symlink, withDestinationURL: second)
        check(!BatchRename.preview(urls: [symlink], options: BatchRenameOptions(prefix: "new-")).first!.isReady, "symlinks rejected")
        check(!BatchRename.preview(urls: [directory], options: BatchRenameOptions(prefix: "new-")).first!.isReady, "directories rejected")
        print("ToolboxCoreTests: batch rename passed")
    }
}
