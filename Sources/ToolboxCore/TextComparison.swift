import Foundation

public enum TextComparisonError: Error, LocalizedError {
    case tooLarge, tooManyLines
    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "每侧文本最多 128 KB（UTF-8）"
        case .tooManyLines: return "每侧文本最多 2000 行"
        }
    }
}

public enum TextChangeKind: Equatable { case added, removed }

public struct TextLineChange {
    public let kind: TextChangeKind
    public let leftLine: Int?
    public let rightLine: Int?
    public let leftRange: NSRange?
    public let rightRange: NSRange?
}

public struct TextComparisonResult {
    public let changes: [TextLineChange]
}

public enum TextComparison {
    public static let maximumBytes = 128 * 1024
    public static let maximumLines = 2000

    public static func compare(_ left: String, _ right: String) throws -> TextComparisonResult {
        guard left.utf8.count <= maximumBytes, right.utf8.count <= maximumBytes else { throw TextComparisonError.tooLarge }
        let lhs = lines(in: left), rhs = lines(in: right)
        guard lhs.count <= maximumLines, rhs.count <= maximumLines else { throw TextComparisonError.tooManyLines }
        let difference = rhs.map(\.content).difference(from: lhs.map(\.content))
        let removals = difference.removals.map { change -> TextLineChange in
            if case let .remove(offset, _, _) = change {
                return TextLineChange(kind: .removed, leftLine: offset + 1, rightLine: nil, leftRange: lhs[offset].range, rightRange: nil)
            }
            fatalError("Unexpected insertion in removals")
        }
        let additions = difference.insertions.map { change -> TextLineChange in
            if case let .insert(offset, _, _) = change {
                return TextLineChange(kind: .added, leftLine: nil, rightLine: offset + 1, leftRange: nil, rightRange: rhs[offset].range)
            }
            fatalError("Unexpected removal in insertions")
        }
        // Sequence changes by their approximate position in the two documents, with a
        // deletion before an insertion when a line is replaced.
        let changes = (removals + additions).sorted {
            let a = $0.leftLine ?? $0.rightLine ?? 0
            let b = $1.leftLine ?? $1.rightLine ?? 0
            return a == b ? $0.kind == .removed : a < b
        }
        return TextComparisonResult(changes: changes)
    }

    private struct Line {
        let content: String
        let range: NSRange
    }

    private static func lines(in text: String) -> [Line] {
        if text.isEmpty { return [] }
        let source = text as NSString
        var result: [Line] = []
        var start = 0
        for index in 0..<source.length where source.character(at: index) == 10 {
            let range = NSRange(location: start, length: index + 1 - start)
            result.append(Line(content: source.substring(with: range), range: range))
            start = index + 1
        }
        if start < source.length {
            let range = NSRange(location: start, length: source.length - start)
            result.append(Line(content: source.substring(with: range), range: range))
        }
        return result
    }
}
