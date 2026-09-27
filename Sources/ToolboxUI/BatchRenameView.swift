import AppKit
import SwiftUI
import ToolboxCore

@MainActor
final class BatchRenameModel: ObservableObject {
    @Published private(set) var urls: [URL] = []
    private var accessURLs: [URL] = []
    @Published private(set) var preview: [BatchRenamePreview] = []
    @Published private(set) var records: [BatchRenameRecord] = []
    @Published private(set) var undoableRecords: [BatchRenameRecord] = []
    @Published var options = BatchRenameOptions() { didSet { refresh() } }
    @Published var notice = "添加文件后预览新名称；确认无冲突再手动执行。"


    var canExecute: Bool { preview.contains(where: \.isReady) }
    var canUndo: Bool { !undoableRecords.isEmpty }
    var logText: String { (["时间\t结果\t原路径\t新路径\t说明"] + records.map(\.exportLine)).joined(separator: "\n") + "\n" }

    func importURLs(_ incoming: [URL]) {
        var known = Set(urls.map { $0.standardizedFileURL.path })
        let fresh = incoming.filter { $0.isFileURL && known.insert($0.standardizedFileURL.path).inserted }
        guard !fresh.isEmpty else { notice = "没有可添加的本地文件，或文件已在列表中"; return }
        urls.append(contentsOf: fresh)
        accessURLs.append(contentsOf: fresh)
        refresh()
        notice = "已添加 \(fresh.count) 个文件；请检查预览和冲突"
    }

    func move(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { urls[$0] }
        for index in source.sorted(by: >) { urls.remove(at: index) }
        let adjustment = source.filter { $0 < destination }.count
        urls.insert(contentsOf: moving, at: max(0, min(urls.count, destination - adjustment)))
        refresh()
    }

    func remove(_ id: UUID) {
        guard let index = preview.firstIndex(where: { $0.id == id }) else { return }
        urls.remove(at: index)
        refresh()
    }

    func clear() {
        urls.removeAll(); preview.removeAll()
        notice = "文件列表已清空；本会话操作记录及可撤销结果仍保留"
    }

    func refresh() { preview = BatchRename.preview(urls: urls, options: options) }

    func execute() {
        guard canExecute else { notice = "没有可执行的改名；请处理预览中的冲突"; return }
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        let currentPreview = preview
        let batch = BatchRename.execute(preview: currentPreview)
        for result in batch where result.succeeded {
            if let index = currentPreview.firstIndex(where: { $0.id == result.operationID }) { urls[index] = result.targetURL }
        }
        records.append(contentsOf: batch)
        undoableRecords.append(contentsOf: batch.filter(\.canUndo))
        refresh()
        notice = "执行完成：成功 \(batch.filter(\.succeeded).count)，失败 \(batch.filter { !$0.succeeded }.count)；详情见操作记录"
    }

    func undoLast() {
        guard canUndo else { return }
        let scoped = accessURLs.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        let results = BatchRename.undo(records: &undoableRecords)
        for result in results where result.succeeded {
            if let index = urls.firstIndex(where: { $0.standardizedFileURL.path == result.sourceURL.path }) { urls[index] = result.targetURL }
        }
        records.append(contentsOf: results)
        refresh()
        notice = "撤销完成：成功 \(results.filter(\.succeeded).count)，失败 \(results.filter { !$0.succeeded }.count)；失败项仍可在本会话重试"
    }

    func exportLog(to url: URL) throws {
        guard !records.isEmpty else { return }
        try logText.write(to: url, atomically: true, encoding: .utf8)
        notice = "操作记录已导出"
    }
}

