import Foundation
import ToolboxCore

@main
struct CoreTestRunner {
    static func main() throws {
        try testFormatPreservesUnicodeAndLargeNumbers()
        try testRootScalarsAndEscapes()
        try testRejectsMalformedJSON()
        try testErrorLocationAndDepthLimit()
        try testBase64TextAndWhitespace()
        try testURLComponentSemantics()
        try testStructuredDiff()
        try testNumericEquality()
        try testDiffRangesAndSpecialPaths()
        try testArrayAndRootDifferences()
        try testHugeExponentsAndPreciseIntegers()
        print("ToolboxCoreTests: 11 groups passed")
    }

    static func check(_ condition: Bool, _ message: String) {
        precondition(condition, message)
    }

    static func expectError(_ operation: () throws -> Void, _ message: String) {
        do { try operation(); preconditionFailure("expected error: \(message)") }
        catch { }
    }

    static func testFormatPreservesUnicodeAndLargeNumbers() throws {
        let source = #"{"z":"中文😀","a":12345678901234567890123456789012345678901234567890,"b":1e400}"#
        let value = try JSONParser.parse(source).value
        check(JSONWriter.write(value, pretty: false) == #"{"a":12345678901234567890123456789012345678901234567890,"b":1e400,"z":"中文😀"}"#, "stable JSON output")
        let prettyValue = try JSONParser.parse(JSONWriter.write(value, pretty: true)).value
        check(prettyValue == value, "pretty round trip")
    }

    static func testRootScalarsAndEscapes() throws {
        for source in ["null", "true", "false", "-0.25e+3", #""a\n\t\"\\\uD83D\uDE00""#, "[]", "{}"] {
            let value = try JSONParser.parse(source).value
            let roundTripped = try JSONParser.parse(JSONWriter.write(value, pretty: false)).value
            check(roundTripped == value, "round trip \(source)")
        }
        let trueValue = try JSONParser.parse("true").value
        let numberValue = try JSONParser.parse("1").value
        check(trueValue != numberValue, "scalar types")
    }

    static func testRejectsMalformedJSON() throws {
        for source in ["", " ", "01", "+1", "1.", "1e", "NaN", "[1,]", #"{"a":1,}"#, #"{"a":1,"a":2}"#, "{}x", #""\x""#, #""\uD800""#, "\"a\nb\""] {
            expectError({ _ = try JSONParser.parse(source) }, source)
        }
    }

    static func testErrorLocationAndDepthLimit() throws {
        expectError({ _ = try JSONParser.parse("{\n  \"a\": }") }, "line and column")
        do { _ = try JSONParser.parse("{\n  \"a\": }"); preconditionFailure("expected location error") }
        catch let error as JSONParseError { check(error.line == 2 && error.column == 8, "line and column") }
        catch { preconditionFailure("wrong error type") }
        expectError({ _ = try JSONParser.parse(String(repeating: "[", count: 520) + "0" + String(repeating: "]", count: 520)) }, "depth")
    }

    static func testBase64TextAndWhitespace() throws {
        check(try TextCodec.encode("中文", kind: .base64) == "5Lit5paH", "base64 encode")
        check(try TextCodec.decode("5Li t\n5paH\r\n", kind: .base64) == "中文", "base64 whitespace")
        check(try TextCodec.decode("", kind: .base64) == "", "base64 empty")
        for source in ["???", "A", "AB==", "Zg=", "/w=="] { expectError({ _ = try TextCodec.decode(source, kind: .base64) }, source) }
    }

    static func testURLComponentSemantics() throws {
        check(try TextCodec.encode("a+b /?=中文", kind: .url) == "a%2Bb%20%2F%3F%3D%E4%B8%AD%E6%96%87", "url encode")
        check(try TextCodec.decode("a+b%20%2F", kind: .url) == "a+b /", "url decode")
        for source in ["%", "%2", "%GG", "%FF"] { expectError({ _ = try TextCodec.decode(source, kind: .url) }, source) }
    }

    static func testStructuredDiff() throws {
        let left = try JSONParser.parse(#"{"a":1,"b":[true,2]}"#)
        let right = try JSONParser.parse(#"{"b":[false,2,3],"a":1.0}"#)
        let changes = JSONDiff.compare(left, right)
        check(changes.map(\.path.description) == ["$.b[0]", "$.b[2]"], "diff paths")
        check(changes.map(\.kind) == [.modified, .added], "diff kinds")
    }

    static func testNumericEquality() throws {
        let equalPairs = [("1", "1.0"), ("1e2", "100"), ("-0", "0"), ("1e-2", "0.01"), ("1e400", "10e399")]
        for (lhs, rhs) in equalPairs {
            let left = try JSONParser.parse(lhs).value
            let right = try JSONParser.parse(rhs).value
            check(left == right, "numeric equality \(lhs) == \(rhs)")
        }
        let high = try JSONParser.parse("1e400").value
        let lower = try JSONParser.parse("1e399").value
        check(high != lower, "numeric inequality")
    }

    static func testDiffRangesAndSpecialPaths() throws {
        let leftText = #"{"emoji":"😀","a.b":[{"x":"旧"}]}"#
        let rightText = #"{"emoji":"😀","a.b":[{"x":"新"}]}"#
        let changes = JSONDiff.compare(try JSONParser.parse(leftText), try JSONParser.parse(rightText))
        check(changes.count == 1, "one nested modification")
        let change = changes[0]
        check(change.path.description == #"$["a.b"][0].x"#, "escaped path components")
        check((leftText as NSString).substring(with: change.leftRange!) == #""x":"旧""#, "UTF-16 left range after emoji")
        check((rightText as NSString).substring(with: change.rightRange!) == #""x":"新""#, "UTF-16 right range after emoji")
        check(change.leftRange!.location == (leftText as NSString).range(of: #""x":"旧""#).location, "exact range offset")
    }

    static func testArrayAndRootDifferences() throws {
        let reordered = JSONDiff.compare(try JSONParser.parse("[1,2]"), try JSONParser.parse("[2,1]"))
        check(reordered.map(\.path.description) == ["$[0]", "$[1]"], "arrays compare by index")
        let removed = JSONDiff.compare(try JSONParser.parse("[1,2]"), try JSONParser.parse("[1]"))
        check(removed.count == 1 && removed[0].kind == .removed && removed[0].rightRange == nil, "array removal")
        let changedRoot = JSONDiff.compare(try JSONParser.parse("{}"), try JSONParser.parse("[]"))
        check(changedRoot.count == 1 && changedRoot[0].path.description == "$", "root type changes")
        let reorderedKeys = JSONDiff.compare(try JSONParser.parse(#"{"a":1,"b":null}"#), try JSONParser.parse(#"{"b":null,"a":1.0}"#))
        check(reorderedKeys.isEmpty, "key order ignored")
        let added = JSONDiff.compare(try JSONParser.parse("{}"), try JSONParser.parse(#"{"a":{}}"#))
        check(added.count == 1 && added[0].kind == .added && added[0].leftRange == nil, "empty container addition")
        let empty = JSONDiff.compare(try JSONParser.parse("[]"), try JSONParser.parse("[]"))
        check(empty.isEmpty, "empty arrays")
    }

    static func testHugeExponentsAndPreciseIntegers() throws {
        let pairs = [("100e-999999999999999999999", "1e-999999999999999999997"),
                     ("0.1e999999999999999999999", "1e999999999999999999998"),
                     ("100e-1", "10"), ("0.0001e4", "1"), ("-10.000", "-1e1")]
        for (a, b) in pairs {
            let lhs = try JSONParser.parse(a).value
            let rhs = try JSONParser.parse(b).value
            check(lhs == rhs, "exact exponent arithmetic")
        }
        let lhs = try JSONParser.parse("12345678901234567890123456789012345678901234567890").value
        let rhs = try JSONParser.parse("12345678901234567890123456789012345678901234567891").value
        check(lhs != rhs, "adjacent integers beyond Decimal precision")
    }
}
