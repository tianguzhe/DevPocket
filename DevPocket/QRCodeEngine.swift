import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum QRCodeCorrection: String, CaseIterable, Identifiable, Sendable {
    case low = "L", medium = "M", quartile = "Q", high = "H"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: return "L · 7%"
        case .medium: return "M · 15%"
        case .quartile: return "Q · 25%"
        case .high: return "H · 30%"
        }
    }
    var maximumBytes: Int {
        switch self {
        case .low: return 2953
        case .medium: return 2331
        case .quartile: return 1663
        case .high: return 1273
        }
    }
}

enum QRCodeSize: Int, CaseIterable, Identifiable, Sendable {
    case small = 256, medium = 512, large = 1024
    var id: Int { rawValue }
    var title: String { "\(rawValue) px" }
}

struct QRCodeOptions: Equatable, Sendable {
    var size: QRCodeSize = .medium
    var correction: QRCodeCorrection = .medium
}

struct QRCodeImage: Sendable {
    let pngData: Data
    let pixelSize: Int
}

enum QRCodeEngine {
    static func generate(_ input: String, options: QRCodeOptions = QRCodeOptions()) throws -> QRCodeImage {
        guard !input.isEmpty else { throw ToolFailure(message: "请输入要生成二维码的文本或网址。") }
        let data = Data(input.utf8)
        guard data.count <= options.correction.maximumBytes else {
            throw ToolFailure(message: "内容超过当前纠错等级的二维码容量（最多 \(options.correction.maximumBytes) 个 UTF-8 字节），请缩短文本或降低纠错等级。")
        }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = options.correction.rawValue
        guard let output = filter.outputImage else {
            throw ToolFailure(message: "内容无法生成二维码，请缩短文本或降低纠错等级。")
        }
        let renderer = CIContext(options: [.useSoftwareRenderer: true])
        let pixels = options.size.rawValue
        guard let code = renderer.createCGImage(output, from: output.extent),
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                      bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw ToolFailure(message: "二维码图片生成失败，请重试。")
        }
        // Keep every module on whole pixels and add at least four white modules
        // on each side so the PNG remains readable on any background.
        let scale = pixels / (code.width + 8)
        let side = code.width * scale
        let offset = (pixels - side) / 2
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.draw(code, in: CGRect(x: offset, y: offset, width: side, height: side))

        let png = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else {
            throw ToolFailure(message: "二维码 PNG 编码失败，请重试。")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ToolFailure(message: "二维码 PNG 编码失败，请重试。")
        }
        return QRCodeImage(pngData: png as Data, pixelSize: pixels)
    }
}