struct BatchRenameView: View {
    @ObservedObject var model: BatchRenameModel
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Button("添加文件…", systemImage: "plus", action: chooseFiles)
                Button("清空列表", action: model.clear).disabled(model.urls.isEmpty)
                Spacer(minLength: 8)
                Button("执行重命名", systemImage: "play.fill", action: model.execute)
                    .buttonStyle(.borderedProminent).tint(WorkspaceStyle.accent)
                    .disabled(!model.canExecute)
                Button("撤销本会话改名", systemImage: "arrow.uturn.backward", action: model.undoLast)
                    .disabled(!model.canUndo)
                Button("导出操作记录…", systemImage: "square.and.arrow.up", action: chooseLog)
                    .disabled(model.records.isEmpty)
            }
            Divider()
            controls
            Divider()
            HStack(spacing: 4) {
                Text("原文件").frame(maxWidth: .infinity, alignment: .leading)
                Text("预览新名").frame(maxWidth: .infinity, alignment: .leading)
                Text("状态").frame(width: 230, alignment: .leading)
            }
            .font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8)
            .background(WorkspaceStyle.chrome)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.preview.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 4) {
                            Text(row.originalName).frame(maxWidth: .infinity, alignment: .leading)
                                .help(row.sourceURL.path)
                            Text(row.newName).frame(maxWidth: .infinity, alignment: .leading)
                                .help(row.newName)
                            Text(row.issue ?? "可执行")
                                .foregroundStyle(row.issue == nil ? Color.secondary : Color.red)
                                .frame(width: 190, alignment: .leading)
                                .help(row.issue ?? "执行前会再次检查")
                            Menu {
                                Button("上移") { model.move(from: IndexSet(integer: index), to: index - 1) }
                                    .disabled(index == 0)
                                Button("下移") { model.move(from: IndexSet(integer: index), to: index + 2) }
                                    .disabled(index == model.urls.count - 1)
                                Button("移除") { model.remove(row.id) }
                            } label: { Image(systemName: "ellipsis") }
                                .menuStyle(.borderlessButton).frame(width: 36)
                        }
                        .font(.system(size: 12)).lineLimit(1)
                        .padding(.horizontal, 12).frame(height: 34)
                        .background(index.isMultiple(of: 2) ? Color.clear : WorkspaceStyle.chrome.opacity(0.45))
                        Divider()
                    }
                    if model.preview.isEmpty {
                        ContentUnavailableView("拖入文件或点击“添加文件”", systemImage: "doc.on.doc",
                                               description: Text("仅处理普通文件；不会自动改名"))
                            .frame(maxWidth: .infinity).padding(.top, 50)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            if !model.records.isEmpty {
                DisclosureGroup("操作记录（\(model.records.count) 条）") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(model.records) { record in
                                Text("\(record.succeeded ? "成功" : "失败") · \(record.sourceURL.lastPathComponent) → \(record.targetURL.lastPathComponent) · \(record.message)")
                                    .foregroundStyle(record.succeeded ? Color.secondary : Color.red)
                                    .textSelection(.enabled)
                            }
                        }
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 100)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            WorkspaceStatus(message: model.notice, isError: false, isProcessing: false,
                            counts: "\(model.preview.count) 项 · \(model.preview.filter(\.isReady).count) 项可执行")
        }
        .background(WorkspaceStyle.background)
        .dropDestination(for: URL.self) { urls, _ in
            model.importURLs(urls); return !urls.isEmpty
        } isTargeted: { isDropTarget = $0 }
        .overlay { if isDropTarget { RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2).allowsHitTesting(false) } }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("前缀", text: $model.options.prefix)
                TextField("后缀", text: $model.options.suffix)
            }
            HStack(spacing: 12) {
                TextField("查找字面文本", text: $model.options.searchText)
                TextField("替换为", text: $model.options.replacementText)
                    .disabled(model.options.searchText.isEmpty)
            }
            HStack(spacing: 12) {
                Toggle("添加序号", isOn: $model.options.numberingEnabled)
                Stepper("起始 \(model.options.numberStart)", value: $model.options.numberStart, in: 0...999_999)
                    .disabled(!model.options.numberingEnabled)
                Stepper("位数 \(model.options.numberPadding)", value: $model.options.numberPadding, in: 1...12)
                    .disabled(!model.options.numberingEnabled)
                Spacer()
                Text("扩展名保持不变；按列表顺序编号").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12)).textFieldStyle(.roundedBorder)
        .padding(12)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { model.importURLs(panel.urls) }
    }

    private func chooseLog() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NsToolBox-rename-log.tsv"
        if panel.runModal() == .OK, let url = panel.url {
            do { try model.exportLog(to: url) }
            catch { model.notice = "导出记录失败：\(error.localizedDescription)" }
        }
    }
}
