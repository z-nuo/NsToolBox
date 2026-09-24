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
        print("ToolboxCoreTests: 7 passed")
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
}
