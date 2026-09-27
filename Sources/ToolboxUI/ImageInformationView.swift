import Foundation
import ImageIO
import SwiftUI

struct ImageInformationView: View {
    let item: ImageBatchItem?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("原图预览")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).frame(height: WorkspaceStyle.paneHeaderHeight)
                    .background(WorkspaceStyle.chrome)
                Divider()
                if let image = preview {
                    ZStack {
                        Checkerboard().accessibilityHidden(true)
                        Image(decorative: image, scale: 1).renderingMode(.original)
                            .resizable().scaledToFit().padding(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("选择图片查看信息", systemImage: "photo")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("图片信息").font(.headline)
                if let info = item?.info {
                    informationRow("实际格式", info.format.rawValue)
                    informationRow("方向归一化尺寸", "\(info.width) × \(info.height) px")
                    informationRow("文件体积", "\(info.fileBytes) 字节 · " + ByteCountFormatter.string(fromByteCount: Int64(info.fileBytes), countStyle: .file))
                    informationRow("色彩", info.colorDescription)
                    informationRow("透明度", info.transparency.rawValue)
                    Text("透明度按完整图像像素检查。文件扩展名和 PNG 格式本身不能证明背景透明。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if let error = item?.error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                } else {
                    Text("导入 PNG 或 JPG 后显示文件真实信息。")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 12)).padding(16)
            .frame(width: 280).frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func informationRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private var preview: CGImage? {
        guard let url = item?.originalPreviewURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}
