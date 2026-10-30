// Puts a settings window picture from `MagicClick --snapshot` on a soft background, with rounded corners,
// a shadow and window buttons, for the README.
// Run: swift scripts/make-screenshot.swift <window.png> <out.png> [height in points, to cut the bottom]
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3, var window = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: arguments[1])))?.cgImage else {
    print("usage: swift scripts/make-screenshot.swift <window.png> <out.png> [height]")
    exit(1)
}
let scale: CGFloat = 2
if arguments.count > 3, let height = Double(arguments[3]), Int(height * scale) < window.height {
    window = window.cropping(to: CGRect(x: 0, y: 0, width: window.width, height: Int(height * scale)))!
}
let margin: CGFloat = 56
let size = CGSize(width: CGFloat(window.width) / scale, height: CGFloat(window.height) / scale)
let canvas = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = canvas
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext

// Background: the app icon colors, from blue at the top left to purple at the bottom right.
let colors = [NSColor(red: 0.43, green: 0.52, blue: 1.0, alpha: 1).cgColor, NSColor(red: 0.66, green: 0.42, blue: 0.96, alpha: 1).cgColor]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: canvas.width, y: 0), options: [])

let frame = CGRect(x: margin, y: margin, width: size.width, height: size.height)
let shape = CGPath(roundedRect: frame, cornerWidth: 16, cornerHeight: 16, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 48, color: NSColor.black.withAlphaComponent(0.45).cgColor)
context.addPath(shape)
context.setFillColor(NSColor(white: 0.16, alpha: 1).cgColor)
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(shape)
context.clip()
context.draw(window, in: frame)
context.restoreGState()
context.addPath(shape)
context.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
context.setLineWidth(1)
context.strokePath()

// The red, yellow and green window buttons.
for (index, color) in [NSColor(red: 1, green: 0.37, blue: 0.34, alpha: 1), NSColor(red: 1, green: 0.74, blue: 0.18, alpha: 1),
                       NSColor(red: 0.16, green: 0.79, blue: 0.25, alpha: 1)].enumerated() {
    let center = CGPoint(x: frame.minX + 20 + CGFloat(index) * 20, y: frame.maxY - 18)
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12))
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arguments[2]))
print("Wrote \(arguments[2]) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
