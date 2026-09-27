import AppKit
import SwiftUI

/// Shared metrics keep tools aligned when switching tabs and modes.
enum WorkspaceStyle {
    static let tabHeight: CGFloat = 34
    static let toolbarHeight: CGFloat = 36
    static let paneHeaderHeight: CGFloat = 30
    static let statusHeight: CGFloat = 24
    static let minimumPaneWidth: CGFloat = 280
    static let background = Color(nsColor: .textBackgroundColor)
    static let chrome = Color(nsColor: .controlBackgroundColor)
    static let sidebar = Color(nsColor: .windowBackgroundColor)
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(srgbRed: 0.36, green: 0.77, blue: 0.73, alpha: 1)
            : NSColor(srgbRed: 0.07, green: 0.46, blue: 0.44, alpha: 1)
    })
    static let selected = accent.opacity(0.12)
}

struct WorkspaceNavigationButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> Body {
        Body(configuration: configuration, isSelected: isSelected)
    }

    struct Body: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 4)
            configuration.label
                .foregroundStyle(isEnabled
                    ? (isSelected ? WorkspaceStyle.accent : Color.primary)
                    : Color.secondary.opacity(0.55))
                .background {
                    shape.fill(isSelected ? WorkspaceStyle.selected
                        : (isHovered && isEnabled ? WorkspaceStyle.selected.opacity(0.65)
                            : WorkspaceStyle.background.opacity(0.55)))
                }
                .overlay {
                    shape.strokeBorder(isSelected ? WorkspaceStyle.accent.opacity(0.55)
                        : Color.primary.opacity(isHovered && isEnabled ? 0.28 : 0.12), lineWidth: 1)
                }
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { isHovered = $0 }
        }
    }
}

struct WorkspaceIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> Body {
        Body(configuration: configuration)
    }

    struct Body: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 4)
            configuration.label
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.55))
                .background(shape.fill(isHovered && isEnabled ? WorkspaceStyle.selected : WorkspaceStyle.background))
                .overlay(shape.strokeBorder(Color.primary.opacity(isHovered && isEnabled ? 0.28 : 0.16)))
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { isHovered = $0 }
        }
    }
}

struct WorkspaceToolbar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .font(.system(size: 12))
            .controlSize(.small)
            .padding(.horizontal, 12)
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
        .padding(.horizontal, 12)
        .frame(height: WorkspaceStyle.statusHeight)
        .background(WorkspaceStyle.chrome)
        .onChange(of: isError) { _, value in if !value { showDetails = false } }
    }
}
