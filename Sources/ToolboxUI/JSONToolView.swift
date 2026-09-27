import AppKit
import SwiftUI
import ToolboxCore

struct JSONToolView: View {
    @ObservedObject var model: JSONToolModel
    @State private var leftSelection: EditorSelection?
    @State private var rightSelection: EditorSelection?
    @State private var showDifferences = false

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Picker("模式", selection: $model.mode) {
                    ForEach(JSONMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 280)
                Spacer()
                if model.mode == .compare {
                    Button("格式化两侧", action: model.formatBoth)
                        .disabled(model.leftText.isEmpty || model.rightText.isEmpty || model.isError || model.isProcessing)
                        .help("统一缩进与字段顺序，再进行结构化对比")
                }
            }
            Divider()
            HSplitView {
                EditorPane(title: model.mode == .compare ? "左侧 · 原始 JSON" : "JSON 输入",
                           text: $model.leftText, highlights: highlights(for: true), error: model.leftError,
                           selection: leftSelection)
                if model.mode == .compare {
                    EditorPane(title: "右侧 · 对比 JSON", text: $model.rightText,
                               highlights: highlights(for: false), error: model.rightError, selection: rightSelection)
                } else if model.mode == .validate {
                    validationReport
                } else {
                    EditorPane(title: model.mode == .format ? "格式化结果" : "压缩结果",
                               text: .constant(model.outputText), editable: false,
                               placeholder: model.isError ? "JSON 无效，请检查左侧输入" : "结果将显示在这里")
                }
            }
            if model.mode == .compare { differencePanel }
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError, isProcessing: model.isProcessing,
                            counts: counts)
        }
        .background(WorkspaceStyle.background)
        .onChange(of: model.leftText) { leftSelection = nil; rightSelection = nil }
        .onChange(of: model.rightText) { leftSelection = nil; rightSelection = nil }
        .onChange(of: model.mode) { leftSelection = nil; rightSelection = nil }
    }

    private var counts: String {
        if model.mode == .compare { return "左侧 \(model.leftText.count) 字符 · 右侧 \(model.rightText.count) 字符" }
        if model.mode == .validate { return "输入 \(model.leftText.count) 字符" }
        return "输入 \(model.leftText.count) 字符 · 输出 \(model.outputText.count) 字符"
    }

    private var validationReport: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("校验报告").fontWeight(.medium)
                Text("只读").foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: model.isProcessing || model.leftText.isEmpty ? "" : model.message)
            }
            .font(.system(size: 12)).controlSize(.small)
            .padding(.horizontal, 8).frame(height: WorkspaceStyle.paneHeaderHeight)
            .background(WorkspaceStyle.chrome)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if model.leftText.isEmpty {
                        Text("输入 JSON 后显示校验报告").foregroundStyle(.secondary)
                    } else if model.isProcessing {
                        Text("正在校验…").foregroundStyle(.secondary)
                    } else if let error = model.leftError {
                        Label("JSON 无效", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(error.message).textSelection(.enabled)
                        Button("定位到第 \(error.line) 行，第 \(error.column) 列") {
                            let length = (model.leftText as NSString).length
                            let offset = min(error.offset, length)
                            leftSelection = EditorSelection(range: NSRange(location: offset, length: offset < length ? 1 : 0))
                        }
                        .accessibilityIdentifier("validation-locate-error")
                        .controlSize(.small)
                    } else {
                        Label("JSON 有效", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("语法检查通过").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
        .frame(minWidth: WorkspaceStyle.minimumPaneWidth, maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("validation-report")
    }

    private var differencePanel: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    showDifferences.toggle()
                } label: {
                    Label(differenceSummary, systemImage: showDifferences ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("toggle-differences")
                differenceLabel(.added)
                differenceLabel(.removed)
                differenceLabel(.modified)
                Spacer(minLength: 4)
                Image(systemName: "info.circle")
                    .help("忽略对象字段顺序；数组顺序敏感；数字按精确值比较")
                    .accessibilityLabel("对比规则：忽略对象字段顺序，数组顺序敏感")
            }
            .font(.system(size: 11)).padding(.horizontal, 8).frame(height: 28)
            .background(WorkspaceStyle.chrome)
            if showDifferences {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if model.differences.isEmpty {
                            Text(model.message).foregroundStyle(.secondary).padding(8)
                        }
                        ForEach(model.differences, id: \.path) { difference in
                            Button {
                                leftSelection = difference.leftRange.map { EditorSelection(range: $0) }
                                rightSelection = difference.rightRange.map { EditorSelection(range: $0) }
                            } label: {
                                HStack(spacing: 8) {
                                    differenceLabel(difference.kind).frame(width: 56, alignment: .leading)
                                    Text(difference.path.description).font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8).frame(minHeight: 24).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).help("定位两侧对应差异")
                            .accessibilityIdentifier("difference-" + difference.path.description)
                        }
                    }.font(.system(size: 11))
                }
                .frame(height: 120)
            }
        }
    }

    private var differenceSummary: String {
        if model.isProcessing { return "差异 · 处理中" }
        if model.isError { return "差异 · 等待有效 JSON" }
        if model.leftText.isEmpty && model.rightText.isEmpty { return "差异 · 等待输入" }
        return "差异 \(model.differences.count)"
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
