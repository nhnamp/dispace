// make_icon.swift
// Draws the Dispace logo: a display that shows three desktops (Spaces), the middle one active.
// Usage: swift make_icon.swift <output.iconset folder>

import AppKit

let outputFolder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws on a 1024 × 1024 canvas (origin at the bottom left).
func drawLogo() {
    // Body: the macOS icon grid uses an 824-point rounded square with a 100-point margin.
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 186, yRadius: 186)
    NSGradient(colors: [color(0x4F7BFF), color(0x6A4CF5), color(0x8B3FE0)])!.draw(in: body, angle: -60)

    // Soft light from the top.
    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!
        .draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Display: frame, stand, and base.
    let shadow = NSShadow()
    shadow.shadowColor = color(0x1B1060, 0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 36
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    color(0xFFFFFF).setFill()
    NSBezierPath(roundedRect: NSRect(x: 214, y: 352, width: 596, height: 400), xRadius: 44, yRadius: 44).fill()
    NSBezierPath(roundedRect: NSRect(x: 462, y: 288, width: 100, height: 80), xRadius: 10, yRadius: 10).fill()
    NSBezierPath(roundedRect: NSRect(x: 372, y: 262, width: 280, height: 40), xRadius: 20, yRadius: 20).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Screen.
    let screen = NSBezierPath(roundedRect: NSRect(x: 246, y: 384, width: 532, height: 336), xRadius: 22, yRadius: 22)
    NSGradient(colors: [color(0x1E2A5A), color(0x2B1F66)])!.draw(in: screen, angle: -90)

    // Three desktops in a row, like the Spaces bar of Mission Control.
    // Blue for work, white for the active desktop, coral for entertainment.
    let tiles: [(x: CGFloat, fill: NSColor)] = [(282, color(0x5EC8FF)), (442, color(0xFFFFFF)), (602, color(0xFF8A65))]
    for tile in tiles {
        let rect = NSRect(x: tile.x, y: 494, width: 140, height: 108)
        tile.fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()
    }
    // Marker under the active (middle) desktop.
    color(0xFFFFFF).setFill()
    NSBezierPath(roundedRect: NSRect(x: 482, y: 446, width: 60, height: 14), xRadius: 7, yRadius: 7).fill()
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for size in sizes {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size.pixels, pixelsHigh: size.pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    let scale = CGFloat(size.pixels) / 1024
    NSAffineTransform(transform: AffineTransform(scaleByX: scale, byY: scale)).concat()
    drawLogo()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: outputFolder.appendingPathComponent(size.name + ".png"))
}
print("Wrote \(sizes.count) images to \(outputFolder.path)")
