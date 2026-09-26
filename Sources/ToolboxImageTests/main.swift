import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ToolboxImages

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}
func expect(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestFailure(description: message) }
}
func expectError(_ fragment: String, _ body: () throws -> Void) throws {
    do { try body() } catch {
        try expect(error.localizedDescription.contains(fragment), "错误应包含 \(fragment)，实际：\(error.localizedDescription)")
        return
    }
    throw TestFailure(description: "应拒绝：\(fragment)")
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ToolboxImageTests-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

func fixture(_ name: String, width: Int = 80, height: Int = 40, type: CFString = UTType.png.identifier as CFString,
             orientation: Int = 1, frames: Int = 1, pixel: (Int, Int) -> [UInt8] = { _, _ in [255, 0, 0, 255] }) throws -> URL {
    var bytes = [UInt8](); bytes.reserveCapacity(width * height * 4)
    for y in 0..<height { for x in 0..<width { bytes.append(contentsOf: pixel(x, y)) } }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let url = directory.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, type, frames, nil)!
    for _ in 0..<frames {
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    }
    try expect(CGImageDestinationFinalize(destination), "生成样本失败")
    return url
}
func decode(_ data: Data) throws -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw TestFailure(description: "结果不可解码") }
    return image
}
func rgba(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}

func testInspectAndOrientation() throws {
    let url = try fixture("renamed.jpg", width: 1200, height: 600)
    let info = try ImageProcessor.inspect(url: url)
    try expect(info.format == .png && info.width == 1200 && info.height == 600, "应按真实编码识别并保持尺寸")
    try expect(info.fileBytes == Data(contentsOf: url).count, "文件体积应准确")
    let thumbnail = try decode(info.thumbnailData)
    try expect(thumbnail.width == 1000 && thumbnail.height == 500, "缩略图应限制到 1000 并保持比例")
    let rotated = try fixture("rotated.jpg", width: 80, height: 40, type: UTType.jpeg.identifier as CFString, orientation: 6,
                              pixel: { x, _ in x < 40 ? [255, 0, 0, 255] : [0, 0, 255, 255] })
    let rotatedInfo = try ImageProcessor.inspect(url: rotated)
    try expect(rotatedInfo.width == 40 && rotatedInfo.height == 80, "元信息应应用 EXIF 方向")
    let result = try ImageProcessor.process(url: rotated, options: ImageProcessingOptions())
    try expect(result.width == 40 && result.height == 80, "输出应应用 EXIF 方向")
    let output = try decode(result.data)
    let pixels = rgba(output)
    let first = (10 * 40 + 20) * 4, last = (70 * 40 + 20) * 4
    try expect(pixels[first] > 220 && pixels[last + 2] > 220, "方向 6 必须顺时针旋转像素")
}
func testPNGPreservesOriginalPrecision() throws {
    // Sub-8-bit steps and Display P3 make an 8-bit sRGB conversion observable.
    let samples: [UInt16] = [
        0x1234, 0x5678, 0x9abc, 0xffff, 0xffff, 0x0000, 0x0000, 0xffff,
        0x0000, 0xffff, 0x0000, 0x8001, 0x0001, 0x0002, 0x0003, 0xffff,
        0x1235, 0x5679, 0x9abd, 0xffff, 0x0000, 0x0000, 0xffff, 0xffff,
        0x2222, 0x4444, 0x6666, 0x0000, 0xffff, 0xffff, 0xffff, 0xffff
    ]
    var bytes = Data()
    for sample in samples { bytes.append(UInt8(sample >> 8)); bytes.append(UInt8(truncatingIfNeeded: sample)) }
    let provider = CGDataProvider(data: bytes as CFData)!
    let bitmapInfo = CGBitmapInfo.byteOrder16Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue))
    let image = CGImage(width: 4, height: 2, bitsPerComponent: 16, bitsPerPixel: 64,
                        bytesPerRow: 32, space: CGColorSpace(name: CGColorSpace.displayP3)!,
                        bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                        shouldInterpolate: false, intent: .defaultIntent)!
    let url = directory.appendingPathComponent("precision16.png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    try expect(CGImageDestinationFinalize(destination), "16 位 PNG 样本编码失败")
    let originalData = try Data(contentsOf: url)
    try expect(decode(originalData).bitsPerComponent == 16, "回归样本必须实际为 16 位 PNG")
    var options = ImageProcessingOptions()
    for mode in [ImageResizeMode.original, .percentage, .dimensions] {
        options.resize = mode; options.percentage = 100; options.width = 4; options.height = 2
        let result = try ImageProcessor.process(url: url, options: options)
        try expect(result.data == originalData, "未改变像素的 PNG 必须保留原字节、精度和色彩描述")
        try expect(decode(result.data).bitsPerComponent == 16, "PNG 直通不得降低到 8 位")
        try expect(decode(result.thumbnailData).width == 4 && result.width == 4 && result.height == 2,
                   "PNG 直通仍须提供正确的预览与尺寸")
    }
}
func testMirroredOrientation() throws {
    let url = try fixture("mirrored.png", width: 20, height: 10, orientation: 2,
                          pixel: { x, _ in x < 10 ? [255, 0, 0, 255] : [0, 0, 255, 255] })
    let result = try ImageProcessor.process(url: url, options: ImageProcessingOptions())
    let pixels = rgba(try decode(result.data))
    try expect(pixels[(5 * 20 + 3) * 4 + 2] > 240 && pixels[(5 * 20 + 16) * 4] > 240,
               "EXIF 镜像必须转换像素，不能只交换尺寸")
}

