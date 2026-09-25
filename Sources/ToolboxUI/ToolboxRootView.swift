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
        NavigationSplitView {
            List(ToolRoute.allCases, selection: $appModel.selectedTool) { route in
                Label(route.rawValue, systemImage: route.systemImage).tag(route)
            }
            .navigationTitle("NsToolBox")
            .listStyle(.sidebar)
        } detail: {
            switch appModel.selectedTool {
            case .json: JSONToolView(model: jsonModel)
            case .base64: EncodingToolView(model: base64Model)
            case .url: EncodingToolView(model: urlModel)
            }
        }
    }
}
