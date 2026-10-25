import AppKit

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func saved(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    body()
}
func stroke(_ points: [NSPoint], color tint: NSColor, width: CGFloat) {
    guard let first = points.first else { return }
    let path = NSBezierPath()
    path.move(to: first)
    for point in points.dropFirst() { path.line(to: point) }
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    tint.setStroke()
    path.stroke()
}
func artwork() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 78, y: 78, width: 868, height: 868), xRadius: 200, yRadius: 200)
    saved {
        let shadow = NSShadow()
        shadow.shadowColor = color(0.09, 0.29, 0.21, 0.18)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        color(0.85, 0.94, 0.89).setFill()
        tile.fill()
    }
    NSGradient(colors: [color(0.97, 1, 0.96), color(0.86, 0.96, 0.90), color(0.70, 0.87, 0.78)])!
        .draw(in: tile, angle: -65)
    saved {
        tile.addClip()
        let light = NSBezierPath(ovalIn: NSRect(x: -180, y: 530, width: 1100, height: 700))
        NSGradient(starting: color(1, 1, 1, 0.52), ending: color(1, 1, 1, 0))!.draw(in: light, angle: -80)
    }
    saved {
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.translateBy(x: 512, y: 580)
        ctx.rotate(by: -CGFloat.pi / 22)
        ctx.translateBy(x: -512, y: -580)
        let card = NSBezierPath(roundedRect: NSRect(x: 298, y: 414, width: 435, height: 355), xRadius: 54, yRadius: 54)
        let shadow = NSShadow()
        shadow.shadowColor = color(0.06, 0.29, 0.20, 0.14)
        shadow.shadowBlurRadius = 20
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        NSColor.white.setFill()
        card.fill()
        stroke([NSPoint(x: 356, y: 690), NSPoint(x: 485, y: 690)], color: color(0.28, 0.60, 0.46, 0.35), width: 14)
        stroke([NSPoint(x: 356, y: 647), NSPoint(x: 590, y: 647)], color: color(0.28, 0.60, 0.46, 0.18), width: 14)
    }
    let pocket = NSBezierPath()
    pocket.move(to: NSPoint(x: 254, y: 622))
    pocket.curve(to: NSPoint(x: 290, y: 658), controlPoint1: NSPoint(x: 254, y: 645), controlPoint2: NSPoint(x: 268, y: 658))
    pocket.line(to: NSPoint(x: 734, y: 658))
    pocket.curve(to: NSPoint(x: 770, y: 622), controlPoint1: NSPoint(x: 756, y: 658), controlPoint2: NSPoint(x: 770, y: 645))
    pocket.line(to: NSPoint(x: 770, y: 418))
    pocket.curve(to: NSPoint(x: 512, y: 244), controlPoint1: NSPoint(x: 770, y: 297), controlPoint2: NSPoint(x: 622, y: 254))
    pocket.curve(to: NSPoint(x: 254, y: 418), controlPoint1: NSPoint(x: 402, y: 254), controlPoint2: NSPoint(x: 254, y: 297))
    pocket.close()
    saved {
        let shadow = NSShadow()
        shadow.shadowColor = color(0.04, 0.26, 0.17, 0.26)
        shadow.shadowBlurRadius = 26
        shadow.shadowOffset = NSSize(width: 0, height: -18)
        shadow.set()
        color(0.09, 0.39, 0.29).setFill()
        pocket.fill()
    }
    NSGradient(colors: [color(0.21, 0.61, 0.47), color(0.10, 0.47, 0.35), color(0.055, 0.34, 0.26)])!
        .draw(in: pocket, angle: -90)
    saved {
        pocket.addClip()
        stroke([NSPoint(x: 279, y: 634), NSPoint(x: 745, y: 634)], color: color(0.66, 0.93, 0.76, 0.42), width: 5)
    }
    let code = color(0.96, 1, 0.97)
    stroke([NSPoint(x: 428, y: 534), NSPoint(x: 367, y: 478), NSPoint(x: 428, y: 422)], color: code, width: 29)
    stroke([NSPoint(x: 596, y: 534), NSPoint(x: 657, y: 478), NSPoint(x: 596, y: 422)], color: code, width: 29)
    stroke([NSPoint(x: 536, y: 550), NSPoint(x: 488, y: 406)], color: code, width: 25)
    NSColor.white.withAlphaComponent(0.55).setStroke()
    tile.lineWidth = 2
    tile.stroke()
}
func render(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    saved {
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.current!.imageInterpolation = .high
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        artwork()
    }
    return bitmap.representation(using: .png, properties: [:])!
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var entries: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(points * scale).write(to: output.appendingPathComponent(name))
        entries.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
try JSONSerialization.data(withJSONObject: ["images": entries, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
let brand = output.deletingLastPathComponent().appendingPathComponent("BrandIcon.imageset", isDirectory: true)
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)
try render(256).write(to: brand.appendingPathComponent("brand.png"))
try JSONSerialization.data(withJSONObject: ["images": [["filename": "brand.png", "idiom": "universal"]], "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    .write(to: brand.appendingPathComponent("Contents.json"))
print("Generated DevPocket code-pocket icon and sidebar brand asset")
