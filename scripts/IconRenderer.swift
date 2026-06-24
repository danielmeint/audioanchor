import AppKit

// Renders a 1024×1024 macOS-style app icon: a rounded-rect with a blue→indigo
// gradient and a white `waveform` glyph. Usage: swift IconRenderer.swift <out.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let px = 1024

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    let rect = NSRect(origin: .zero, size: image.size)
    image.draw(in: rect)
    color.set()
    rect.fill(using: .sourceAtop)
    out.unlockFocus()
    out.isTemplate = false
    return out
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("could not create bitmap context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

let canvas = CGFloat(px)
let inset: CGFloat = 100
let plate = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
let path = NSBezierPath(roundedRect: plate, xRadius: 184, yRadius: 184)

let start = NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 1) // sky blue
let end = NSColor(srgbRed: 0.31, green: 0.27, blue: 0.90, alpha: 1)   // indigo
NSGradient(starting: start, ending: end)?.draw(in: path, angle: -60)

let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let glyph = tinted(symbol, .white)
    let targetHeight: CGFloat = 360
    let scale = targetHeight / glyph.size.height
    let w = glyph.size.width * scale
    let h = glyph.size.height * scale
    glyph.draw(in: NSRect(x: (canvas - w) / 2, y: (canvas - h) / 2, width: w, height: h))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(px)x\(px))")