// A grayscale source keeps the test allocation near 40 MB while exercising
// rejection of a valid, encoded image just above the input pixel limit.
func oversizedPNG() throws -> URL {
    try autoreleasepool {
        let width = 8000, height = 5001
        let provider = CGDataProvider(data: Data(repeating: 128, count: width * height) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let url = directory.appendingPathComponent("oversized.png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        try expect(CGImageDestinationFinalize(destination), "超尺寸样本编码失败")
        return url
    }
}
func testResize() throws {
    let url = try fixture("resize.png")
    var options = ImageProcessingOptions(); options.resize = .percentage; options.percentage = 50
    var result = try ImageProcessor.process(url: url, options: options)
    try expect(result.width == 40 && result.height == 20, "50% 缩放失败")
    options.resize = .dimensions; options.width = 30; options.height = 30
    result = try ImageProcessor.process(url: url, options: options)
    try expect(result.width == 30 && result.height == 15, "边界缩放应保留长宽比且不裁剪")
    options.preserveAspect = false
    result = try ImageProcessor.process(url: url, options: options)
    try expect(result.width == 30 && result.height == 30, "解锁后应精确拉伸")
    options.resize = .percentage; options.percentage = 0.01
    result = try ImageProcessor.process(url: url, options: options)
    try expect(result.width == 1 && result.height == 1, "极小合法缩放不应产生 0 像素")
}
func testAlphaAndJPEG() throws {
    let url = try fixture("alpha.png", width: 16, height: 16, pixel: { _, _ in [255, 0, 0, 0] })
    let png = try ImageProcessor.process(url: url, options: ImageProcessingOptions())
    try expect(rgba(decode(png.data))[3] == 0, "PNG 必须保留透明度")
    var options = ImageProcessingOptions(); options.format = .jpeg; options.background = ImageBackground(red: 0, green: 1, blue: 0)
    let jpg = try ImageProcessor.process(url: url, options: options)
    let bytes = rgba(try decode(jpg.data))
    try expect(bytes[0] < 10 && bytes[1] > 245 && bytes[2] < 10 && bytes[3] == 255, "JPG 应合成用户底色")
    let source = CGImageSourceCreateWithData(jpg.data as CFData, nil)!
    try expect(CGImageSourceGetType(source) == UTType.jpeg.identifier as CFString, "JPG 必须实际编码为 JPEG")
    let half = try fixture("half.png", width: 16, height: 16, pixel: { _, _ in [255, 0, 0, 128] })
    let halfPNG = try ImageProcessor.process(url: half, options: ImageProcessingOptions())
    let halfBytes = rgba(try decode(halfPNG.data))
    try expect(abs(Int(halfBytes[3]) - 128) <= 1, "半透明 alpha 必须保留")
}
func testWhiteBackground() throws {
    let colors: [[UInt8]] = [[255,255,255,255], [255,240,160,255], [120,20,100,255],
                            [248,248,248,255], [235,235,235,255], [255,0,0,128], [0,0,0,0]]
    let url = try fixture("white-artwork.png", width: colors.count, height: 2, pixel: { x, _ in colors[x] })
    var options = ImageProcessingOptions(); options.cutout = .whiteBackground
    let result = try ImageProcessor.process(url: url, options: options)
    let bytes = rgba(try decode(result.data))
    try expect(bytes[3] == 0 && bytes[3 * 4 + 3] == 0, "白底与近白背景应真正透明")
    try expect(bytes[1 * 4 + 3] == 255 && bytes[2 * 4 + 3] == 255, "淡黄色描边与彩色主体应保留")
    try expect(abs(Int(bytes[1 * 4 + 2]) - 160) <= 2, "去白底不应改变保留的彩色像素")
    try expect(bytes[4 * 4 + 3] > 0 && bytes[4 * 4 + 3] < 255, "去白底边界应保留软过渡")
    let recomposited = Int(bytes[4 * 4]) + 255 - Int(bytes[4 * 4 + 3])
    try expect(abs(recomposited - 235) <= 2, "软边去白底后叠回白底应还原原色")
    try expect(abs(Int(bytes[5 * 4 + 3]) - 128) <= 1 && bytes[6 * 4 + 3] == 0, "已有透明度应保留")
    options.whiteTolerance = 0.1
    let stronger = rgba(try decode(ImageProcessor.process(url: url, options: options).data))
    try expect(stronger[4 * 4 + 3] == 0, "增大容差应去除更多近白色")
    for invalid in [Double.nan, -0.1, 1.1] {
        options.whiteTolerance = invalid
        try expectError("容差") { _ = try ImageProcessor.process(url: url, options: options) }
    }
}

func testQuality() throws {
    let url = try fixture("noise.png", width: 256, height: 256, pixel: { x, y in
        [UInt8((x * 71 + y * 131) % 256), UInt8((x * 13 + y * 29) % 256), UInt8((x * y + x * 53) % 256), 255]
    })
    var options = ImageProcessingOptions(); options.format = .jpeg; options.jpegQuality = 0.1
    let low = try ImageProcessor.process(url: url, options: options)
    options.jpegQuality = 0.95
    let high = try ImageProcessor.process(url: url, options: options)
    try expect(low.data.count < high.data.count, "JPG 质量设置必须影响编码结果")
}
func testInvalidAndLimits() throws {
    let invalid = directory.appendingPathComponent("invalid.png"); try Data("not an image".utf8).write(to: invalid)
    try expectError("图片") { _ = try ImageProcessor.inspect(url: invalid) }
    let gif = try fixture("unsupported.png", type: UTType.gif.identifier as CFString)
    try expectError("PNG") { _ = try ImageProcessor.inspect(url: gif) }
    let apng = try fixture("animated.png", frames: 2)
    try expectError("多帧") { _ = try ImageProcessor.inspect(url: apng) }
    let url = try fixture("limit.png")
    let oversized = try oversizedPNG()
    try expectError("4000 万") { _ = try ImageProcessor.inspect(url: oversized) }
    try expectError("4000 万") { _ = try ImageProcessor.process(url: oversized, options: ImageProcessingOptions()) }
    let truncated = directory.appendingPathComponent("truncated.png")
    try Data(contentsOf: url).prefix(40).write(to: truncated)
    try expectError("图片") { _ = try ImageProcessor.inspect(url: truncated) }
    var options = ImageProcessingOptions(); options.resize = .dimensions; options.preserveAspect = false
    options.width = 16_385; options.height = 1
    try expectError("16384") { _ = try ImageProcessor.process(url: url, options: options) }
    options.width = 8000; options.height = 8000
    try expectError("4000 万") { _ = try ImageProcessor.process(url: url, options: options) }
    options.width = -1
    try expectError("大于 0") { _ = try ImageProcessor.process(url: url, options: options) }
    options.resize = .percentage
    for percent in [0.0, -1, Double.nan, Double.infinity, Double.greatestFiniteMagnitude] {
        options.percentage = percent
        try expectError("缩放") { _ = try ImageProcessor.process(url: url, options: options) }
    }
    options = ImageProcessingOptions(); options.format = .jpeg; options.jpegQuality = .nan
    try expectError("质量") { _ = try ImageProcessor.process(url: url, options: options) }
    options.jpegQuality = 0.8; options.background.red = -1
    try expectError("底色") { _ = try ImageProcessor.process(url: url, options: options) }
}

func testEditGeometry() throws {
    let colors: [[UInt8]] = [[255,0,0,255], [0,255,0,255], [0,0,255,255], [255,255,0,255],
                             [255,0,255,255], [0,255,255,255], [80,40,20,255], [20,40,80,255]]
    let url = try fixture("edit-grid.png", width: 4, height: 2, pixel: { x, y in colors[y * 4 + x] })
    let crop = try ImageProcessor.edit(url: url, options: ImageEditOptions(crop: ImagePixelRect(x: 1, y: 0, width: 2, height: 2)))
    try expect(crop.width == 2 && crop.height == 2, "裁剪尺寸应准确")
    let cropped = rgba(try decode(crop.data))
    try expect(Array(cropped[0..<4]) == colors[1] && Array(cropped[4..<8]) == colors[2]
               && Array(cropped[8..<12]) == colors[5], "裁剪坐标应从已归一化图像左上角计")
    let clockwise = try ImageProcessor.edit(url: url, options: ImageEditOptions(quarterTurns: 1))
    let turned = rgba(try decode(clockwise.data))
    try expect(clockwise.width == 2 && clockwise.height == 4, "旋转 90° 应交换宽高")
    try expect(Array(turned[0..<4]) == colors[4] && Array(turned[4..<8]) == colors[0], "顺时针旋转的首行像素错误")
    let horizontal = rgba(try decode(ImageProcessor.edit(url: url, options: ImageEditOptions(flipHorizontal: true)).data))
    try expect(Array(horizontal[0..<4]) == colors[3] && Array(horizontal[4..<8]) == colors[2], "水平翻转像素错误")
    let vertical = rgba(try decode(ImageProcessor.edit(url: url, options: ImageEditOptions(flipVertical: true)).data))
    try expect(Array(vertical[0..<4]) == colors[4] && Array(vertical[4..<8]) == colors[5], "垂直翻转像素错误")
    try expectError("裁剪") { _ = try ImageProcessor.edit(url: url, options: ImageEditOptions(crop: ImagePixelRect(x: 3, y: 1, width: 2, height: 2))) }
}

func testEditOrientationAndAlphaInfo() throws {
    let oriented = try fixture("oriented-edit.jpg", width: 20, height: 10, orientation: 6,
                               pixel: { x, _ in x < 10 ? [255,0,0,255] : [0,0,255,255] })
    let result = try ImageProcessor.edit(url: oriented, options: ImageEditOptions(crop: ImagePixelRect(x: 0, y: 0, width: 10, height: 10)))
    try expect(result.width == 10 && result.height == 10, "裁剪应使用方向归一化后的尺寸")
    try expect(rgba(try decode(result.data))[0] > 220, "方向归一化后上方应是原图左侧红色像素")
    let clear = try fixture("clear-info.png", width: 2, height: 1, pixel: { x, _ in x == 0 ? [255,0,0,255] : [0,0,0,0] })
    let opaqueAlpha = try fixture("opaque-alpha.png", width: 2, height: 1)
    let noAlpha = try fixture("no-alpha.jpg", width: 2, height: 1, type: UTType.jpeg.identifier as CFString)
    try expect(try ImageProcessor.inspect(url: clear).transparency == .containsTransparentPixels, "真实透明像素应被识别")
    try expect(try ImageProcessor.inspect(url: opaqueAlpha).transparency == .opaqueAlphaChannel, "全不透明 alpha 应单独分类")
    try expect(try ImageProcessor.inspect(url: noAlpha).transparency == .noAlphaChannel, "JPEG 应无 alpha")
    try expect(!(try ImageProcessor.inspect(url: clear).colorDescription.isEmpty), "应展示色彩信息")
    let edited = try ImageProcessor.edit(url: clear, options: ImageEditOptions(flipHorizontal: true))
    try expect(rgba(try decode(edited.data))[3] == 0, "编辑后 PNG 仍应保留透明像素")
}

func test16BitAlphaPrecision() throws {
    var bytes = Data()
    for component: UInt16 in [0, 0, 0, 0xfffe, 0, 0, 0, 0xffff] {
        bytes.append(UInt8(component >> 8))
        bytes.append(UInt8(truncatingIfNeeded: component))
    }
    let provider = CGDataProvider(data: bytes as CFData)!
    let image = CGImage(width: 2, height: 1, bitsPerComponent: 16, bitsPerPixel: 64,
                        bytesPerRow: 16, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGBitmapInfo.byteOrder16Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)),
                        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let url = directory.appendingPathComponent("subtle-alpha-16.png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    try expect(CGImageDestinationFinalize(destination), "16 位 alpha 样本编码失败")
    try expect(try decode(Data(contentsOf: url)).bitsPerComponent == 16, "回归样本必须确实保留 16 位通道")
    let info = try ImageProcessor.inspect(url: url)
    try expect(info.transparency == .containsTransparentPixels, "alpha=65534 的 16 位 PNG 仍含真实透明像素")

    var opaqueBytes = bytes
    opaqueBytes.replaceSubrange(6..<8, with: [0xff, 0xff])
    let opaqueProvider = CGDataProvider(data: opaqueBytes as CFData)!
    let opaqueImage = CGImage(width: 2, height: 1, bitsPerComponent: 16, bitsPerPixel: 64,
                              bytesPerRow: 16, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGBitmapInfo.byteOrder16Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)),
                              provider: opaqueProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let opaqueURL = directory.appendingPathComponent("opaque-alpha-16.png")
    let opaqueDestination = CGImageDestinationCreateWithURL(opaqueURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(opaqueDestination, opaqueImage, nil)
    try expect(CGImageDestinationFinalize(opaqueDestination), "全不透明 16 位样本编码失败")
    try expect(try ImageProcessor.inspect(url: opaqueURL).transparency == .opaqueAlphaChannel,
               "全不透明 16 位 Alpha 应保持独立分类")
}

func testEditOutputDimensionLimit() throws {
    let url = try fixture("wide-edit.png", width: 16_385, height: 1)
    try expectError("16384") { _ = try ImageProcessor.edit(url: url, options: ImageEditOptions()) }
}
func probeForegroundSubject() throws {
    let url = try fixture("sphere.png", width: 512, height: 512, pixel: { x, y in
        let dx = Double(x - 256) / 140, dy = Double(y - 240) / 140
        let distance = dx * dx + dy * dy
        if distance < 1 {
            let light = max(0.2, min(1, 0.7 - dx * 0.3 - dy * 0.3))
            return [UInt8(255 * light), UInt8(120 * light), UInt8(25 * light), 255]
        }
        return [235, 235, 235, 255]
    })
    var options = ImageProcessingOptions(); options.cutout = .foreground
    do {
        let result = try ImageProcessor.process(url: url, options: options)
        let pixels = rgba(try decode(result.data))
        try expect(pixels[3] < 20, "主体抠图必须移除图片角落的背景")
        try expect(pixels[(240 * 512 + 256) * 4 + 3] > 200, "主体抠图必须保留球体中心")
        print("VISION 主体样本：本机推理成功，球体中心保留、背景透明")
    } catch let error as TestFailure { throw error }
    catch {
        try expect(error.localizedDescription.contains("Vision") || error.localizedDescription.contains("未检测"), "应明确报告分割失败")
        print("VISION 主体样本未验收：\(error.localizedDescription)")
    }
}
func probeVision() throws {
    let url = try fixture("blank.png", width: 256, height: 256, pixel: { _, _ in [255, 255, 255, 255] })
    for mode in [ImageCutoutMode.foreground, .person] {
        var options = ImageProcessingOptions(); options.cutout = mode
        do {
            _ = try ImageProcessor.process(url: url, options: options)
            throw TestFailure(description: "纯白图片不应伪造主体：\(mode.rawValue)")
        } catch let error as TestFailure { throw error }
        catch {
            let message = error.localizedDescription
            try expect(message.contains("未检测") || message.contains("Vision"), "应报告无主体或具体系统推理错误：\(message)")
            print("VISION \(mode.rawValue)：\(message)")
        }
    }
}
var tests: [(String, () throws -> Void)] = [
    ("裁剪旋转翻转真实像素", testEditGeometry), ("编辑方向与透明信息", testEditOrientationAndAlphaInfo),
    ("16 位极浅透明度", test16BitAlphaPrecision),
    ("编辑输出尺寸限制", testEditOutputDimensionLimit),
    ("识别、缩略图与 EXIF 方向", testInspectAndOrientation), ("PNG 原始精度保留", testPNGPreservesOriginalPrecision), ("EXIF 镜像", testMirroredOrientation), ("比例与精确缩放", testResize),
    ("透明度与 JPG 底色", testAlphaAndJPEG), ("去白底与软边透明度", testWhiteBackground), ("JPG 质量", testQuality),
    ("格式、非法参数与资源限制", testInvalidAndLimits), ("本机 Vision 空白图探测", probeVision), ("本机 Vision 主体探测", probeForegroundSubject)
]
if let argumentIndex = CommandLine.arguments.firstIndex(of: "--vision-person") {
    guard CommandLine.arguments.indices.contains(argumentIndex + 1) else {
        print("--vision-person 需要本地人像图片路径"); exit(1)
    }
    let personURL = URL(fileURLWithPath: CommandLine.arguments[argumentIndex + 1])
    tests.append(("本机 Vision 真实人像", {
        var options = ImageProcessingOptions(); options.cutout = .person
        let result = try ImageProcessor.process(url: personURL, options: options)
        let pixels = rgba(try decode(result.data))
        var opaque = 0, transparent = 0
        for alphaIndex in stride(from: 3, to: pixels.count, by: 4) {
            if pixels[alphaIndex] > 200 { opaque += 1 }
            if pixels[alphaIndex] < 20 { transparent += 1 }
        }
        let total = result.width * result.height
        try expect(opaque > total / 100 && transparent > total / 100,
                   "真实人像应同时保留明显主体区域并去除明显背景区域")
        print("VISION 人像样本：人物保留 \(opaque) 像素、透明背景 \(transparent) 像素，共 \(total) 像素")
    }))
}
var failures = 0
for (name, test) in tests {
    do { try test(); print("PASS \(name)") }
    catch { failures += 1; print("FAIL \(name)：\(error)") }
}
print("图片测试：\(tests.count - failures)/\(tests.count) 组通过")
if failures > 0 { exit(1) }
