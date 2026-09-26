import AppKit
import Combine
import Foundation
import ToolboxImages

enum ImageToolRoute: String, CaseIterable, Identifiable {
    case cutout = "抠图", resize = "缩放", format = "格式转换", compress = "压缩"
    var id: String { rawValue }
    var actionTitle: String {
        switch self {
        case .cutout: return "开始抠图"
        case .resize: return "调整尺寸"
        case .format: return "转换格式"
        case .compress: return "压缩图片"
        }
    }

    func processingOptions(from options: ImageProcessingOptions, sourceFormat: ImageOutputFormat) -> ImageProcessingOptions {
        var result = ImageProcessingOptions()
        switch self {
        case .cutout:
            result.cutout = options.cutout
            result.format = .png
        case .resize:
            result.resize = options.resize
            result.percentage = options.percentage
            result.width = options.width; result.height = options.height
            result.preserveAspect = options.preserveAspect
            result.format = sourceFormat
            result.jpegQuality = 0.95
        case .format:
            result.format = options.format
            result.background = options.background
            result.jpegQuality = 0.95
        case .compress:
            result.format = options.format
            result.jpegQuality = options.jpegQuality
            result.background = options.background
        }
        return result
    }
}

enum ImageItemState: String {
    case waiting = "待处理", processing = "处理中", ready = "可导出", exported = "已导出", failed = "失败"
}

struct ImageBatchItem: Identifiable {
    let id: UUID
    let originalURL: URL
    var displayName: String?
    var name: String { displayName ?? originalURL.lastPathComponent }
    var sourceURL: URL?
    var info: ImageInfo?
    var originalPreviewURL: URL?
    var resultPreviewURL: URL?
    var resultURL: URL?
    var resultWidth: Int?
    var resultHeight: Int?
    var resultBytes: Int?
    var resultFormat: ImageOutputFormat?
    var exportedURL: URL?
    var state: ImageItemState = .waiting
    var error: String?
}

@MainActor
final class ImageBatchModel: ObservableObject {
    @Published private(set) var items: [ImageBatchItem] = []
    @Published var selection: UUID?
    let tool: ImageToolRoute
    @Published var options = ImageProcessingOptions() {
        didSet { if oldValue != options { invalidateResults() } }
    }
    @Published private(set) var isBusy = false
    @Published private(set) var isCancelling = false
    @Published private(set) var progressText = "导入 PNG / JPG 开始处理"
    @Published var notice = ""
    private let worker = DispatchQueue(label: "com.nstoolbox.images", qos: .userInitiated)
    private let cacheDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("NsToolBox-images-" + UUID().uuidString, isDirectory: true)
    private var task: Task<Void, Never>?
    private var revision = 0
    private var terminationObserver: NSObjectProtocol?

