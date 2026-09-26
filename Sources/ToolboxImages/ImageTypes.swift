import Foundation

public enum ImageCutoutMode: String, CaseIterable, Identifiable, Sendable {
    case none = "不抠图", foreground = "自动去背景", person = "人像抠图", whiteBackground = "去白底"
    public var id: String { rawValue }
}

public enum ImageResizeMode: String, CaseIterable, Identifiable, Sendable {
    case original = "原始尺寸", percentage = "百分比", dimensions = "指定宽高"
    public var id: String { rawValue }
}

public enum ImageOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG", jpeg = "JPG"
    public var id: String { rawValue }
    public var fileExtension: String { self == .png ? "png" : "jpg" }
}

public struct ImageBackground: Sendable, Equatable {
    public var red: Double = 1
    public var green: Double = 1
    public var blue: Double = 1
    public init(red: Double = 1, green: Double = 1, blue: Double = 1) {
        self.red = red; self.green = green; self.blue = blue
    }
}

public struct ImageProcessingOptions: Sendable, Equatable {
    public var cutout: ImageCutoutMode = .none
    public var whiteTolerance: Double = 0.05
    public var resize: ImageResizeMode = .original
    public var percentage: Double = 100
    public var width: Int = 1024
    public var height: Int = 768
    public var preserveAspect: Bool = true
    public var format: ImageOutputFormat = .png
    public var jpegQuality: Double = 0.85
    public var background = ImageBackground()
    public init() {}
}

public struct ImageInfo: Sendable {
    public let width: Int
    public let height: Int
    public let fileBytes: Int
    public let format: ImageOutputFormat
    public let thumbnailData: Data
    public let colorDescription: String
    public let transparency: ImageTransparency
    public init(width: Int, height: Int, fileBytes: Int, format: ImageOutputFormat, thumbnailData: Data,
                colorDescription: String = "未知", transparency: ImageTransparency = .noAlphaChannel) {
        self.width = width; self.height = height; self.fileBytes = fileBytes
        self.format = format; self.thumbnailData = thumbnailData
        self.colorDescription = colorDescription; self.transparency = transparency
    }
}

public enum ImageTransparency: String, Sendable {
    case noAlphaChannel = "无 Alpha 通道"
    case opaqueAlphaChannel = "有 Alpha，全部不透明"
    case containsTransparentPixels = "存在透明像素"
}

/// Coordinates are integer pixels from the top left of the orientation-normalized image.
public struct ImagePixelRect: Sendable, Equatable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct ImageEditOptions: Sendable, Equatable {
    public var crop: ImagePixelRect?
    public var quarterTurns: Int
    public var flipHorizontal: Bool
    public var flipVertical: Bool
    public init(crop: ImagePixelRect? = nil, quarterTurns: Int = 0,
                flipHorizontal: Bool = false, flipVertical: Bool = false) {
        self.crop = crop; self.quarterTurns = quarterTurns
        self.flipHorizontal = flipHorizontal; self.flipVertical = flipVertical
    }
}

public struct ProcessedImage: Sendable {
    public let data: Data
    public let thumbnailData: Data
    public let width: Int
    public let height: Int
    public let format: ImageOutputFormat
    public init(data: Data, thumbnailData: Data, width: Int, height: Int, format: ImageOutputFormat) {
        self.data = data; self.thumbnailData = thumbnailData
        self.width = width; self.height = height; self.format = format
    }
}
