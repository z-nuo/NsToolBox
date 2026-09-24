import Foundation

public enum JSONWriter {
    public static func write(_ value: JSONValue, pretty: Bool) -> String {
        render(value, pretty: pretty, level: 0)
    }

    static func quote(_ string: String) -> String {
        // Encoding a single string cannot fail for a valid Swift String.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try! encoder.encode(string), as: UTF8.self)
    }

    private static func render(_ value: JSONValue, pretty: Bool, level: Int) -> String {
        switch value {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .number(let value): return value.rawValue
        case .string(let value): return quote(value)
        case .object(let object):
            let entries = object.keys.sorted().map { key in
                quote(key) + (pretty ? ": " : ":") + render(object[key]!, pretty: pretty, level: level + 1)
            }
            return container(entries, open: "{", close: "}", pretty: pretty, level: level)
        case .array(let array):
            return container(array.map { render($0, pretty: pretty, level: level + 1) }, open: "[", close: "]", pretty: pretty, level: level)
        }
    }

    private static func container(_ entries: [String], open: String, close: String, pretty: Bool, level: Int) -> String {
        guard !entries.isEmpty else { return open + close }
        guard pretty else { return open + entries.joined(separator: ",") + close }
        let indent = String(repeating: "  ", count: level + 1)
        return open + "\n" + entries.map { indent + $0 }.joined(separator: ",\n") + "\n" + String(repeating: "  ", count: level) + close
    }
}
