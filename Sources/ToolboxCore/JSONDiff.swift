import Foundation

public enum JSONDifferenceKind: Equatable, Sendable {
    case added
    case removed
    case modified
}

public struct JSONDifference: Equatable, Sendable {
    public let path: JSONPath
    public let kind: JSONDifferenceKind
    public let leftRange: NSRange?
    public let rightRange: NSRange?

    public init(path: JSONPath, kind: JSONDifferenceKind, leftRange: NSRange?, rightRange: NSRange?) {
        self.path = path
        self.kind = kind
        self.leftRange = leftRange
        self.rightRange = rightRange
    }
}

public enum JSONDiff {
    public static func compare(_ left: JSONDocument, _ right: JSONDocument) -> [JSONDifference] {
        var differences: [JSONDifference] = []
        compare(left.value, right.value, path: JSONPath(), left: left, right: right, into: &differences)
        return differences
    }

    private static func compare(_ left: JSONValue?, _ right: JSONValue?, path: JSONPath, left leftDocument: JSONDocument, right rightDocument: JSONDocument, into output: inout [JSONDifference]) {
        switch (left, right) {
        case (nil, .some):
            output.append(JSONDifference(path: path, kind: .added, leftRange: nil, rightRange: rightDocument.ranges[path]))
        case (.some, nil):
            output.append(JSONDifference(path: path, kind: .removed, leftRange: leftDocument.ranges[path], rightRange: nil))
        case (.none, .none):
            break
        case (.some(let lhs), .some(let rhs)):
            if lhs == rhs { return }
            switch (lhs, rhs) {
            case (.object(let lo), .object(let ro)):
                let keys = Set(lo.keys).union(ro.keys).sorted()
                for key in keys { compare(lo[key], ro[key], path: path.appending(.key(key)), left: leftDocument, right: rightDocument, into: &output) }
            case (.array(let la), .array(let ra)):
                for index in 0..<max(la.count, ra.count) {
                    compare(index < la.count ? la[index] : nil, index < ra.count ? ra[index] : nil, path: path.appending(.index(index)), left: leftDocument, right: rightDocument, into: &output)
                }
            default:
                output.append(JSONDifference(path: path, kind: .modified, leftRange: leftDocument.ranges[path], rightRange: rightDocument.ranges[path]))
            }
        }
    }
}
