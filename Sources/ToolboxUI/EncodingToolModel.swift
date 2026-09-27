import Combine
import Foundation
import ToolboxCore

@MainActor
final class EncodingToolModel: ObservableObject {
    let kind: CodecKind
    @Published var input = "" { didSet { convert() } }
    @Published var output = ""
    @Published var isDecoding = false { didSet { convert() } }
    @Published var message = ""
    @Published var isError = false

    init(kind: CodecKind) { self.kind = kind }

    func convert() {
        guard !input.isEmpty else {
            output = ""
            message = ""
            isError = false
            return
        }
        do {
            output = try isDecoding ? TextCodec.decode(input, kind: kind) : TextCodec.encode(input, kind: kind)
            message = isDecoding ? "解码成功" : "编码成功"
            isError = false
        } catch {
            output = ""
            message = error.localizedDescription
            isError = true
        }
    }

    func clear() {
        input = ""
        output = ""
        message = ""
        isError = false
    }

}
