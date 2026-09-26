import Foundation
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
