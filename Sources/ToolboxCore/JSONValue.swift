import Foundation

public indirect enum JSONValue: Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(JSONNumber)
    case bool(Bool)
    case null
}

/// Retains the original spelling and compares numbers without floating-point rounding.
public struct JSONNumber: Equatable, Sendable {
    public let rawValue: String
    private let canonical: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
        let parts = rawValue.lowercased().split(separator: "e")
        let negative = parts[0].hasPrefix("-")
        let mantissa = parts[0].filter { $0 != "-" }
        let fractionCount = mantissa.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
        var digits = Array(mantissa.filter { $0 != "." }.drop(while: { $0 == "0" }))
        if digits.isEmpty { canonical = "0"; return }
        var trailingZeros = 0
        while digits.last == "0" { digits.removeLast(); trailingZeros += 1 }
        let exponent = parts.count == 2 ? String(parts[1]) : "0"
        let normalizedExponent = Self.add(exponent, String(trailingZeros - fractionCount))
        canonical = (negative ? "-" : "") + String(digits) + "e" + normalizedExponent
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.canonical == rhs.canonical }

    // Exponents are unbounded decimal integers, too: 1e999… is still valid JSON.
    private static func add(_ lhs: String, _ rhs: String) -> String {
        func parts(_ text: String) -> (negative: Bool, digits: [Int]) {
            let digits = text.filter { $0 != "-" && $0 != "+" }.drop(while: { $0 == "0" }).compactMap(\.wholeNumberValue)
            return (text.hasPrefix("-") && !digits.isEmpty, digits.isEmpty ? [0] : digits)
        }
        let a = parts(lhs), b = parts(rhs)
        let aLarger = a.digits.count != b.digits.count ? a.digits.count > b.digits.count : !a.digits.lexicographicallyPrecedes(b.digits)
        let large = aLarger ? a : b, small = aLarger ? b : a
        let x = Array(large.digits.reversed()), y = Array(small.digits.reversed())
        var result: [Int] = [], carry = 0
        for i in x.indices {
            let value = x[i] + (a.negative == b.negative ? 1 : -1) * (i < y.count ? y[i] : 0) + carry
            if a.negative == b.negative {
                result.append(value % 10); carry = value / 10
            } else {
                result.append((value + 10) % 10); carry = value < 0 ? -1 : 0
            }
        }
        if carry > 0 { result.append(carry) }
        while result.count > 1 && result.last == 0 { result.removeLast() }
        let number = result.reversed().map(String.init).joined()
        return (large.negative && number != "0" ? "-" : "") + number
    }
}

public enum JSONPathComponent: Hashable, Sendable {
    case key(String)
    case index(Int)
}

public struct JSONPath: Hashable, Sendable, CustomStringConvertible {
    public let components: [JSONPathComponent]
    public init(_ components: [JSONPathComponent] = []) { self.components = components }
    public func appending(_ part: JSONPathComponent) -> Self { Self(components + [part]) }
    public var description: String {
        components.reduce("$") { path, component in
            switch component {
            case .index(let index): return path + "[\(index)]"
            case .key(let key):
                if key.range(of: "^[A-Za-z_][A-Za-z_0-9]*$", options: .regularExpression) != nil { return path + "." + key }
                return path + "[" + JSONWriter.quote(key) + "]"
            }
        }
    }
}

public struct JSONDocument: Sendable {
    public let value: JSONValue
    public let ranges: [JSONPath: NSRange]
}

public struct JSONParseError: Error, LocalizedError, Sendable {
    public let message: String
    public let line: Int
    public let column: Int
    public let offset: Int
    public var errorDescription: String? { "第 \(line) 行，第 \(column) 列：\(message)" }
}
