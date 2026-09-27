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
    @State private var cropRatio = ImageCropRatio.free

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
                if model.tool != .info {
                    Button(model.tool.actionTitle, systemImage: "play.fill", action: model.processAll)
                        .buttonStyle(.borderedProminent)
                        .tint(WorkspaceStyle.accent)
                        .disabled(!model.canProcess)
                }
                if let useResult, model.tool != .info {
                    if !model.isBusy && model.selectedItem?.resultURL != nil {
                        Menu {
                            ForEach(ImageToolRoute.allCases.filter { $0 != model.tool }) { tool in
                                Button(tool.rawValue) { useResult(tool) }
                            }
                        } label: {
                            Label("继续处理", systemImage: "arrowshape.turn.up.right")
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 124)
                        .help("把选中图片的结果复制到另一个工具，随后手动开始处理")
                    } else {
                        Label("继续处理", systemImage: "arrowshape.turn.up.right")
                            .foregroundStyle(.tertiary)
                            .frame(width: 124, height: 24)
                            .accessibilityLabel("继续处理：需要选中处理结果")
                    }
                }
                if model.tool != .info {
                    Button("导出结果…", systemImage: "square.and.arrow.up", action: chooseExportDirectory)
                        .disabled(model.isBusy || !model.hasResults)
                }
            }
            Divider()
            parameters
                .disabled(model.isBusy)
            Divider()
            HStack(spacing: 0) {
                queue.frame(width: 184)
                Divider()
                if model.tool == .info {
                    ImageInformationView(item: model.selectedItem)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ImagePreviewView(item: model.selectedItem)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isDropTarget && !model.isBusy {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(WorkspaceStyle.accent.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(WorkspaceStyle.accent, lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            Divider()
            WorkspaceStatus(message: model.notice.isEmpty ? model.progressText : model.notice,
                            isError: !model.notice.isEmpty, isProcessing: model.isBusy,
                            counts: model.tool == .info
                                ? "\(model.items.count) 张 · \(model.items.filter { $0.state == .read }.count) 张已读取"
                                : "\(model.items.count) 张 · \(model.items.filter { $0.resultURL != nil }.count) 个结果")
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
        ScrollView(.horizontal, showsIndicators: true) { HStack(spacing: 0) {
            ForEach(ImageToolRoute.allCases) { route in
                Button { selectTool?(route) } label: {
                    Text(route.rawValue)
                        .font(.system(size: 12, weight: model.tool == route ? .medium : .regular))
                        .frame(width: 100, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(WorkspaceNavigationButtonStyle(isSelected: model.tool == route))
                .frame(width: 104, height: WorkspaceStyle.tabHeight)
                .disabled(model.isBusy)
                .accessibilityIdentifier("image-tab-\(route.id)")
                .accessibilityAddTraits(model.tool == route ? [.isSelected] : [])
                .help(route == model.tool ? operationSummary : "切换到\(route.rawValue)")
            }
        }}
        .background(WorkspaceStyle.chrome)
    }

    private var parameters: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch model.tool {
            case .cutout:
                HStack(spacing: 10) {
                    Text("去背景方式").foregroundStyle(.secondary)
                    Picker("去背景方式", selection: $model.options.cutout) {
                        ForEach([ImageCutoutMode.foreground, .person, .whiteBackground]) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 310)
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                        .help("输出透明 PNG，保留原尺寸；无可用主体时显示失败原因")
                }
                if model.options.cutout == .whiteBackground {
                    HStack(spacing: 12) {
                        Text("白色容差")
                        Slider(value: $model.options.whiteTolerance, in: 0...0.3, step: 0.01)
                            .frame(width: 220).accessibilityLabel("去白底容差")
                        Text("\(Int((model.options.whiteTolerance * 100).rounded()))%")
                            .monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                    Text("容差增大也可能去除主体中的白色").foregroundStyle(.secondary)
                }
            case .resize:
                HStack(spacing: 10) {
                    Text("缩放方式").foregroundStyle(.secondary)
                    Picker("缩放方式", selection: $model.options.resize) {
                        ForEach(ImageResizeMode.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 310)
                }
                resizeParameters
            case .format:
                outputFormatPicker
                Text(model.options.format == .png
                     ? "格式转换会保留原背景；需要透明背景请使用「抠图」。"
                     : "JPG 不支持透明度；透明区域将与所选底色合成。")
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
                     ? "降低质量通常会减小体积，同时损失细节；以结果实际体积为准。"
                     : "PNG 可能保留原始数据，不保证体积更小。")
                    .foregroundStyle(.secondary)
            case .edit:
                editParameters
            case .info:
                Text("选择图片查看实际格式、尺寸、色彩与像素透明度")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12)).controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var editParameters: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Toggle("启用裁剪", isOn: Binding(get: { model.editOptions.crop != nil }, set: { enabled in
                    guard enabled, let info = model.selectedItem?.info else { model.editOptions.crop = nil; return }
                    model.editOptions.crop = ImagePixelRect(x: 0, y: 0, width: info.width, height: info.height)
                })).toggleStyle(.checkbox).disabled(model.selectedItem?.info == nil)
                Picker("比例", selection: $cropRatio) {
                    ForEach(ImageCropRatio.allCases) { ratio in Text(ratio.rawValue).tag(ratio) }
                }.frame(width: 155)
                .onChange(of: cropRatio) { _, ratio in applyCropRatio(ratio) }
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                    .help("坐标从归一化图片左上角开始，单位 px")
            }
            if model.editOptions.crop != nil {
                HStack(spacing: 7) {
                    Text("X")
                    cropField(\.x, label: "裁剪 X")
                    Text("Y")
                    cropField(\.y, label: "裁剪 Y")
                    Text("宽")
                    cropField(\.width, label: "裁剪宽度")
                    Text("高")
                    cropField(\.height, label: "裁剪高度")
                }
            }
            HStack(spacing: 10) {
                Button("左转 90°") { model.editOptions.quarterTurns -= 1 }
                Button("右转 90°") { model.editOptions.quarterTurns += 1 }
                Toggle("水平翻转", isOn: $model.editOptions.flipHorizontal).toggleStyle(.checkbox)
                Toggle("垂直翻转", isOn: $model.editOptions.flipVertical).toggleStyle(.checkbox)
                Text("当前顺时针 \(((model.editOptions.quarterTurns % 4) + 4) % 4 * 90)°")
                    .foregroundStyle(.secondary)
            }
            Text("先裁剪、再旋转、最后翻转；输出原格式。")
                .foregroundStyle(.secondary)
        }
    }

    private func cropField(_ keyPath: WritableKeyPath<ImagePixelRect, Int>, label: String) -> some View {
        TextField(label, value: Binding(get: { model.editOptions.crop?[keyPath: keyPath] ?? 0 }, set: { value in
            guard var crop = model.editOptions.crop else { return }
            crop[keyPath: keyPath] = value
            model.editOptions.crop = crop
        }), format: .number.grouping(.never))
        .frame(width: 62).textFieldStyle(.roundedBorder).accessibilityLabel(label)
    }

    private func applyCropRatio(_ ratio: ImageCropRatio) {
        guard let shape = ratio.shape, let info = model.selectedItem?.info else { return }
        let width = min(info.width, Int((Double(info.height) * shape).rounded(.down)))
        let height = min(info.height, Int((Double(info.width) / shape).rounded(.down)))
        let size: (Int, Int) = Double(info.width) / Double(info.height) >= shape
            ? (max(1, width), info.height) : (info.width, max(1, height))
        model.editOptions.crop = ImagePixelRect(x: (info.width - size.0) / 2, y: (info.height - size.1) / 2,
                                                width: size.0, height: size.1)
    }

    @ViewBuilder private var resizeParameters: some View {
        switch model.options.resize {
        case .original:
            EmptyView()
        case .percentage:
            HStack(spacing: 8) {
                Text("比例")
                TextField("百分比", value: $model.options.percentage, format: .number)
                    .frame(width: 76).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("缩放百分比")
                Text("%")
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
        }
    }

    private var queue: some View {
        VStack(spacing: 0) {
            HStack {
                Text("图片列表").fontWeight(.semibold)
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
            }.pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 180)
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
        case .edit: return "先裁剪、再旋转、最后翻转 · 输出原格式 · 不执行抠图"
        case .info: return "读取实际文件内容和像素透明度 · 不产生处理结果"
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

private enum ImageCropRatio: String, CaseIterable, Identifiable {
    case free = "自由", square = "1:1", photo = "4:3", wide = "16:9", classic = "3:2"
    var id: String { rawValue }
    var shape: Double? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .photo: return 4.0 / 3
        case .wide: return 16.0 / 9
        case .classic: return 3.0 / 2
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
        case .read: return "checkmark.circle.fill"
        }
    }
}
