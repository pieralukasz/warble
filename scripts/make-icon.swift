// Draws the Warble app icon and writes Resources/AppIcon.icns plus a 1024 px PNG.
// Run from the repository root: swift scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024
/// Apple's macOS icon grid leaves a margin around the rounded square.
let inset: CGFloat = 100
let body = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let cornerRadius = body.width * 0.225

func render(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: context)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawIcon(in context: CGContext) {
    let shape = CGPath(roundedRect: body, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Soft drop shadow under the tile.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    context.addPath(shape)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    // Parakeet green to teal.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let colors = [
        NSColor(red: 0.30, green: 0.84, blue: 0.52, alpha: 1).cgColor,
        NSColor(red: 0.10, green: 0.62, blue: 0.56, alpha: 1).cgColor,
        NSColor(red: 0.06, green: 0.40, blue: 0.50, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])

    // Glassy highlight across the top half.
    let highlight = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.white.withAlphaComponent(0.28).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(highlight, start: CGPoint(x: body.midX, y: body.maxY), end: CGPoint(x: body.midX, y: body.midY), options: [])
    context.restoreGState()

    drawWaveform(in: context)
}

func drawWaveform(in context: CGContext) {
    let heights: [CGFloat] = [0.26, 0.52, 0.80, 0.56, 0.92, 0.62, 0.34]
    let barWidth: CGFloat = 58
    let gap: CGFloat = 34
    let maxHeight = body.height * 0.52
    let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    var x = body.midX - total / 2

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.22).cgColor)
    context.setFillColor(NSColor.white.cgColor)
    for fraction in heights {
        let height = maxHeight * fraction
        let bar = CGRect(x: x, y: body.midY - height / 2, width: barWidth, height: height)
        context.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        x += barWidth + gap
    }
    context.fillPath()
    context.restoreGState()
}

func write(_ rep: NSBitmapImageRep, to url: URL) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try write(render(size: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try write(render(size: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try write(render(size: 1024), to: root.appendingPathComponent("Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
