import AppKit
import SwiftUI
import ToolboxCore

@MainActor
enum ClipboardService {
    static func copy(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

struct CopyButton: View {
    let text: String
    @State private var feedback: String?
    @State private var request = 0

    var body: some View {
        Button {
            feedback = ClipboardService.copy(text) ? "已复制" : "复制失败"
            request += 1
        } label: {
            Label(feedback ?? "复制", systemImage: feedback == "已复制" ? "checkmark" : "doc.on.doc")
        }
        .disabled(text.isEmpty)
        .help("复制该编辑区的文本")
        .task(id: request) {
            guard request > 0 else { return }
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            feedback = nil
        }
    }
}

struct EditorPane: View {
    let title: String
    @Binding var text: String
    var editable = true
    var syntax = true
    var highlights: [EditorHighlight] = []
    var error: JSONParseError?
    var selection: EditorSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Text(editable ? "可编辑" : "只读").font(.caption).foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: text).controlSize(.small)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $text, highlights: highlights, isEditable: editable, syntaxHighlighting: syntax,
                           selection: selection, accessibilityLabel: title)
                if text.isEmpty {
                    Text(editable ? "在此粘贴或输入文本…" : "处理结果将显示在这里")
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(.tertiary)
                        .padding(12).allowsHitTesting(false)
                }
            }
            Divider()
            HStack {
                Text("\(text.count) 字符").monospacedDigit()
                Spacer()
                if let error { Text(error.localizedDescription).foregroundStyle(.red).lineLimit(2).help(error.localizedDescription) }
                else { Text("UTF-8").foregroundStyle(.secondary) }
            }
            .font(.caption).foregroundStyle(.secondary).padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
