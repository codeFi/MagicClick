// Turns the frames from `MagicClick --gesture-frames <dir>` into an animated GIF: the mouse on the left, and on
// the right either a card that says what a click is for, or a San Francisco map rendered with MapKit that zooms
// and rotates the same way as the fingers.
// Run: swift scripts/make-maps-gif.swift <dir> <out.gif>
import AppKit
import ImageIO
import MapKit
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift scripts/make-maps-gif.swift <frames dir> <out.gif>")
    exit(1)
}
let directory = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

let width = 960, height = 600
let captionHeight: CGFloat = 76
let footerHeight: CGFloat = 44
let mapRect = CGRect(x: 312, y: footerHeight + 8, width: 624, height: CGFloat(height) - captionHeight - footerHeight - 16)
let panelRect = CGRect(x: 24, y: footerHeight + 8, width: 264, height: mapRect.height)
// Downtown San Francisco, near the Ferry Building. Zoom 1 shows most of the city.
let center = CLLocationCoordinate2D(latitude: 37.7925, longitude: -122.4010)
let baseDistance = 16_000.0
let background = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)

let lines = try String(contentsOf: directory.appendingPathComponent("frames.txt"), encoding: .utf8)
    .split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }

/// Renders the map for one zoom and heading. Snapshots arrive on the main queue, so this waits on the run loop.
var mapCache: [String: CGImage] = [:]
func map(zoom: Double, heading: Double) -> CGImage? {
    let key = String(format: "%.4f/%.2f", zoom, heading)
    if let cached = mapCache[key] { return cached }
    let options = MKMapSnapshotter.Options()
    options.camera = MKMapCamera(lookingAtCenter: center, fromDistance: baseDistance / zoom, pitch: 0, heading: heading)
    options.size = mapRect.size
    options.appearance = NSAppearance(named: .darkAqua)
    var result: CGImage?
    var done = false
    MKMapSnapshotter(options: options).start { snapshot, error in
        if let error { print("map error: \(error)") }
        result = snapshot?.image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        done = true
    }
    while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    mapCache[key] = result
    return result
}

func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: CGRect) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style,
    ])
    let textHeight = string.size().height
    string.draw(in: CGRect(x: rect.minX, y: rect.midY - textHeight / 2, width: rect.width, height: textHeight + 4))
}

/// The macOS arrow pointer with its tip at `tip`, so it is clear where the zoom happens.
func drawPointer(at tip: CGPoint, in context: CGContext) {
    let points: [CGPoint] = [(0, 0), (0, -21), (5, -16), (9, -25), (12, -24), (8, -15), (15, -15)]
        .map { CGPoint(x: tip.x + $0.0 * 1.2, y: tip.y + $0.1 * 1.2) }
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -2), blur: 4, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    context.addPath(path)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()
    context.addPath(path)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(1.6)
    context.setLineJoin(.round)
    context.strokePath()
}

/// A small compass whose arrow points north, so the rotation is easy to read.
func drawCompass(heading: Double, at point: CGPoint, in context: CGContext) {
    let radius: CGFloat = 20
    context.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
    context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    // Heading h turns the map so that north sits h degrees counterclockwise from up.
    let angle = (90 + heading) * .pi / 180
    // A classic needle: the red half points north, the white half south.
    func needle(_ direction: Double, _ color: NSColor) {
        let tip = CGPoint(x: point.x + cos(direction) * 14, y: point.y + sin(direction) * 14)
        let side = CGPoint(x: point.x + cos(direction + .pi / 2) * 5, y: point.y + sin(direction + .pi / 2) * 5)
        let other = CGPoint(x: point.x - cos(direction + .pi / 2) * 5, y: point.y - sin(direction + .pi / 2) * 5)
        context.setFillColor(color.cgColor)
        context.move(to: tip)
        context.addLine(to: side)
        context.addLine(to: other)
        context.closePath()
        context.fillPath()
    }
    needle(angle, .systemRed)
    needle(angle + .pi, NSColor.white.withAlphaComponent(0.9))
}

let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, lines.count, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)

for line in lines {
    let panel = NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(line[0])))!.cgImage!
    let seconds = Double(line[1]) ?? 1
    let caption = line[2]
    let zoom = Double(line[3]) ?? 1
    let heading = Double(line[4]) ?? 0
    let card = line.count > 5 && !line[5].isEmpty
        ? NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(line[5])))?.cgImage : nil

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.interpolationQuality = .high
    context.setFillColor(background.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Left: the mouse, scaled to fit the panel and centered.
    let panelScale = min(panelRect.width / CGFloat(panel.width), panelRect.height / CGFloat(panel.height))
    let panelSize = CGSize(width: CGFloat(panel.width) * panelScale, height: CGFloat(panel.height) * panelScale)
    context.draw(panel, in: CGRect(x: panelRect.midX - panelSize.width / 2, y: panelRect.midY - panelSize.height / 2,
                                   width: panelSize.width, height: panelSize.height))

    if let card {
        // Right: what this click is for.
        context.draw(card, in: mapRect)
    } else {
        // Right: the map with rounded corners, the pointer at the zoom center, and a compass.
        if let mapImage = map(zoom: zoom, heading: heading) {
            context.saveGState()
            context.addPath(CGPath(roundedRect: mapRect, cornerWidth: 16, cornerHeight: 16, transform: nil))
            context.clip()
            context.draw(mapImage, in: mapRect)
            context.restoreGState()
        }
        drawPointer(at: CGPoint(x: mapRect.midX, y: mapRect.midY), in: context)
        drawCompass(heading: heading, at: CGPoint(x: mapRect.maxX - 34, y: mapRect.maxY - 34), in: context)
        // Top left, so Apple's map credit at the bottom stays visible.
        let label = CGRect(x: mapRect.minX + 12, y: mapRect.maxY - 36, width: 262, height: 24)
        context.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        context.addPath(CGPath(roundedRect: label, cornerWidth: 12, cornerHeight: 12, transform: nil))
        context.fillPath()
        draw("San Francisco · rendered with Apple MapKit", size: 12, weight: .medium, color: NSColor.white.withAlphaComponent(0.85),
             in: label)
    }

    let accent = caption.hasSuffix("!") ? NSColor(red: 1, green: 0.84, blue: 0.3, alpha: 1) : NSColor.white
    draw(caption, size: 30, weight: .bold, color: accent,
         in: CGRect(x: 0, y: CGFloat(height) - captionHeight, width: CGFloat(width), height: captionHeight))
    draw("MagicClick · free & open source · github.com/codeFi/MagicClick", size: 16, weight: .medium,
         color: NSColor.white.withAlphaComponent(0.55), in: CGRect(x: 0, y: 0, width: CGFloat(width), height: footerHeight))
    NSGraphicsContext.restoreGraphicsState()

    CGImageDestinationAddImage(destination, rep.cgImage!, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: seconds, kCGImagePropertyGIFUnclampedDelayTime: seconds,
    ]] as CFDictionary)
}

guard CGImageDestinationFinalize(destination) else {
    print("Could not write \(output.path)")
    exit(1)
}
print("Wrote \(output.path) (\(width)x\(height), \(lines.count) frames)")
