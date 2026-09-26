import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Synchronous, local image processing. Call from a background serial queue.
public enum ImageProcessor {
    private static let pixelLimit = 40_000_000
    private static let dimensionLimit = 16_384
    private static let thumbnailLimit = 1000

    public static func inspect(url: URL) throws -> ImageInfo {
        try autoreleasepool {
            let input = try Input(url: url)
            let thumbnail = try input.decode(maxDimension: thumbnailLimit)
            let bytes: Int
            do { bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0 }
            catch { throw ProcessingError("无法读取图片文件体积：\(error.localizedDescription)") }
            return ImageInfo(width: input.width, height: input.height, fileBytes: bytes,
                             format: input.format, thumbnailData: try encode(thumbnail, format: .png, quality: 1))
        }
    }

    public static func process(url: URL, options: ImageProcessingOptions) throws -> ProcessedImage {
        try autoreleasepool {
            let input = try Input(url: url)
            let size = try outputSize(width: input.width, height: input.height, options: options)
            if options.format == .jpeg {
                guard options.jpegQuality.isFinite, (0...1).contains(options.jpegQuality) else {
                    throw ProcessingError("JPG 质量必须在 0 到 1 之间。")
                }
                guard [options.background.red, options.background.green, options.background.blue]
                    .allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
                    throw ProcessingError("JPG 底色的 RGB 值必须在 0 到 1 之间。")
                }
            }
            // A pixel-preserving PNG operation must also preserve bit depth,
            // color profile and metadata. Only the preview is decoded separately.
            // Non-up EXIF orientation is an actual pixel transform and goes below.
            if input.format == .png, options.format == .png, options.cutout == .none,
               input.orientation == 1, size.width == input.width, size.height == input.height {
                let thumbnail = try input.decode(maxDimension: thumbnailLimit)
                let data: Data
                do { data = try Data(contentsOf: url) }
                catch { throw ProcessingError("无法读取 PNG 原始数据：\(error.localizedDescription)") }
                return ProcessedImage(data: data, thumbnailData: try encode(thumbnail, format: .png, quality: 1),
                                      width: size.width, height: size.height, format: .png)
            }
            // ImageIO applies EXIF orientation before Vision, resizing and export.
            let original = try input.decode(maxDimension: max(input.width, input.height))
            let image = options.cutout == .none ? original : try removeBackground(original, mode: options.cutout,
                                                                                 whiteTolerance: options.whiteTolerance)
            let rendered = try render(image, width: size.width, height: size.height,
                                      background: options.format == .jpeg ? options.background : nil)
            let data = try encode(rendered, format: options.format, quality: options.jpegQuality)
            // Build preview from the encoded result, including actual JPEG compression.
            guard let resultSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw ProcessingError("无法生成结果预览。")
            }
            let thumbnail = try decodeThumbnail(resultSource, maxDimension: thumbnailLimit)
            return ProcessedImage(data: data, thumbnailData: try encode(thumbnail, format: .png, quality: 1),
                                  width: size.width, height: size.height, format: options.format)
        }
    }

    private struct ProcessingError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    private struct Input {
        let source: CGImageSource
        let width: Int
        let height: Int
        let format: ImageOutputFormat
        let orientation: Int

        init(url: URL) throws {
            guard url.isFileURL,
                  let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
                throw ProcessingError("无法读取图片，请选择有效的 PNG 或 JPG 文件。")
            }
            guard let type = CGImageSourceGetType(source) else { throw ProcessingError("无法识别图片格式。") }
            if type == UTType.png.identifier as CFString { format = .png }
            else if type == UTType.jpeg.identifier as CFString { format = .jpeg }
            else { throw ProcessingError("仅支持 PNG 和 JPG 图片；文件内容与扩展名可能不一致。") }
            guard CGImageSourceGetCount(source) == 1 else { throw ProcessingError("不支持多帧或动画图片，请先导出单帧 PNG / JPG。") }
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let rawWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
                  let rawHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
                  rawWidth.isFinite, rawHeight.isFinite, rawWidth >= 1, rawHeight >= 1 else {
                throw ProcessingError("无法读取图片尺寸，文件可能已损坏。")
            }
            // Validate before any full-size pixel allocation or numeric conversion.
            guard rawWidth * rawHeight <= Double(pixelLimit) else {
                throw ProcessingError("图片超过单张 4000 万像素上限，请先降低分辨率。")
            }
            orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            if (5...8).contains(orientation) { width = Int(rawHeight); height = Int(rawWidth) }
            else { width = Int(rawWidth); height = Int(rawHeight) }
            self.source = source
        }
        func decode(maxDimension: Int) throws -> CGImage { try decodeThumbnail(source, maxDimension: maxDimension) }
    }

    private static func decodeThumbnail(_ source: CGImageSource, maxDimension: Int) throws -> CGImage {
        let parameters: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, parameters as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw ProcessingError("图片解码失败，文件可能已损坏或不完整。")
        }
        return image
    }

    private static func outputSize(width: Int, height: Int, options: ImageProcessingOptions) throws -> (width: Int, height: Int) {
        var w = Double(width), h = Double(height)
        switch options.resize {
        case .original: break
        case .percentage:
            guard options.percentage.isFinite, options.percentage > 0 else {
                throw ProcessingError("缩放百分比必须是大于 0 的有限数值。")
            }
            let scale = options.percentage / 100
            w *= scale; h *= scale
        case .dimensions:
            guard options.width > 0, options.height > 0 else { throw ProcessingError("目标宽高必须大于 0。") }
            if options.preserveAspect {
                let scale = min(Double(options.width) / w, Double(options.height) / h)
                w *= scale; h *= scale
            } else { w = Double(options.width); h = Double(options.height) }
        }
        guard w.isFinite, h.isFinite else { throw ProcessingError("缩放结果过大，请减小目标尺寸。") }
        w = max(1, w.rounded()); h = max(1, h.rounded())
        guard w <= Double(dimensionLimit), h <= Double(dimensionLimit) else {
            throw ProcessingError("缩放输出单边不能超过 16384 像素。")
        }
        guard w * h <= Double(pixelLimit) else { throw ProcessingError("缩放输出不能超过 4000 万像素。") }
        return (Int(w), Int(h))
    }

    private static func render(_ image: CGImage, width: Int, height: Int, background: ImageBackground?) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ProcessingError("无法分配图片处理内存，请降低图片尺寸。")
        }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        if let background {
            context.setFillColor(red: background.red, green: background.green, blue: background.blue, alpha: 1)
            context.fill(rect)
        }
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        guard let output = context.makeImage() else { throw ProcessingError("无法生成处理后的图片。") }
        return output
    }

    private static func encode(_ image: CGImage, format: ImageOutputFormat, quality: Double) throws -> Data {
        let data = NSMutableData()
        let type = (format == .png ? UTType.png : UTType.jpeg).identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { throw ProcessingError("无法创建图片编码器。") }
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        if format == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ProcessingError("图片编码失败。") }
        return data as Data
    }

    private static func removeWhiteBackground(_ image: CGImage, tolerance: Double) throws -> CGImage {
        guard tolerance.isFinite, (0...0.3).contains(tolerance) else {
            throw ProcessingError("去白底容差必须在 0% 到 30% 之间。")
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { throw ProcessingError("无法分配去白底内存，请降低图片尺寸。") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        for offset in stride(from: 0, to: image.width * image.height * 4, by: 4) {
            let alpha = Double(pixels[offset + 3])
            guard alpha > 0 else { continue }
            let darkest = Double(min(pixels[offset], pixels[offset + 1], pixels[offset + 2])) / alpha
            let distance = 1 - darkest
            let mask = min(1, max(0, (distance - tolerance) / 0.05))
            guard mask < 1 else { continue }
            // Remove the white matte from premultiplied colors as alpha is reduced.
            // This retains existing alpha and avoids baking white into the soft edge.
            let white = (1 - mask) * alpha
            for channel in 0..<3 {
                pixels[offset + channel] = UInt8(max(0, Double(pixels[offset + channel]) - white).rounded())
            }
            pixels[offset + 3] = UInt8((alpha * mask).rounded())
        }
        guard let result = context.makeImage() else { throw ProcessingError("无法生成去白底结果。") }
        return result
    }

    private static func removeBackground(_ image: CGImage, mode: ImageCutoutMode, whiteTolerance: Double) throws -> CGImage {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let mask: CVPixelBuffer
        do {
            switch mode {
            case .foreground:
                let request = VNGenerateForegroundInstanceMaskRequest()
                try handler.perform([request])
                guard let result = request.results?.first, !result.allInstances.isEmpty else {
                    throw ProcessingError("未检测到可分离的主体。白底文字或图标请尝试「去白底」，人物照片可尝试人像模式。")
                }
                mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            case .person:
                let request = VNGeneratePersonSegmentationRequest()
                request.qualityLevel = .accurate
                request.outputPixelFormat = kCVPixelFormatType_OneComponent8
                try handler.perform([request])
                guard let result = request.results?.first else { throw ProcessingError("未检测到人像，请尝试更清晰的人像图片。") }
                mask = result.pixelBuffer
            case .whiteBackground: return try removeWhiteBackground(image, tolerance: whiteTolerance)
            case .none: return image
            }
        } catch let error as ProcessingError { throw error }
        catch {
            let systemError = error as NSError
            let suggestion = mode == .foreground ? "可尝试人像模式；该模式只分割人物。" : "请尝试其他图片或关闭抠图。"
            throw ProcessingError("Vision \(mode.rawValue)失败（\(systemError.domain) \(systemError.code)）：\(systemError.localizedDescription)。\(suggestion)")
        }
        guard try containsSubject(mask) else {
            throw ProcessingError(mode == .person ? "未检测到人像，请尝试更清晰的人像图片。" : "未检测到可分离的主体。")
        }
        let original = CIImage(cgImage: image)
        let maskImage = CIImage(cvPixelBuffer: mask)
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: CGFloat(image.width) / maskImage.extent.width,
                                                                     y: CGFloat(image.height) / maskImage.extent.height))
        let output = original.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: original.extent),
            kCIInputMaskImageKey: scaledMask
        ])
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let result = context.createCGImage(output, from: original.extent) else { throw ProcessingError("Vision 蒙版合成失败。") }
        return result
    }

    private static func containsSubject(_ mask: CVPixelBuffer) throws -> Bool {
        guard CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { throw ProcessingError("无法读取 Vision 蒙版。") }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { throw ProcessingError("Vision 蒙版为空。") }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        let format = CVPixelBufferGetPixelFormatType(mask)
        for y in 0..<height {
            let row = base.advanced(by: y * stride)
            if format == kCVPixelFormatType_OneComponent8 {
                let values = row.assumingMemoryBound(to: UInt8.self)
                for x in 0..<width where values[x] >= 13 { return true }
            } else if format == kCVPixelFormatType_OneComponent32Float {
                let values = row.assumingMemoryBound(to: Float.self)
                for x in 0..<width where values[x].isFinite && values[x] >= 0.05 { return true }
            } else { throw ProcessingError("Vision 返回了不支持的蒙版像素格式：\(format)。") }
        }
        return false
    }
}
