import SwiftUI
import ToolboxCore

struct EncodingToolView: View {
    @ObservedObject var model: EncodingToolModel
    private var title: String { model.kind == .base64 ? "Base64 编解码" : "URL 编解码" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    Text(model.kind == .base64 ? "UTF-8 文本与标准 Base64 双向转换" : "百分号编码文本或参数值，解码时保留 + 字符")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("清空", action: model.clear)
            }
            HStack {
                Picker("操作", selection: $model.isDecoding) {
                    Text("编码").tag(false)
                    Text("解码").tag(true)
                }.pickerStyle(.segmented).frame(width: 180)
                Spacer()
                Text("所有处理均在本地完成").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                EditorPane(title: "输入文本", text: $model.input, syntax: false)
                EditorPane(title: model.isDecoding ? "解码结果" : "编码结果", text: .constant(model.output), editable: false, syntax: false)
            }
            HStack {
                Image(systemName: model.isError ? "exclamationmark.triangle.fill" : "info.circle")
                Text(model.message.isEmpty ? "输入文本后自动转换" : model.message).textSelection(.enabled)
                Spacer()
            }.foregroundStyle(model.isError ? Color.red : Color.secondary).font(.callout).frame(minHeight: 20)
        }.padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
