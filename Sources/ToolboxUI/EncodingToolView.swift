import SwiftUI
import ToolboxCore

struct EncodingToolView: View {
    @ObservedObject var model: EncodingToolModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Picker("操作", selection: $model.isDecoding) {
                    Text("编码").tag(false)
                    Text("解码").tag(true)
                }.pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 160)
                Spacer()
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .help(model.kind == .base64 ? "UTF-8 文本与标准 Base64 双向转换；所有处理均在本地完成" : "编码文本或参数值；完整 URL 的分隔符也会编码，解码保留 + 字符。所有处理均在本地完成")
                    .accessibilityLabel("编解码说明")
            }
            Divider()
            HSplitView {
                EditorPane(title: "输入文本", text: $model.input, syntax: false)
                EditorPane(title: model.isDecoding ? "解码结果" : "编码结果", text: .constant(model.output), editable: false,
                           syntax: false, placeholder: model.isError ? "无法转换，请检查左侧输入" : "结果将显示在这里")
            }
            Divider()
            WorkspaceStatus(message: model.message.isEmpty ? "输入文本后自动转换" : model.message,
                            isError: model.isError,
                            counts: "输入 \(model.input.count) 字符 · 输出 \(model.output.count) 字符")
        }
        .background(WorkspaceStyle.background)
    }
}
