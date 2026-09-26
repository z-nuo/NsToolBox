import Foundation
import ToolboxCore

extension CoreTestRunner {
    static func testPhaseOneUtilities() throws {
        let utc = try TimestampUtility.timeZone("UTC")
        check(try TimestampUtility.dateString(from: "0", unit: .seconds, timeZone: utc) == "1970-01-01 00:00:00", "epoch seconds")
        check(try TimestampUtility.dateString(from: "-1000", unit: .milliseconds, timeZone: utc) == "1969-12-31 23:59:59", "negative epoch milliseconds")
        check(try TimestampUtility.timestamp(from: "1970-01-01 08:00:00", unit: .seconds, timeZone: TimestampUtility.timeZone("Asia/Shanghai")) == "0", "explicit timezone")
        check(try TimestampUtility.timestamp(from: "1970-01-01 00:00:01", unit: .milliseconds, timeZone: utc) == "1000", "explicit milliseconds")
        for value in ["1.5", "", "999999999999999999999"] {
            expectError({ _ = try TimestampUtility.dateString(from: value, unit: .seconds, timeZone: utc) }, "invalid epoch \(value)")
        }
        expectError({ _ = try TimestampUtility.timestamp(from: "2024-02-30 12:00:00", unit: .seconds, timeZone: utc) }, "invalid calendar day")
        expectError({ _ = try TimestampUtility.timestamp(from: "2024-01-01 00:00:00 extra", unit: .seconds, timeZone: utc) }, "strict date")
        expectError({ _ = try TimestampUtility.timeZone("No/Such_Zone") }, "invalid timezone")
        let pacific = try TimestampUtility.timeZone("America/Los_Angeles")
        expectError({ _ = try TimestampUtility.timestamp(from: "2024-03-10 02:30:00", unit: .seconds, timeZone: pacific) }, "nonexistent spring time")
        expectError({ _ = try TimestampUtility.timestamp(from: "2024-11-03 01:30:00", unit: .seconds, timeZone: pacific) }, "ambiguous fall time")

        let ids = try UUIDUtility.generate(count: 64)
        check(ids.count == 64 && Set(ids).count == 64, "unique UUID batch")
        let pattern = try NSRegularExpression(pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
        check(ids.allSatisfy { pattern.firstMatch(in: $0, range: NSRange(location: 0, length: ($0 as NSString).length)) != nil }, "UUID v4 format")
        expectError({ _ = try UUIDUtility.generate(count: 0) }, "zero UUIDs")
        expectError({ _ = try UUIDUtility.generate(count: 1001) }, "oversized UUID batch")

        check(TextHashUtility.digest("abc", algorithm: .sha256) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256 vector")
        check(TextHashUtility.digest("abc", algorithm: .sha512) == "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f", "SHA-512 vector")
        check(TextHashUtility.digest("abc", algorithm: .sha1) == "a9993e364706816aba3e25717850c26c9cd0d89d", "SHA-1 vector")
        check(TextHashUtility.digest("abc", algorithm: .md5) == "900150983cd24fb0d6963f7d28e17f72", "MD5 vector")
        check(TextHashUtility.digest("中文😀", algorithm: .sha256) == "e973a1c1b41c5c9f4fbac31fcc311536dfffd003bfb914580455170a599953fa", "UTF-8 vector")

        let left = "😀same\nremove\nend"
        let right = "😀same\nadd\nend"
        let comparison = try TextComparison.compare(left, right)
        check(comparison.changes.count == 2, "one removal and one insertion")
        check(comparison.changes.map(\.kind) == [.removed, .added], "change order")
        check((left as NSString).substring(with: comparison.changes[0].leftRange!) == "remove\n", "UTF-16 removal range")
        check((right as NSString).substring(with: comparison.changes[1].rightRange!) == "add\n", "UTF-16 insertion range")
        check(try TextComparison.compare("same\n", "same\n").changes.isEmpty, "same input")
        expectError({ _ = try TextComparison.compare(String(repeating: "x", count: 131_073), "") }, "text size limit")
        expectError({ _ = try TextComparison.compare(String(repeating: "x\n", count: 2_001), "") }, "line count limit")
    }
}
