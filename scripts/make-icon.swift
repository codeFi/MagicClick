// Draws the app icon and writes Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = size * 0.1
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.36, green: 0.42, blue: 1.0, alpha: 1), NSColor(red: 0.62, green: 0.33, blue: 0.96, alpha: 1)])!
        .draw(in: path, angle: -45)
    let config = NSImage.SymbolConfiguration(pointSize: rect.width * 0.5, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        symbol.draw(in: NSRect(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2,
                               width: symbolSize.width, height: symbolSize.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try! render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try! render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
