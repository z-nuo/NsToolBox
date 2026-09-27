import Foundation
import ToolboxCore
@testable import ToolboxUI

extension StateTests {
    @MainActor
    static func testPhaseOneUtilityState() async throws {
        let timestamp = TimestampToolModel()
        timestamp.timeZoneID = "UTC"
        timestamp.epochInput = "0"
        precondition(timestamp.dateOutput == "1970-01-01 00:00:00")
        timestamp.epochInput = "bad"
        precondition(timestamp.dateOutput.isEmpty && timestamp.isError, "Invalid epoch must clear old output")
        timestamp.epochInput = "0"
        timestamp.timeZoneID = "No/Such_Zone"
        precondition(timestamp.dateOutput.isEmpty && timestamp.isError, "Invalid zone must clear old output")

        timestamp.timeZoneID = "UTC"
        timestamp.dateInput = "1970-01-01 00:00:01"
        timestamp.epochInput = "bad"
        precondition(timestamp.epochOutput == "1", "Invalid epoch must not erase valid reverse conversion")

        timestamp.unit = .milliseconds
        timestamp.epochInput = "-1"
        timestamp.format = .iso8601
        precondition(timestamp.dateOutput == "1969-12-31T23:59:59.999Z")
        timestamp.isClockPaused = true
        timestamp.now = Date(timeIntervalSince1970: 1.125)
        timestamp.fillCurrent()
        precondition(timestamp.epochInput == "1125" && timestamp.dateInput == "1970-01-01T00:00:01.125Z")
        timestamp.mode = .batch
        timestamp.batchInput = "0\nbad\n-1"
        timestamp.convertBatch()
        try await waitUntil { !timestamp.isProcessing }
        precondition(timestamp.batchOutput.hasPrefix("1970-01-01T00:00:00.000Z") && timestamp.isError)
        timestamp.batchInput = "1"
        precondition(timestamp.batchOutput.isEmpty && !timestamp.isError, "Edits invalidate previous batch output")
        timestamp.batchInput = Array(repeating: "0", count: 1000).joined(separator: "\n")
        timestamp.convertBatch()
        timestamp.timeZoneID = "Asia/Shanghai"
        try await waitUntil { !timestamp.isProcessing }
        precondition(timestamp.batchOutput.isEmpty, "Stale background batch must not overwrite changed settings")
        timestamp.batchInput = "1970-01-01T00:00:01.125Z"
        timestamp.direction = .toTimestamp
        timestamp.convertBatch()
        try await waitUntil { !timestamp.isProcessing }
        precondition(timestamp.batchOutput == "1125")
        timestamp.mode = .difference
        timestamp.startInput = "1970-01-01T00:00:01.125Z"
        timestamp.endInput = "1970-01-01T00:00:01.001Z"
        precondition(timestamp.differenceOutput.contains("总毫秒：-124") && timestamp.differenceOutput.contains("总秒数：-0.124"))
        timestamp.endInput = "invalid"
        precondition(timestamp.differenceOutput.isEmpty && timestamp.isError)
        timestamp.mode = .convert
        precondition(timestamp.epochInput == "1125" && !timestamp.dateOutput.isEmpty, "Modes preserve independent inputs")

        let uuid = UUIDToolModel()
        uuid.countInput = "3"
        uuid.generate()
        precondition(uuid.output.split(separator: "\n").count == 3)
        uuid.countInput = "1001"
        uuid.generate()
        precondition(uuid.output.isEmpty && uuid.isError, "Invalid count must clear old UUIDs")

        let hash = HashToolModel()
        hash.input = "abc"
        precondition(hash.output == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        hash.algorithm = .md5
        precondition(hash.output == "900150983cd24fb0d6963f7d28e17f72", "Algorithm change must recompute")
        hash.input = String(repeating: "x", count: 2_097_153)
        precondition(hash.output.isEmpty && hash.isError, "Oversized hash input must clear old result")

        let compare = TextCompareModel()
        compare.leftText = "a\nold\n"
        compare.rightText = "a\nnew\n"
        try await waitUntil { compare.changes.count == 2 }
        compare.rightText = "a\n"
        precondition(compare.changes.isEmpty, "Input change must clear stale highlights immediately")
        compare.rightText = "a\nnewer\n"
        try await waitUntil { compare.changes.count == 2 }
        precondition(compare.changes[1].rightRange != nil)
        precondition(compare.navigate(-1)?.kind == .added, "First previous navigation must wrap to final difference")
        precondition(compare.navigate(1)?.kind == .removed, "Next navigation must wrap to first difference")
        compare.leftText = String(repeating: "x", count: 131_073)
        try await waitUntil { compare.isError }
        precondition(compare.changes.isEmpty, "Oversized input must not retain old ranges")
    }
}
