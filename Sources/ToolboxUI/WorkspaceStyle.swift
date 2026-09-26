import AppKit
import SwiftUI

/// Shared metrics keep tools aligned when switching tabs and modes.
enum WorkspaceStyle {
    static let tabHeight: CGFloat = 34
    static let toolbarHeight: CGFloat = 32
    static let paneHeaderHeight: CGFloat = 28
    static let statusHeight: CGFloat = 24
    static let minimumPaneWidth: CGFloat = 280
    static let background = Color(nsColor: .textBackgroundColor)
    static let chrome = Color(nsColor: .controlBackgroundColor)
}

struct WorkspaceToolbar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .font(.system(size: 12))
            .controlSize(.small)
            .padding(.horizontal, 8)
            .frame(height: WorkspaceStyle.toolbarHeight)
            .background(WorkspaceStyle.chrome)
    }
}

struct WorkspaceStatus: View {
    let message: String
    var isError = false
    var isProcessing = false
    let counts: String
    @State private var showDetails = false

    var body: some View {
        HStack(spacing: 6) {
            if isProcessing {
                ProgressView().controlSize(.mini).scaleEffect(0.75).frame(width: 14)
            } else {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle")
                    .foregroundStyle(isError ? Color.red : Color.secondary)
            }
            Text(message).lineLimit(1).truncationMode(.tail)
                .foregroundStyle(isError ? Color.red : Color.secondary)
                .help(message)
            if isError {
                Button {
                    showDetails.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看完整错误")
                .popover(isPresented: $showDetails) {
                    Text(message).textSelection(.enabled).padding(12).frame(width: 360, alignment: .leading)
                }
            }
            Spacer(minLength: 8)
            Text(counts).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                .layoutPriority(1)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .frame(height: WorkspaceStyle.statusHeight)
        .background(WorkspaceStyle.chrome)
        .onChange(of: isError) { _, value in if !value { showDetails = false } }
    }
}
