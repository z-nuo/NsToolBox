import AppKit
import SwiftUI
import ToolboxImages
import UniformTypeIdentifiers

struct ImageWorkspaceView: View {
    @ObservedObject var workspace: ImageWorkspaceModel

    var body: some View {
        ImageToolView(model: workspace.activeModel, selectTool: workspace.select,
                      useResult: workspace.useSelectedResult)
            .id(workspace.selectedTool)
    }
}

struct ImageToolView: View {
    @ObservedObject var model: ImageBatchModel
    var selectTool: ((ImageToolRoute) -> Void)? = nil
    var useResult: ((ImageToolRoute) -> Void)? = nil
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            tabs
            Divider()
            WorkspaceToolbar {
                Button("添加图片…", systemImage: "plus", action: chooseImages)
                    .disabled(model.isBusy)
                Spacer(minLength: 8)
                if model.isBusy {
                    Button(model.isCancelling ? "正在取消…" : "取消", action: model.cancel)
                        .disabled(model.isCancelling)
                }
                Button(model.tool.actionTitle, systemImage: "play.fill", action: model.processAll)
                    .disabled(!model.canProcess)
                if let useResult {
                    Menu("将此结果用于…") {
                        ForEach(ImageToolRoute.allCases.filter { $0 != model.tool }) { tool in
                            Button(tool.rawValue) { useResult(tool) }
                        }
                    }
                    .disabled(model.isBusy || model.selectedItem?.resultURL == nil)
                    .help("把选中图片的结果复制到另一个工具，随后手动开始处理")
                }
                Button("导出结果…", systemImage: "square.and.arrow.up", action: chooseExportDirectory)
                    .disabled(model.isBusy || !model.hasResults)
            }
            Divider()
            parameters
                .disabled(model.isBusy)
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text(operationSummary)
                    .lineLimit(2).help(operationSummary)
                Spacer(minLength: 0)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(WorkspaceStyle.chrome)
            Divider()
            HStack(spacing: 0) {
                queue.frame(width: 192)
                Divider()
                ImagePreviewView(item: model.selectedItem)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isDropTarget && !model.isBusy {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            Divider()
            WorkspaceStatus(message: model.notice.isEmpty ? model.progressText : model.notice,
                            isError: !model.notice.isEmpty, isProcessing: model.isBusy,
                            counts: "\(model.items.count) 张 · \(model.items.filter { $0.resultURL != nil }.count) 个结果")
        }
        .background(WorkspaceStyle.background)
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.isBusy else { return false }
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            model.importURLs(files)
            return true
        } isTargeted: { isDropTarget = $0 }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(ImageToolRoute.allCases) { route in
                Button { selectTool?(route) } label: {
                    Text(route.rawValue)
                        .font(.system(size: 12, weight: model.tool == route ? .medium : .regular))
                        .frame(width: 104, height: WorkspaceStyle.tabHeight)
                        .contentShape(Rectangle())
                        .background(model.tool == route ? WorkspaceStyle.background : .clear)
                        .overlay(alignment: .bottom) {
                            if model.tool == route { Color.accentColor.frame(height: 2) }
                        }
                }
                .buttonStyle(.plain)
                .disabled(model.isBusy)
                .accessibilityIdentifier("image-tab-\(route.id)")
                .accessibilityAddTraits(model.tool == route ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .background(WorkspaceStyle.chrome)
    }

    private var parameters: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch model.tool {
            case .cutout:
                Picker("去背景方式", selection: $model.options.cutout) {
                    ForEach([ImageCutoutMode.foreground, .person, .whiteBackground]) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 440)
                if model.options.cutout == .whiteBackground {
                    HStack(spacing: 12) {
                        Text("白色容差")
                        Slider(value: $model.options.whiteTolerance, in: 0...0.3, step: 0.01)
                            .frame(width: 220).accessibilityLabel("去白底容差")
                        Text("\(Int((model.options.whiteTolerance * 100).rounded()))%")
                            .monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                    Text("适合白底文字、图标；容差越大，去除的浅色越多，主体中的白色也会被去除。")
                        .foregroundStyle(.secondary)
                } else {
                    Text("照片使用自动去背景或人像抠图；白底文字、图标可选择「去白底」。")
                        .foregroundStyle(.secondary)
                    Text("输出透明 PNG，保留原尺寸；无可用主体时显示失败原因。")
                        .foregroundStyle(.secondary)
                }
            case .resize:
                Picker("缩放方式", selection: $model.options.resize) {
                    ForEach(ImageResizeMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 440)
                resizeParameters
                Text("保留每张原图的文件格式，仅调整尺寸。").foregroundStyle(.secondary)
            case .format:
                outputFormatPicker
                Text(model.options.format == .png
                     ? "PNG 支持透明，但格式转换会保留原背景，不会自动去底。"
                     : "JPG 不支持透明度，透明区域将与所选底色合成。")
                    .foregroundStyle(.secondary)
                Text("需要透明背景请使用「抠图」；白底文字、图标选择「去白底」。")
                    .foregroundStyle(.secondary)
            case .compress:
                outputFormatPicker
                HStack(spacing: 12) {
                    Text("JPG 质量")
                    Slider(value: $model.options.jpegQuality, in: 0.1...1, step: 0.01)
                        .frame(width: 220).accessibilityLabel("JPG 压缩质量")
                    Text("\(Int((model.options.jpegQuality * 100).rounded()))%")
                        .monospacedDigit().frame(width: 36, alignment: .trailing)
                }.disabled(model.options.format != .jpeg)
                Text(model.options.format == .jpeg
                     ? "降低质量通常会减小体积，同时损失图片细节。"
                     : "PNG 原图不抠图且尺寸、方向不变时保留原始数据，不保证更小。")
                    .foregroundStyle(.secondary)
                Text(model.options.format == .jpeg
                     ? "以处理结果的实际体积为准。"
                     : "可在上方选择 JPG，再调整质量和透明区域底色。")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12)).controlSize(.small)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    @ViewBuilder private var resizeParameters: some View {
        switch model.options.resize {
        case .original:
            Text("保持原始像素尺寸，自动校正图片方向。")
                .foregroundStyle(.secondary)
        case .percentage:
            HStack(spacing: 8) {
                Text("比例")
                TextField("百分比", value: $model.options.percentage, format: .number)
                    .frame(width: 76).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("缩放百分比")
                Text("%")
                Text("例如 50% 为原宽高的一半").foregroundStyle(.secondary)
            }
        case .dimensions:
            HStack(spacing: 8) {
                Text("宽")
                TextField("宽度", value: $model.options.width, format: .number.grouping(.never))
                    .frame(width: 68).accessibilityLabel("输出最大宽度")
                Text("× 高")
                TextField("高度", value: $model.options.height, format: .number.grouping(.never))
                    .frame(width: 68).accessibilityLabel("输出最大高度")
                Text("px").foregroundStyle(.secondary)
                Toggle("保持比例", isOn: $model.options.preserveAspect)
                    .toggleStyle(.checkbox)
            }.textFieldStyle(.roundedBorder)
            Text(model.options.preserveAspect ? "按比例适配宽高边界，不裁剪。" : "按指定宽高拉伸，图片比例可能改变。")
                .foregroundStyle(.secondary)
        }
    }

    private var queue: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.tool.rawValue + "图片").fontWeight(.medium)
                Spacer()
                Text("\(model.items.count)").foregroundStyle(.secondary)
            }
            .font(.system(size: 11)).padding(.horizontal, 10)
            .frame(height: WorkspaceStyle.paneHeaderHeight)
            .background(WorkspaceStyle.chrome)
            Divider()
            if model.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 28))
                    Text("拖入 PNG / JPG\n或点击「添加图片」")
                        .multilineTextAlignment(.center).font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $model.selection) {
                    ForEach(model.items) { item in
                        ImageQueueRow(item: item).tag(item.id)
                    }
                }.listStyle(.inset).accessibilityLabel("待处理图片列表")
            }
            Divider()
            HStack {
                Button("删除选中", action: model.removeSelected).disabled(model.selection == nil)
                Spacer(minLength: 0)
                Button("清空", action: model.clearAll).disabled(model.items.isEmpty)
            }
            .controlSize(.small).font(.system(size: 11))
            .padding(8).disabled(model.isBusy)
            .background(WorkspaceStyle.chrome)
        }
    }

    private var backgroundColor: Binding<Color> {
        Binding {
            let color = model.options.background
            return Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
        } set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            model.options.background = ImageBackground(red: Double(rgb.redComponent),
                                                       green: Double(rgb.greenComponent),
                                                       blue: Double(rgb.blueComponent))
        }
    }

    private var outputFormatPicker: some View {
        HStack(spacing: 12) {
            Picker("输出格式", selection: $model.options.format) {
                ForEach(ImageOutputFormat.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(width: 180)
            if model.options.format == .jpeg {
                ColorPicker("透明区域底色", selection: backgroundColor, supportsOpacity: false)
                    .fixedSize()
            }
        }
    }

    private var operationSummary: String {
        switch model.tool {
        case .cutout: return "仅抠图 · 输出透明 PNG · 不改变尺寸"
        case .resize: return "仅调整尺寸 · 保留原格式 · 不执行抠图"
        case .format: return "仅转换格式 · 保留原尺寸 · 不执行抠图"
        case .compress: return "仅按当前格式和质量输出 · 保留原尺寸 · 不执行抠图"
        }
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.title = "添加图片"
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK { model.importURLs(panel.urls) }
        }
    }

    private func chooseExportDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择结果导出目录"
        panel.prompt = "导出结果"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let directory = panel.url { model.export(to: directory) }
        }
    }
}

private struct ImageQueueRow: View {
    let item: ImageBatchItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                .help(item.name)
            HStack(spacing: 4) {
                Image(systemName: stateSymbol)
                Text(item.state.rawValue)
                Spacer(minLength: 0)
                if let info = item.info { Text(info.format.rawValue) }
            }
            .font(.system(size: 10)).foregroundStyle(item.error == nil ? Color.secondary : Color.red)
            if let error = item.error {
                Text(error).font(.system(size: 10)).foregroundStyle(.red)
                    .lineLimit(2).help(error)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var stateSymbol: String {
        switch item.state {
        case .waiting: return "clock"
        case .processing: return "gearshape.2"
        case .ready: return "checkmark.circle"
        case .exported: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }
}
