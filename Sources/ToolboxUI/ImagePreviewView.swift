import AppKit
import ImageIO
import SwiftUI
import ToolboxImages

struct ImagePreviewView: View {
    let item: ImageBatchItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ImagePreviewPane(title: "原图", url: item?.originalPreviewURL,
                                 metadata: originalMetadata,
                                 placeholder: item == nil ? "选择图片查看预览" : "原图无法预览")
                Divider()
                ImagePreviewPane(title: "处理结果", url: item?.resultPreviewURL,
                                 metadata: resultMetadata, placeholder: resultPlaceholder)
            }.frame(maxHeight: .infinity)
            if let error = item?.error {
                Divider()
                ScrollView {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(error).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: 12)).padding(10)
                }.frame(maxHeight: 88)
                .background(Color.red.opacity(0.04))
            }
        }
    }

    private var originalMetadata: String {
        guard let info = item?.info else { return item == nil ? "PNG / JPG" : "无法读取图片信息" }
        return "\(info.width) × \(info.height) px · \(info.format.rawValue)\n\(bytes(info.fileBytes))"
    }

    private var resultMetadata: String {
        guard let item, let width = item.resultWidth, let height = item.resultHeight, let count = item.resultBytes else {
            return "处理后显示尺寸与体积"
        }
        var detail = "\(width) × \(height) px · \(item.resultFormat?.rawValue ?? "")\n\(bytes(count))"
        if let original = item.info?.fileBytes, original > 0 {
            let change = (Double(count) / Double(original) - 1) * 100
            detail += "（\(change >= 0 ? "+" : "")\(Int(change.rounded()))%）"
        }
        return detail
    }

    private var resultPlaceholder: String {
        guard let item else { return "结果将在这里显示" }
        switch item.state {
        case .processing: return "正在处理…"
        case .failed: return "请查看下方错误原因"
        default: return "使用上方操作按钮生成结果"
        }
    }

    private func bytes(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}

private struct ImagePreviewPane: View {
    let title: String
    let url: URL?
    let metadata: String
    let placeholder: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).frame(height: WorkspaceStyle.paneHeaderHeight)
                .background(WorkspaceStyle.chrome)
            Divider()
            GeometryReader { geometry in
                ZStack {
                    Checkerboard().accessibilityHidden(true)
                    if let image = decodedPreview {
                        Image(decorative: image, scale: 1).renderingMode(.original).resizable().scaledToFit()
                            .padding(12).accessibilityLabel("\(title)缩略图")
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo").font(.system(size: 24))
                            Text(placeholder).font(.system(size: 12)).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary).padding(12)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            Divider()
            Text(metadata).font(.system(size: 11)).monospacedDigit()
                .foregroundStyle(.secondary).textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 4)
        }.frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var decodedPreview: CGImage? {
        guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // These files are bounded thumbnails. Decode pixels explicitly rather than asking
        // NSImage to choose an appearance-dependent or lazily loaded representation.
        return CGImageSourceCreateImageAtIndex(source, 0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 12
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(nsColor: .textBackgroundColor)))
            for row in 0..<Int(ceil(size.height / cell)) {
                for column in 0..<Int(ceil(size.width / cell)) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.12)))
                }
            }
        }
    }
}
