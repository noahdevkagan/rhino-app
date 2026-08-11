// Generates the Rhino icons:
//   build/AppIcon.iconset/*        — app icon: rhino FACE, big, on a coral squircle
//   build/tray_icon_18.png / 36    — menu bar template: rhino silhouette (from emoji alpha)
//   build/icon-preview.png         — 256px preview for eyeballing
// Driven by: swift Scripts/make-icon.swift && iconutil -c icns build/AppIcon.iconset -o OpenSuperWhisper/AppIcon.icns
import AppKit

let outDir = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

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

// MARK: - App icon: face-forward rhino on coral

func renderAppIcon(_ px: Int) -> NSBitmapImageRep {
    let rep = bitmap(px)
    draw(into: rep) { s in
        let inset = s * 0.049
        let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237,
                                    yRadius: rect.width * 0.2237)

        // Warm coral, tiger-icon energy — the gray face pops against it.
        let top = NSColor(calibratedRed: 1.00, green: 0.47, blue: 0.37, alpha: 1)
        let bottom = NSColor(calibratedRed: 0.93, green: 0.26, blue: 0.31, alpha: 1)
        NSGradient(starting: top, ending: bottom)?.draw(in: squircle, angle: -90)

        // Everything after this stays inside the squircle (the zoomed face bleeds).
        squircle.setClip()

        // The rhino faces LEFT in the emoji; its head is the left ~40% of the
        // glyph. Scale way past the tile and shift right/down so just the face
        // fills the frame, Evernote-style.
        let glyph = "🦏" as NSString
        let fontSize = s * 2.15
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Apple Color Emoji", size: fontSize)
                ?? NSFont.systemFont(ofSize: fontSize)
        ]
        let gsize = glyph.size(withAttributes: attrs)
        // Head-center in glyph space ≈ (0.24 * w, 0.62 * h). Land it on tile center.
        let x = s * 0.53 - gsize.width * 0.26
        let y = s * 0.45 - gsize.height * 0.60
        glyph.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
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
