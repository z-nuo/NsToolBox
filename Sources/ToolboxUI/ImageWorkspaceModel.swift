import Combine
import Foundation
import ToolboxImages

/// Each tool keeps its own inputs, settings, errors and results for this window.
@MainActor
final class ImageWorkspaceModel: ObservableObject {
    @Published private(set) var selectedTool: ImageToolRoute = .cutout
    private let sessions: [ImageToolRoute: ImageBatchModel] = Dictionary(
        uniqueKeysWithValues: ImageToolRoute.allCases.map { ($0, ImageBatchModel(tool: $0)) })

    var activeModel: ImageBatchModel { model(for: selectedTool) }

    func model(for tool: ImageToolRoute) -> ImageBatchModel { sessions[tool]! }

    func select(_ tool: ImageToolRoute) {
        guard !activeModel.isBusy else { return }
        selectedTool = tool
    }

    func useSelectedResult(in tool: ImageToolRoute) {
        let source = activeModel
        let target = model(for: tool)
        guard tool != selectedTool, !source.isBusy, !target.isBusy,
              let item = source.selectedItem, let result = item.resultURL else { return }
        let name = URL(fileURLWithPath: item.name).deletingPathExtension().lastPathComponent
            + "." + result.pathExtension
        // Import makes a separate snapshot before the source session can be changed again.
        target.importURLs([result], displayNames: [result: name], selectImported: true)
        selectedTool = tool
    }
}
