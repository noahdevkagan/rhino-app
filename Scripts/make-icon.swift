// Generates the Rhino icons:
//   build/AppIcon.iconset/*        — app icon: crisp illustrated rhino on coral
//   build/tray_icon_18.png / 36    — menu bar template: rhino silhouette (from emoji alpha)
//   build/icon-preview.png         — 256px preview for eyeballing
// Driven by: swift Scripts/make-icon.swift && iconutil -c icns build/AppIcon.iconset -o OpenSuperWhisper/AppIcon.icns
import AppKit

let outDir = URL(fileURLWithPath: "build/AppIcon.iconset")
let appIconSourceURL = URL(fileURLWithPath: "Scripts/Assets/rhino-app-icon.png")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let appIconSource = NSImage(contentsOf: appIconSourceURL) else {
    fatalError("Missing app icon source at \(appIconSourceURL.path)")
}

func bitmap(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    return rep
}

func draw(into rep: NSBitmapImageRep, _ body: (CGFloat) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    body(CGFloat(rep.pixelsWide))
    NSGraphicsContext.restoreGraphicsState()
}

func writePNG(_ rep: NSBitmapImageRep, _ name: String, dir: URL = outDir) {
    try! rep.representation(using: .png, properties: [:])!
        .write(to: dir.appendingPathComponent(name))
}

// MARK: - App icon: crisp illustrated rhino on coral

func renderAppIcon(_ px: Int) -> NSBitmapImageRep {
    let rep = bitmap(px)
    draw(into: rep) { s in
        let inset = s * 0.049
        let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let squircle = NSBezierPath(
            roundedRect: rect,
            xRadius: rect.width * 0.2237,
            yRadius: rect.width * 0.2237
        )
        squircle.addClip()

        NSGraphicsContext.current?.imageInterpolation = .high
        appIconSource.draw(
            in: rect,
            from: NSRect(origin: .zero, size: appIconSource.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
    return rep
}

for base in [16, 32, 128, 256, 512] {
    writePNG(renderAppIcon(base), "icon_\(base)x\(base).png")
    writePNG(renderAppIcon(base * 2), "icon_\(base)x\(base)@2x.png")
}
writePNG(renderAppIcon(256), "icon-preview.png", dir: URL(fileURLWithPath: "build"))

// MARK: - Menu bar template: rhino silhouette from the emoji's alpha channel

func renderTray(_ px: Int) -> NSBitmapImageRep {
    // Render the emoji, then keep only its alpha as black — a clean silhouette
    // that macOS tints as a template image (menu bar, dark & light).
    let src = bitmap(px * 4)  // supersample for a smooth edge at 18px
    draw(into: src) { s in
        let glyph = "🦏" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Apple Color Emoji", size: s * 0.98)
                ?? NSFont.systemFont(ofSize: s * 0.98)
        ]
        let gsize = glyph.size(withAttributes: attrs)
        glyph.draw(at: NSPoint(x: (s - gsize.width) / 2, y: (s - gsize.height) / 2),
                   withAttributes: attrs)
    }
    let out = bitmap(px)
    draw(into: out) { s in
        guard let cg = src.cgImage else { return }
        let ctx = NSGraphicsContext.current!.cgContext
        // clip(to:mask:) uses the image's alpha as the mask; fill = silhouette.
        ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: s), mask: cg)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    }
    return out
}

writePNG(renderTray(18), "tray_icon_18.png", dir: URL(fileURLWithPath: "build"))
writePNG(renderTray(36), "tray_icon_36.png", dir: URL(fileURLWithPath: "build"))
print("iconset + tray + preview written under build/")
