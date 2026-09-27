import AppKit
import Combine
import Foundation
import SwiftUI
import ToolboxCore

@MainActor
final class TextCompareModel: ObservableObject {
    @Published var leftText = "" { didSet { scheduleComparison() } }
    @Published var rightText = "" { didSet { scheduleComparison() } }
    @Published private(set) var changes: [TextLineChange] = []
    @Published private(set) var message = "在左右两侧输入纯文本"
    @Published private(set) var isError = false
    @Published private(set) var isProcessing = false
    @Published private(set) var selectedChange = -1
    private var generation = 0
    private var pending: DispatchWorkItem?
    private let worker = DispatchQueue(label: "com.nstoolbox.textcomparison", qos: .userInitiated)

    deinit { pending?.cancel() }

    private func scheduleComparison() {
        generation += 1
        pending?.cancel()
        changes = []
        selectedChange = -1
        isError = false
        guard !leftText.isEmpty || !rightText.isEmpty else {
            isProcessing = false
            message = "在左右两侧输入纯文本"
            return
        }
        let lhs = leftText, rhs = rightText, request = generation
        isProcessing = true
        message = "正在对比…"
        let work = DispatchWorkItem { [weak self] in
            let result = Result { try TextComparison.compare(lhs, rhs) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == request else { return }
                self.isProcessing = false
                switch result {
                case .success(let comparison):
                    self.changes = comparison.changes
                    self.message = comparison.changes.isEmpty ? "两侧文本相同" : "发现 \(comparison.changes.count) 行差异"
                case .failure(let error):
                    self.isError = true
                    self.message = error.localizedDescription
                }
            }
        }
        pending = work
        worker.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    @discardableResult
    func navigate(_ step: Int) -> TextLineChange? {
        guard !changes.isEmpty else { return nil }
        if selectedChange < 0 {
            selectedChange = step < 0 ? changes.count - 1 : 0
        } else {
            selectedChange = (selectedChange + step + changes.count) % changes.count
        }
        return changes[selectedChange]
    }
}

struct TextCompareView: View {
    @ObservedObject var model: TextCompareModel
    @State private var leftSelection: EditorSelection?
    @State private var rightSelection: EditorSelection?

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Text("纯文本按行对比").foregroundStyle(.secondary)
                Spacer()
                Button("上一处") { navigate(-1) }.disabled(model.changes.isEmpty)
                Button("下一处") { navigate(1) }.disabled(model.changes.isEmpty)
                Text(model.changes.isEmpty ? "0 / 0" : "\(max(model.selectedChange + 1, 0)) / \(model.changes.count)")
                    .monospacedDigit().frame(width: 64)
            }
            Divider()
            HSplitView {
                EditorPane(title: "左侧 · 原文本", text: $model.leftText, syntax: false,
                           highlights: highlights(left: true), selection: leftSelection)
                EditorPane(title: "右侧 · 对比文本", text: $model.rightText, syntax: false,
                           highlights: highlights(left: false), selection: rightSelection)
            }
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError, isProcessing: model.isProcessing,
                            counts: "左 \(model.leftText.utf8.count) B · 右 \(model.rightText.utf8.count) B")
        }
        .background(WorkspaceStyle.background)
        .onChange(of: model.leftText) { _, _ in resetSelection() }
        .onChange(of: model.rightText) { _, _ in resetSelection() }
    }

    private func highlights(left: Bool) -> [EditorHighlight] {
        model.changes.compactMap { change in
            guard let range = left ? change.leftRange : change.rightRange else { return nil }
            return EditorHighlight(range: range, background: (left ? NSColor.systemRed : NSColor.systemGreen).withAlphaComponent(0.20))
        }
    }

    private func resetSelection() {
        leftSelection = nil
        rightSelection = nil
    }

    private func navigate(_ step: Int) {
        guard let change = model.navigate(step) else { return }
        leftSelection = change.leftRange.map(EditorSelection.init(range:))
        rightSelection = change.rightRange.map(EditorSelection.init(range:))
    }
}
