import AppKit
import SwiftUI
import ToolboxCore

struct JSONToolView: View {
    @ObservedObject var model: JSONToolModel
    @State private var leftSelection: EditorSelection?
    @State private var rightSelection: EditorSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JSON 工具").font(.title2.bold())
                    Text("格式化、校验和结构化对比 · 本地处理").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("清空", action: model.clear)
            }
            HStack {
                Picker("模式", selection: $model.mode) {
                    ForEach(JSONMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 360)
                Spacer()
                if model.mode == .compare {
                    Button("格式化两侧", action: model.formatBoth)
                        .disabled(model.leftText.isEmpty || model.rightText.isEmpty || model.isError)
                        .help("统一缩进与字段顺序，再进行结构化对比")
                }
            }
            if model.mode == .compare { compareEditor } else { singleEditor }
            HStack(alignment: .top) {
                if model.isProcessing { ProgressView().controlSize(.small) }
                else { Image(systemName: model.isError ? "exclamationmark.triangle.fill" : "info.circle").foregroundStyle(model.isError ? Color.red : Color.secondary) }
                Text(model.message).font(.callout).foregroundStyle(model.isError ? Color.red : Color.secondary).textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 20)
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.leftText) { _ in leftSelection = nil; rightSelection = nil }
        .onChange(of: model.rightText) { _ in leftSelection = nil; rightSelection = nil }
    }

    private var singleEditor: some View {
        HStack(spacing: 14) {
            EditorPane(title: "JSON 输入", text: $model.leftText, error: model.leftError)
            if model.mode != .validate {
                EditorPane(title: model.mode == .format ? "格式化结果" : "压缩结果", text: .constant(model.outputText), editable: false)
            }
        }
    }

    private var compareEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                EditorPane(title: "左侧 · 原始 JSON", text: $model.leftText, highlights: highlights(for: true), error: model.leftError, selection: leftSelection)
                EditorPane(title: "右侧 · 对比 JSON", text: $model.rightText, highlights: highlights(for: false), error: model.rightError, selection: rightSelection)
            }
            HStack(spacing: 14) {
                differenceLabel(.added)
                differenceLabel(.removed)
                differenceLabel(.modified)
                Spacer()
                Text("忽略对象字段顺序 · 数组顺序敏感").foregroundStyle(.secondary)
            }.font(.caption)
            if !model.differences.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(model.differences, id: \.path) { difference in
                            Button {
                                leftSelection = difference.leftRange.map { EditorSelection(range: $0) }
                                rightSelection = difference.rightRange.map { EditorSelection(range: $0) }
                            } label: {
                                HStack {
                                    differenceLabel(difference.kind).frame(width: 70, alignment: .leading)
                                    Text(difference.path.description).font(.system(.caption, design: .monospaced)).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(.secondary)
                                }.padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
                            }.buttonStyle(.plain).help("点击定位到两侧对应的差异")
                        }
                    }
                }
                .frame(height: 118)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func highlights(for left: Bool) -> [EditorHighlight] {
        model.differences.compactMap { difference -> EditorHighlight? in
            guard let range = left ? difference.leftRange : difference.rightRange else { return nil }
            return EditorHighlight(range: range, background: difference.kind.nsColor.withAlphaComponent(0.20))
        }
    }

    private func differenceLabel(_ kind: JSONDifferenceKind) -> some View {
        Label(kind.label, systemImage: kind.icon).foregroundStyle(Color(nsColor: kind.nsColor))
    }
}

private extension JSONDifferenceKind {
    var label: String { switch self { case .added: return "新增"; case .removed: return "删除"; case .modified: return "修改" } }
    var icon: String { switch self { case .added: return "plus.circle.fill"; case .removed: return "minus.circle.fill"; case .modified: return "pencil.circle.fill" } }
    var nsColor: NSColor { switch self { case .added: return .systemGreen; case .removed: return .systemRed; case .modified: return .systemOrange } }
}
