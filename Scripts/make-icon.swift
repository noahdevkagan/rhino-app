// Generates AppIcon.icns: white-first squircle with the rhino mark.
// Rerun after design changes:  swift Scripts/make-icon.swift && iconutil ...
// (see Scripts/make-icon.sh, which drives both steps)
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> NSBitmapImageRep {
    let s = CGFloat(px)
    // Draw into an exact-pixel bitmap: NSImage.lockFocus on a retina display
    // renders at 2x backing scale and every size comes out doubled.
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Big Sur-style squircle, drawn slightly inset like system icons.
    let inset = s * 0.049
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = rect.width * 0.2237
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Soft near-white vertical gradient + hairline border: quiet, not flat.
    let top = NSColor(calibratedWhite: 1.0, alpha: 1)
    let bottom = NSColor(calibratedRed: 0.945, green: 0.945, blue: 0.955, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: squircle, angle: -90)
    NSColor(calibratedWhite: 0.82, alpha: 1).setStroke()
    squircle.lineWidth = max(1, s / 512)
    squircle.stroke()

    // The rhino, front and center.
    let glyph = "🦏" as NSString
    let fontSize = s * 0.58
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Apple Color Emoji", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
    ]
    let gsize = glyph.size(withAttributes: attrs)
    glyph.draw(at: NSPoint(x: (s - gsize.width) / 2, y: (s - gsize.height) / 2 + s * 0.01),
               withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, px: Int, name: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    try! png.write(to: outDir.appendingPathComponent(name))
}

for base in [16, 32, 128, 256, 512] {
    write(render(base), px: base, name: "icon_\(base)x\(base).png")
    write(render(base * 2), px: base * 2, name: "icon_\(base)x\(base)@2x.png")
}
print("iconset written to \(outDir.path)")
