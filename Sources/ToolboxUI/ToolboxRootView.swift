import SwiftUI

enum ToolRoute: String, CaseIterable, Identifiable {
    case json = "JSON"
    case base64 = "Base64"
    case url = "URL"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .json: return "curlybraces.square"
        case .base64: return "character.textbox"
        case .url: return "link"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTool: ToolRoute = .json
}

public struct ToolboxRootView: View {
    public init() {}
    @StateObject private var appModel = AppModel()
    @StateObject private var jsonModel = JSONToolModel()
    @StateObject private var base64Model = EncodingToolModel(kind: .base64)
    @StateObject private var urlModel = EncodingToolModel(kind: .url)

    public var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 4) {
                Text("工具集")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).frame(height: WorkspaceStyle.tabHeight)
                Label("开发工具", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8).frame(height: 28)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 6)
                    .accessibilityAddTraits(.isSelected)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 120, idealWidth: 144, maxWidth: 200, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(ToolRoute.allCases) { route in
                        Button {
                            appModel.selectedTool = route
                        } label: {
                            Label(route.rawValue, systemImage: route.systemImage)
                                .font(.system(size: 12, weight: appModel.selectedTool == route ? .medium : .regular))
                                .frame(width: 104, height: WorkspaceStyle.tabHeight)
                                .contentShape(Rectangle())
                                .background(appModel.selectedTool == route ? WorkspaceStyle.background : Color.clear)
                                .overlay(alignment: .bottom) {
                                    if appModel.selectedTool == route { Color.accentColor.frame(height: 2) }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(route.rawValue)
                        .accessibilityIdentifier("tool-tab-\(route.id)")
                        .accessibilityAddTraits(appModel.selectedTool == route ? [.isSelected] : [])
                        .help("切换到 \(route.rawValue)")
                    }
                    Spacer(minLength: 0)
                }
                .background(WorkspaceStyle.chrome)
                Divider()
                switch appModel.selectedTool {
                case .json: JSONToolView(model: jsonModel)
                case .base64: EncodingToolView(model: base64Model)
                case .url: EncodingToolView(model: urlModel)
                }
            }
            .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WorkspaceStyle.background)
    }
}
