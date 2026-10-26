import AppKit

// Finder lays out the installer in points. Store both 1× and 2× artwork in
// the TIFF so the same layout stays sharp on standard and Retina displays.
let canvas = NSSize(width: 720, height: 520)
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let version = CommandLine.arguments[2]
let brand = NSImage(contentsOfFile: CommandLine.arguments[3])!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}
func rect(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvas.height - top - height, width: width, height: height)
}
func point(_ x: CGFloat, _ top: CGFloat) -> NSPoint { NSPoint(x: x, y: canvas.height - top) }
func text(_ value: String, in bounds: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
          color: NSColor, alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byClipping
    (value as NSString).draw(in: bounds, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: paragraph
    ])
}

func artwork() {
    let ink = color(0.10, 0.37, 0.29)
    let secondary = color(0.40, 0.49, 0.44)
    NSGradient(starting: color(0.96, 0.98, 0.96), ending: color(0.90, 0.95, 0.92))!
        .draw(in: NSRect(origin: .zero, size: canvas), angle: -65)

    brand.draw(in: rect(42, 30, 50, 50))
    text("DevPocket", in: rect(104, 29, 350, 37), size: 28, weight: .semibold, color: ink)
    text("开发者的随身工具箱", in: rect(106, 69, 350, 18), size: 11, color: secondary)

    NSColor.white.withAlphaComponent(0.7).setFill()
    NSBezierPath(roundedRect: rect(596, 42, 80, 26), xRadius: 13, yRadius: 13).fill()
    text("v\(version)", in: rect(600, 47, 72, 17), size: 11, weight: .medium, color: ink, alignment: .center)

    text("拖入 Applications，完成安装", in: rect(40, 123, 640, 28),
         size: 20, weight: .semibold, color: ink, alignment: .center)
    text("将左侧应用拖到右侧文件夹", in: rect(40, 157, 640, 20),
         size: 12, color: secondary, alignment: .center)

    let card = NSBezierPath(roundedRect: rect(48, 194, 624, 150), xRadius: 23, yRadius: 23)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0.12, 0.32, 0.23, 0.045)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -5)
    shadow.set()
    NSColor.white.withAlphaComponent(0.8).setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()
    color(0.20, 0.46, 0.33, 0.06).setStroke()
    card.lineWidth = 1
    card.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: point(322, 246))
    arrow.line(to: point(398, 246))
    arrow.move(to: point(386, 234))
    arrow.line(to: point(398, 246))
    arrow.line(to: point(386, 258))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    color(0.27, 0.56, 0.43, 0.7).setStroke()
    arrow.stroke()

    text("安装后，在「应用程序」中打开 DevPocket。", in: rect(40, 363, 640, 20),
         size: 12, color: secondary, alignment: .center)
    let divider = NSBezierPath()
    divider.move(to: point(48, 394))
    divider.line(to: point(672, 394))
    divider.lineWidth = 1
    color(0.21, 0.41, 0.30, 0.10).setStroke()
    divider.stroke()
    text("本地处理 · 随手即用", in: rect(50, 412, 240, 18), size: 10, color: secondary)
    text("macOS 14+  ·  Apple Silicon / Intel", in: rect(360, 412, 310, 18),
         size: 10, color: secondary, alignment: .right)
}

func render(scale: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width) * scale, pixelsHigh: Int(canvas.height) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current!.imageInterpolation = .high
    artwork()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let standard = render(scale: 1)
let retina = render(scale: 2)
try NSBitmapImageRep.representationOfImageReps(in: [standard, retina], using: .tiff,
    properties: [.compressionMethod: NSBitmapImageRep.TIFFCompression.lzw.rawValue])!
    .write(to: output.appendingPathComponent("background.tiff"))
try retina.representation(using: .png, properties: [:])!
    .write(to: output.appendingPathComponent("background@2x.png"))
print("Generated DMG artwork (720 × 520 pt, 1× + 2×)")
