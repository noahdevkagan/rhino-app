import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "app/icon.png")
let pixels = 512

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmap.size = NSSize(width: pixels, height: pixels)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
NSColor.clear.setFill()
canvas.fill()

let tile = canvas.insetBy(dx: 20, dy: 20)
let shape = NSBezierPath(roundedRect: tile, xRadius: 116, yRadius: 116)
NSColor(calibratedRed: 0.98, green: 0.39, blue: 0.32, alpha: 1).setFill()
shape.fill()

let glyph = "🦏" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Apple Color Emoji", size: 330)
        ?? NSFont.systemFont(ofSize: 330)
]
let glyphSize = glyph.size(withAttributes: attributes)
glyph.draw(
    at: NSPoint(
        x: (CGFloat(pixels) - glyphSize.width) / 2,
        y: (CGFloat(pixels) - glyphSize.height) / 2 - 2
    ),
    withAttributes: attributes
)

NSGraphicsContext.restoreGraphicsState()

try FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
