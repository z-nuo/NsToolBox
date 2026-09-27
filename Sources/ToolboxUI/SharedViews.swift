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
            Image(systemName: feedback == "已复制" ? "checkmark" : "doc.on.doc")
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(WorkspaceIconButtonStyle())
        .disabled(text.isEmpty)
        .help(feedback ?? "复制")
        .accessibilityLabel(feedback ?? "复制")
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
    var placeholder: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(title).fontWeight(.semibold).lineLimit(1)
                if !editable { Image(systemName: "lock").foregroundStyle(.tertiary).help("只读") }
                if error != nil {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        .help(error?.localizedDescription ?? "")
                }
                Spacer(minLength: 4)
                CopyButton(text: text)
                if editable {
                    Button { text = "" } label: {
                        Image(systemName: "trash").frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(WorkspaceIconButtonStyle())
                        .disabled(text.isEmpty)
                        .accessibilityLabel("清空" + title)
                        .help("仅清空" + title)
                }
            }
            .font(.system(size: 12))
            .controlSize(.small)
            .padding(.horizontal, 12)
            .frame(height: WorkspaceStyle.paneHeaderHeight)
            .background(WorkspaceStyle.chrome)
            Divider()
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $text, highlights: highlights, isEditable: editable, syntaxHighlighting: syntax,
                           selection: selection, accessibilityLabel: title)
                if text.isEmpty {
                    Text(placeholder ?? (editable ? "粘贴或输入文本…" : "结果将显示在这里"))
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
                        .padding(.leading, 56).padding(.top, 8).allowsHitTesting(false)
                }
            }
        }
        .background(WorkspaceStyle.background)
        .frame(minWidth: WorkspaceStyle.minimumPaneWidth, maxWidth: .infinity, maxHeight: .infinity)
    }
}
