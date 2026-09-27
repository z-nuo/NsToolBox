import Combine
import Foundation
import SwiftUI
import ToolboxCore

@MainActor
final class UUIDToolModel: ObservableObject {
    @Published var countInput = "1"
    @Published private(set) var output = ""
    @Published private(set) var message = "输入数量并生成 UUID v4"
    @Published private(set) var isError = false

    func generate() {
        output = ""
        isError = false
        do {
            guard let count = Int(countInput), countInput == String(count) else { throw DeveloperUtilityError.invalidCount }
            output = try UUIDUtility.generate(count: count).joined(separator: "\n")
            message = "已生成 \(count) 个 UUID v4"
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }
}

struct UUIDToolView: View {
    @ObservedObject var model: UUIDToolModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Text("数量")
                TextField("1–1000", text: $model.countInput).frame(width: 80)
                Button("生成 UUID v4", action: model.generate)
                Spacer()
            }
            Divider()
            EditorPane(title: "UUID v4 结果", text: .constant(model.output), editable: false, syntax: false)
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError, counts: "最多 1000 个")
        }.background(WorkspaceStyle.background)
    }
}

@MainActor
final class HashToolModel: ObservableObject {
    static let maximumBytes = 2 * 1024 * 1024
    @Published var input = "" { didSet { recompute() } }
    @Published var algorithm: TextHashAlgorithm = .sha256 { didSet { recompute() } }
    @Published private(set) var output = ""
    @Published private(set) var isError = false
    var message: String {
        if isError { return "输入文本超过 2 MB（UTF-8）上限" }
        return input.isEmpty ? "输入 UTF-8 文本后计算摘要" : "已计算 \(algorithm.rawValue) 摘要"
    }

    private func recompute() {
        isError = input.utf8.count > Self.maximumBytes
        output = input.isEmpty || isError ? "" : TextHashUtility.digest(input, algorithm: algorithm)
    }
}

struct HashToolView: View {
    @ObservedObject var model: HashToolModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Picker("算法", selection: $model.algorithm) {
                    ForEach(TextHashAlgorithm.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 160)
                Spacer()
                Text("文本摘要 · UTF-8").foregroundStyle(.secondary)
            }
            Divider()
            HSplitView {
                EditorPane(title: "输入文本", text: $model.input, syntax: false)
                EditorPane(title: "\(model.algorithm.rawValue) 摘要", text: .constant(model.output), editable: false, syntax: false)
            }
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError,
                            counts: "输入 \(model.input.utf8.count) 字节 · 摘要 \(model.output.count) 字符")
        }.background(WorkspaceStyle.background)
    }
}
