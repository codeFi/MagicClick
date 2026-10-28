// Turns the frames from `MagicClick --demo-frames <dir>` into an animated GIF.
// Run: swift scripts/make-gif.swift <dir> <out.gif>
import AppKit
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift scripts/make-gif.swift <frames dir> <out.gif>")
    exit(1)
}
let directory = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

// The "Live view" card inside a 2x window frame, and the size of the GIF.
let cardRect = CGRect(x: 20, y: 420, width: 1120, height: 500)
let width = 800
let scale = CGFloat(width) / cardRect.width
let captionHeight: CGFloat = 96
let footerHeight: CGFloat = 52
let height = Int(captionHeight + cardRect.height * scale + footerHeight)

let lines = try String(contentsOf: directory.appendingPathComponent("frames.txt"), encoding: .utf8)
    .split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }

let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, lines.count, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)

func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style,
    ])
    let textHeight = string.size().height
    string.draw(in: NSRect(x: 0, y: centerY - textHeight / 2, width: CGFloat(width), height: textHeight + 4))
}

for line in lines {
    let frame = NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(line[0])))!.cgImage!
    let seconds = Double(line[1]) ?? 1
    let caption = line[2]

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.interpolationQuality = .high

    // Window background: one pixel of the frame, stretched.
    let background = frame.cropping(to: CGRect(x: 4, y: 4, width: 1, height: 1))!
    context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))

    let card = frame.cropping(to: cardRect)!
    context.draw(card, in: CGRect(x: 0, y: footerHeight, width: CGFloat(width), height: cardRect.height * scale))

    let accent = caption.hasSuffix("!") ? NSColor(red: 1, green: 0.84, blue: 0.3, alpha: 1) : NSColor.white
    draw(caption, size: 30, weight: .bold, color: accent, centerY: CGFloat(height) - captionHeight / 2 - 4)
    draw("MagicClick · free & open source · github.com/codeFi/MagicClick", size: 17, weight: .medium,
         color: NSColor.white.withAlphaComponent(0.55), centerY: footerHeight / 2)
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
