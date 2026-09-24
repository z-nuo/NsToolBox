import Foundation

public enum JSONParser {
    public static func parse(_ text: String) throws -> JSONDocument {
        var scanner = Scanner(text)
        let value = try scanner.value(at: JSONPath(), depth: 0)
        scanner.skipWhitespace()
        guard scanner.index == scanner.units.count else { throw scanner.error("JSON 结尾有多余内容") }
        return JSONDocument(value: value, ranges: scanner.ranges)
    }
}

private struct Scanner {
    let units: [UInt16]
    var index = 0
    var ranges: [JSONPath: NSRange] = [:]
    init(_ text: String) { units = Array(text.utf16) }
    var current: UInt16? { index < units.count ? units[index] : nil }

    mutating func skipWhitespace() {
        while let unit = current, [9, 10, 13, 32].contains(unit) { index += 1 }
    }

    func error(_ message: String, at position: Int? = nil) -> JSONParseError {
        let offset = position ?? index
        var line = 1, column = 1, previous: UInt16 = 0
        for unit in units.prefix(offset) {
            if unit == 13 { line += 1; column = 1 }
            else if unit == 10 { if previous != 13 { line += 1 }; column = 1 }
            else { column += 1 }
            previous = unit
        }
        return JSONParseError(message: message, line: line, column: column, offset: offset)
    }

    mutating func consume(_ unit: UInt16) -> Bool {
        guard current == unit else { return false }
        index += 1
        return true
    }

    mutating func require(_ unit: UInt16, _ message: String) throws {
        skipWhitespace()
        guard consume(unit) else { throw error(message) }
    }

    mutating func value(at path: JSONPath, depth: Int) throws -> JSONValue {
        guard depth <= 256 else { throw error("嵌套超过 256 层，无法处理") }
        skipWhitespace()
        let start = index
        let result: JSONValue
        switch current {
        case 123:
            index += 1
            var object: [String: JSONValue] = [:]
            skipWhitespace()
            if !consume(125) {
                repeat {
                    skipWhitespace()
                    let keyStart = index
                    let key = try string()
                    guard object[key] == nil else { throw error("重复字段：\(key)", at: keyStart) }
                    try require(58, "字段名后需要冒号")
                    let childPath = path.appending(.key(key))
                    object[key] = try value(at: childPath, depth: depth + 1)
                    // Include the key so empty strings/containers remain easy to identify.
                    ranges[childPath] = NSRange(location: keyStart, length: index - keyStart)
                    skipWhitespace()
                    if consume(125) { break }
                    try require(44, "对象字段之间需要逗号，或使用 } 结束对象")
                } while true
            }
            result = .object(object)
        case 91:
            index += 1
            var array: [JSONValue] = []
            skipWhitespace()
            if !consume(93) {
                repeat {
                    array.append(try value(at: path.appending(.index(array.count)), depth: depth + 1))
                    skipWhitespace()
                    if consume(93) { break }
                    try require(44, "数组元素之间需要逗号，或使用 ] 结束数组")
                } while true
            }
            result = .array(array)
        case 34: result = .string(try string())
        case 116: try literal("true"); result = .bool(true)
        case 102: try literal("false"); result = .bool(false)
        case 110: try literal("null"); result = .null
        case let unit? where unit == 45 || (48...57).contains(unit): result = .number(try number())
        default: throw error("需要 JSON 对象、数组、字符串、数字、布尔值或 null")
        }
        ranges[path] = NSRange(location: start, length: index - start)
        return result
    }

    mutating func string() throws -> String {
        let start = index
        guard consume(34) else { throw error("字段名必须使用双引号") }
        while let unit = current {
            if unit < 32 { throw error("字符串内不能包含未转义的控制字符") }
            index += 1
            if unit == 34 {
                let token = String(decoding: units[start..<index], as: UTF16.self)
                do { return try JSONDecoder().decode(String.self, from: Data(token.utf8)) }
                catch { throw self.error("字符串转义或 Unicode 序列无效", at: start) }
            }
            if unit == 92 {
                guard let escaped = current else { throw error("字符串转义不完整") }
                guard [34, 92, 47, 98, 102, 110, 114, 116, 117].contains(escaped) else { throw error("无效的转义字符") }
                index += 1
                if escaped == 117 {
                    for _ in 0..<4 {
                        guard let hex = current, (48...57).contains(hex) || (65...70).contains(hex) || (97...102).contains(hex) else { throw error("Unicode 转义需要四位十六进制数字") }
                        index += 1
                    }
                }
            }
        }
        throw error("字符串缺少结束双引号")
    }

    mutating func literal(_ literal: String) throws {
        for unit in literal.utf16 {
            guard consume(unit) else { throw error("需要 \(literal)") }
        }
    }

    mutating func number() throws -> JSONNumber {
        let start = index
        _ = consume(45)
        if !consume(48) {
            guard let digit = current, (49...57).contains(digit) else { throw error("无效的数字") }
            digits()
        }
        if consume(46) {
            let fraction = index
            digits()
            guard index > fraction else { throw error("小数点后需要数字") }
        }
        if consume(101) || consume(69) {
            if !consume(43) { _ = consume(45) }
            let exponent = index
            digits()
            guard index > exponent else { throw error("指数后需要数字") }
        }
        return JSONNumber(String(decoding: units[start..<index], as: UTF16.self))
    }

    mutating func digits() {
        while let unit = current, (48...57).contains(unit) { index += 1 }
    }
}
