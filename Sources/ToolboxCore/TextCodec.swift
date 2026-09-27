import Foundation

public enum CodecKind: String, Sendable { case base64, url }

public enum CodecError: Error, LocalizedError {
    case invalidBase64, invalidUTF8, invalidURL
    public var errorDescription: String? {
        switch self {
        case .invalidBase64: return "Base64 格式无效，请检查字符和末尾的 = 填充。"
        case .invalidUTF8: return "解码结果不是有效的 UTF-8 文本。首版仅支持文本转换。"
        case .invalidURL: return "URL 编码无效，请检查 % 后的两位十六进制数字和 UTF-8 字节。"
        }
    }
}

public enum TextCodec {
    public static func encode(_ text: String, kind: CodecKind) throws -> String {
        switch kind {
        case .base64: return Data(text.utf8).base64EncodedString()
        case .url:
            let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            guard let result = text.addingPercentEncoding(withAllowedCharacters: unreserved) else { throw CodecError.invalidURL }
            return result
        }
    }

    public static func decode(_ text: String, kind: CodecKind) throws -> String {
        switch kind {
        case .base64:
            let source = text.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: source), data.base64EncodedString() == source else { throw CodecError.invalidBase64 }
            guard let result = String(data: data, encoding: .utf8) else { throw CodecError.invalidUTF8 }
            return result
        case .url:
            guard let result = text.removingPercentEncoding else { throw CodecError.invalidURL }
            return result
        }
    }
}
