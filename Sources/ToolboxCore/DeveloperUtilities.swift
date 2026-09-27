import CryptoKit
import Foundation

public enum DeveloperUtilityError: Error, LocalizedError, Equatable {
    case invalidTimestamp, invalidDate, ambiguousDate, invalidTimeZone, invalidCount

    public var errorDescription: String? {
        switch self {
        case .invalidTimestamp: return "请输入有效的整数时间戳，日期范围为 1900–9999 年"
        case .invalidDate: return "请输入 1900–9999 年的有效日期：yyyy-MM-dd HH:mm:ss[.SSS] 或带时区的 ISO 8601"
        case .ambiguousDate: return "该本地时间在夏令时切换时出现两次，请使用带 UTC 偏移的 ISO 8601 日期"
        case .invalidTimeZone: return "请输入有效的时区标识，例如 Asia/Shanghai"
        case .invalidCount: return "UUID 数量必须在 1 到 1000 之间"
        }
    }
}

public enum UUIDUtility {
    public static func generate(count: Int) throws -> [String] {
        guard (1...1000).contains(count) else { throw DeveloperUtilityError.invalidCount }
        return (0..<count).map { _ in UUID().uuidString.lowercased() }
    }
}

public enum TextHashAlgorithm: String, CaseIterable, Identifiable {
    case sha256 = "SHA-256", sha512 = "SHA-512", sha1 = "SHA-1", md5 = "MD5"
    public var id: String { rawValue }
}

public enum TextHashUtility {
    public static func digest(_ text: String, algorithm: TextHashAlgorithm) -> String {
        let data = Data(text.utf8)
        let bytes: [UInt8]
        switch algorithm {
        case .sha256: bytes = Array(SHA256.hash(data: data))
        case .sha512: bytes = Array(SHA512.hash(data: data))
        case .sha1: bytes = Array(Insecure.SHA1.hash(data: data))
        case .md5: bytes = Array(Insecure.MD5.hash(data: data))
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
