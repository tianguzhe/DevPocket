import Foundation
import ImageIO
import Vision

@main
struct QRCodeEngineTests {
    static func image(_ code: QRCodeImage) -> CGImage {
        let source = CGImageSourceCreateWithData(code.pngData as CFData, nil)!
        precondition(CGImageSourceGetType(source) as String? == "public.png")
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        precondition(image.width == code.pixelSize && image.height == code.pixelSize)
        return image
    }

    static func verifyPixels(_ image: CGImage) {
        let size = image.width
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: size, height: size, bitsPerComponent: 8,
                                    bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        for y in 0..<size {
            for x in 0..<size {
                let i = (y * size + x) * 4
                precondition(pixels[i + 3] == 255)
                precondition(pixels[i] == pixels[i + 1] && pixels[i] == pixels[i + 2])
                precondition(pixels[i] == 0 || pixels[i] == 255, "QR modules must have sharp edges")
                if x < 4 || y < 4 || x >= size - 4 || y >= size - 4 {
                    precondition(pixels[i] == 255, "QR image needs a white quiet zone")
                }
            }
        }
    }

    static func verifyScan(_ image: CGImage, text: String) throws {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image).perform([request])
        precondition(request.results?.count == 1)
        precondition(request.results?.first?.payloadStringValue == text, "Scanned QR text differs from input")
    }

    static func main() throws {
        let url = "https://example.com/中文?text=你好👋&q=a+b%20c#片段"
        for correction in QRCodeCorrection.allCases {
            for size in QRCodeSize.allCases {
                let result = try ToolEngine.run(ToolRequest(mode: .qrGenerate, input: url,
                                                           qrCode: QRCodeOptions(size: size, correction: correction)))
                guard case .qrCode(let code) = result else { fatalError("Expected image output") }
                let bitmap = image(code)
                verifyPixels(bitmap)
                try verifyScan(bitmap, text: url)
            }
        }
        for text in ["  exact text + % &\nsecond line  ", #"{"name":"二维码","emoji":"👨‍💻"}"#] {
            try verifyScan(image(QRCodeEngine.generate(text)), text: text)
        }
        // Byte-mode capacity fixtures from QR version 40, independent of options.
        for (correction, capacity) in [(QRCodeCorrection.low, 2953), (.medium, 2331), (.quartile, 1663), (.high, 1273)] {
            let code = try QRCodeEngine.generate(String(repeating: "a", count: capacity),
                                                 options: QRCodeOptions(size: .large, correction: correction))
            verifyPixels(image(code))
            do {
                _ = try QRCodeEngine.generate(String(repeating: "a", count: capacity + 1),
                                               options: QRCodeOptions(correction: correction))
                fatalError("Expected capacity rejection")
            } catch let error as ToolFailure { precondition(error.message.contains("容量")) }
        }
        do {
            _ = try QRCodeEngine.generate("")
            fatalError("Expected empty input rejection")
        } catch let error as ToolFailure { precondition(error.message.contains("请输入")) }
        print("PASS: QR scanning of Unicode/emoji URLs and exact text, every size/correction level, PNG dimensions, sharp pixels, white quiet zones and input limits")
    }
}