    init(tool: ImageToolRoute = .format) {
        self.tool = tool
        if tool == .cutout { options.cutout = .foreground }
        if tool == .resize { options.resize = .percentage }
        if tool == .compress { options.format = .jpeg }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cleanUpForTermination() }
        }
    }

    func cleanUpForTermination() {
        task?.cancel()
        let directory = cacheDirectory
        // Wait for the current system operation before deleting files it may still write.
        worker.sync { try? FileManager.default.removeItem(at: directory) }
    }

    var selectedItem: ImageBatchItem? { items.first { $0.id == selection } }
    var hasResults: Bool { items.contains { $0.resultURL != nil } }
    var canProcess: Bool { !isBusy && items.contains { $0.sourceURL != nil } }

    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        task?.cancel()
        let directory = cacheDirectory
        worker.async { try? FileManager.default.removeItem(at: directory) }
    }

    func importURLs(_ urls: [URL], displayNames: [URL: String] = [:], selectImported: Bool = false) {
        guard !isBusy, !urls.isEmpty else { return }
        let known = Set(items.map { $0.originalURL.standardizedFileURL.resolvingSymlinksInPath() })
        var seen = known
        let fresh = urls.filter { $0.isFileURL && seen.insert($0.standardizedFileURL.resolvingSymlinksInPath()).inserted }
        guard !fresh.isEmpty else { notice = "这些图片已在列表中，或不是本地文件"; return }
        isBusy = true; isCancelling = false; notice = ""
        let directory = cacheDirectory
        task = Task { [weak self] in
            guard let self else { return }
            for (index, url) in fresh.enumerated() {
                if Task.isCancelled { break }
                self.progressText = "正在导入 \(index + 1) / \(fresh.count)"
                let id = UUID()
                var item = ImageBatchItem(id: id, originalURL: url, displayName: displayNames[url])
                do {
                    let imported = try await self.work {
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let source = directory.appendingPathComponent(id.uuidString + ".source")
                        do {
                            // Keep a private snapshot so later external edits cannot change a pending job.
                            _ = try ImageProcessor.inspect(url: url)
                            try FileManager.default.copyItem(at: url, to: source)
                            let info = try ImageProcessor.inspect(url: source)
                            let preview = directory.appendingPathComponent(id.uuidString + "-original.png")
                            try info.thumbnailData.write(to: preview, options: .atomic)
                            return (source, preview, info)
                        } catch {
                            try? FileManager.default.removeItem(at: source)
                            throw error
                        }
                    }
                    item.sourceURL = imported.0; item.originalPreviewURL = imported.1; item.info = ImageInfo(width: imported.2.width, height: imported.2.height, fileBytes: imported.2.fileBytes, format: imported.2.format, thumbnailData: Data())
                } catch {
                    item.state = .failed; item.error = error.localizedDescription
                }
                self.items.append(item)
                if self.selection == nil || selectImported { self.selection = id }
            }
            self.finish(Task.isCancelled ? "已停止导入，已导入的图片保留" : "已导入 \(self.items.count) 张图片")
        }
    }

    func processAll() {
        guard canProcess else { return }
        let requestedOptions = options
        let ids = items.filter { $0.sourceURL != nil }.map(\.id)
        invalidateResults()
        let processingRevision = revision
        isBusy = true; isCancelling = false; notice = ""
        let directory = cacheDirectory
        task = Task { [weak self] in
            guard let self else { return }
            var completed = 0, failed = 0
            for (index, id) in ids.enumerated() {
                guard !Task.isCancelled, self.revision == processingRevision,
                      let position = self.items.firstIndex(where: { $0.id == id }), let source = self.items[position].sourceURL else { break }
                let settings = self.tool.processingOptions(from: requestedOptions, sourceFormat: self.items[position].info!.format)
                self.items[position].state = .processing
                self.progressText = "正在处理 \(index + 1) / \(ids.count) · \(self.items[position].name)"
                do {
                    let result = try await self.work {
                        try autoreleasepool {
                            let image = try ImageProcessor.process(url: source, options: settings)
                            let output = directory.appendingPathComponent(id.uuidString + "-\(processingRevision)-result." + image.format.fileExtension)
                            let preview = directory.appendingPathComponent(id.uuidString + "-result-preview.png")
                            try image.data.write(to: output, options: .atomic)
                            try image.thumbnailData.write(to: preview, options: .atomic)
                            return (output, preview, image.width, image.height, image.data.count, image.format)
                        }
                    }
                    if Task.isCancelled || self.revision != processingRevision {
                        try? FileManager.default.removeItem(at: result.0)
                        try? FileManager.default.removeItem(at: result.1)
                        self.items[position].state = .waiting
                        break
                    }
                    self.items[position].resultURL = result.0
                    self.items[position].resultPreviewURL = result.1
                    self.items[position].resultWidth = result.2; self.items[position].resultHeight = result.3
                    self.items[position].resultBytes = result.4; self.items[position].resultFormat = result.5
                    self.items[position].state = .ready
                    completed += 1
                } catch {
                    if Task.isCancelled || self.revision != processingRevision {
                        self.items[position].state = .waiting
                        break
                    }
                    self.items[position].state = .failed
                    self.items[position].error = error.localizedDescription
                    failed += 1
                }
            }
            self.finish(Task.isCancelled ? "已取消，已完成结果保留" : "处理完成：成功 \(completed)，失败 \(failed)")
        }
    }

    func export(to directory: URL) {
        guard !isBusy, hasResults else { return }
        let exports = items.compactMap { item -> (UUID, URL, String)? in
            guard let result = item.resultURL else { return nil }
            return (item.id, result, URL(fileURLWithPath: item.name).deletingPathExtension().lastPathComponent + "_processed")
        }
        isBusy = true; isCancelling = false; notice = ""
        task = Task { [weak self] in
            guard let self else { return }
            var count = 0, failures = 0
            for (index, job) in exports.enumerated() {
                if Task.isCancelled { break }
                self.progressText = "正在导出 \(index + 1) / \(exports.count)"
                do {
                    let destination = try await self.work {
                        let scoped = directory.startAccessingSecurityScopedResource()
                        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
                        return try ImageExport.copyWithoutReplacing(source: job.1, directory: directory, baseName: job.2)
                    }
                    if let position = self.items.firstIndex(where: { $0.id == job.0 }) {
                        self.items[position].exportedURL = destination
                        self.items[position].state = .exported; self.items[position].error = nil
                    }
                    count += 1
                } catch {
                    if let position = self.items.firstIndex(where: { $0.id == job.0 }) {
                        self.items[position].error = "导出失败：" + error.localizedDescription
                        self.items[position].state = .failed
                    }
                    failures += 1
                }
            }
            self.finish(Task.isCancelled ? "已停止导出，已保存文件保留" : "导出完成：成功 \(count)，失败 \(failures)")
        }
    }

    func cancel() {
        guard isBusy else { return }
        isCancelling = true; task?.cancel()
        progressText = "正在取消，等待当前图片处理结束…"
    }

    func removeSelected() {
        guard !isBusy, let id = selection, let position = items.firstIndex(where: { $0.id == id }) else { return }
        discard(items.remove(at: position))
        selection = items.first?.id
    }

    func clearAll() {
        guard !isBusy else { return }
        items.forEach(discard); items = []; selection = nil
        progressText = "导入 PNG / JPG 开始处理"; notice = ""
    }

    private func invalidateResults() {
        revision += 1
        if isBusy { task?.cancel(); isCancelling = true }
        for index in items.indices where items[index].sourceURL != nil {
            for url in [items[index].resultURL, items[index].resultPreviewURL].compactMap({ $0 }) { try? FileManager.default.removeItem(at: url) }
            items[index].resultURL = nil; items[index].resultPreviewURL = nil
            items[index].resultWidth = nil; items[index].resultHeight = nil; items[index].resultBytes = nil; items[index].resultFormat = nil
            items[index].exportedURL = nil; items[index].error = nil; items[index].state = .waiting
        }
        if !isBusy && !items.isEmpty { progressText = "参数已更新，请重新处理" }
    }

    private func discard(_ item: ImageBatchItem) {
        for url in [item.sourceURL, item.originalPreviewURL, item.resultURL, item.resultPreviewURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func finish(_ message: String) {
        for index in items.indices where items[index].state == .processing { items[index].state = .waiting }
        isBusy = false; isCancelling = false; progressText = message; task = nil
    }

    private func work<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            worker.async { continuation.resume(with: Result(catching: operation)) }
        }
    }
}

/// copyItem is exclusive: a competing writer can never be overwritten between checking and copying.
enum ImageExport {
    static func copyWithoutReplacing(source: URL, directory: URL, baseName: String) throws -> URL {
        for index in 0..<100_000 {
            let name = baseName + (index == 0 ? "" : "_\(index)") + "." + source.pathExtension
            let target = directory.appendingPathComponent(name)
            do { try FileManager.default.copyItem(at: source, to: target); return target }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
        }
        throw NSError(domain: "NsToolBox.Images", code: 1, userInfo: [NSLocalizedDescriptionKey: "同名文件过多，请选择其他目录"])
    }
}
