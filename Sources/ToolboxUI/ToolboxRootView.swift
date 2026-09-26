import SwiftUI

enum ToolRoute: String, CaseIterable, Identifiable {
    case json = "JSON"
    case base64 = "Base64"
    case url = "URL"
    case timestamp = "时间戳"
    case uuid = "UUID"
    case hash = "哈希"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .json: return "curlybraces.square"
        case .base64: return "character.textbox"
        case .url: return "link"
        case .timestamp: return "clock"
        case .uuid: return "number"
        case .hash: return "number.square"
        }
    }
}

enum ToolGroup: String, CaseIterable, Identifiable {
    case developer = "开发工具", images = "图片处理", text = "文本工具", files = "文件工具"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .images: return "photo.on.rectangle"
        case .text: return "text.alignleft"
        case .files: return "folder"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTool: ToolRoute = .json
    @Published var selectedGroup: ToolGroup = .images
}

public struct ToolboxRootView: View {
    public init() {}
    @StateObject private var appModel = AppModel()
    @StateObject private var imageModel = ImageWorkspaceModel()
    @StateObject private var jsonModel = JSONToolModel()
    @StateObject private var base64Model = EncodingToolModel(kind: .base64)
    @StateObject private var urlModel = EncodingToolModel(kind: .url)
    @StateObject private var timestampModel = TimestampToolModel()
    @StateObject private var uuidModel = UUIDToolModel()
    @StateObject private var hashModel = HashToolModel()
    @StateObject private var textModel = TextCompareModel()
    @StateObject private var renameModel = BatchRenameModel()

    public var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 4) {
                Text("工具集")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).frame(height: WorkspaceStyle.tabHeight)
                ForEach(ToolGroup.allCases) { group in
                    Button {
                        appModel.selectedGroup = group
                    } label: {
                        Label(group.rawValue, systemImage: group.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8).frame(height: 28)
                            .contentShape(Rectangle())
                            .background(appModel.selectedGroup == group ? Color.accentColor.opacity(0.14) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .accessibilityIdentifier("group-" + group.id)
                    .accessibilityAddTraits(appModel.selectedGroup == group ? [.isSelected] : [])
                }
                Spacer(minLength: 0)
            }
            .frame(minWidth: 120, idealWidth: 144, maxWidth: 200, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            Group {
                switch appModel.selectedGroup {
                case .developer: developerWorkspace
                case .images: ImageWorkspaceView(workspace: imageModel)
                case .text:
                    VStack(spacing: 0) {
                        singleToolHeader("文本对比", symbol: "text.alignleft")
                        TextCompareView(model: textModel)
                    }
                case .files:
                    VStack(spacing: 0) {
                        singleToolHeader("批量重命名", symbol: "pencil.line")
                        BatchRenameView(model: renameModel)
                    }
                }
            }
            .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WorkspaceStyle.background)
    }

    private func singleToolHeader(_ title: String, symbol: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Label(title, systemImage: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 130, height: WorkspaceStyle.tabHeight)
                    .background(WorkspaceStyle.background)
                    .overlay(alignment: .bottom) { Color.accentColor.frame(height: 2) }
                Spacer(minLength: 0)
            }
            .background(WorkspaceStyle.chrome)
            Divider()
        }
    }

    private var developerWorkspace: some View {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
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
                }
                .frame(height: WorkspaceStyle.tabHeight)
                .background(WorkspaceStyle.chrome)
                Divider()
                switch appModel.selectedTool {
                case .json: JSONToolView(model: jsonModel)
                case .base64: EncodingToolView(model: base64Model)
                case .url: EncodingToolView(model: urlModel)
                case .timestamp: TimestampToolView(model: timestampModel)
                case .uuid: UUIDToolView(model: uuidModel)
                case .hash: HashToolView(model: hashModel)
                }
            }
    }
}
