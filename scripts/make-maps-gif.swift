// Turns the frames from `MagicClick --gesture-frames <dir>` into the showcase GIF: the mouse on the left, and on
// the right either a card that says what a click is for, or a San Francisco map rendered with MapKit that zooms
// and rotates the same way as the fingers. Wide cards fill the frame. With --movie, the "@clips" line becomes the
// spotlight clips listed in --clips (scripts/showcase-clips.txt), cut from a full-screen recording.
// With --mp4, it also writes a sharp 1920x1200 video of the same showcase.
// Run: swift scripts/make-maps-gif.swift <dir> <out.gif> [--movie <recording.mov> --clips <clips.txt>] [--mp4 <out.mp4>]
import AppKit
import AVFoundation
import ImageIO
import MapKit
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}
guard arguments.count >= 3 else {
    print("usage: swift scripts/make-maps-gif.swift <frames dir> <out.gif> [--movie <rec.mov> --clips <clips.txt>] [--mp4 <out.mp4>]")
    exit(1)
}
let directory = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let movie = option("--movie").map { URL(fileURLWithPath: $0) }
let clipsFile = option("--clips").map { URL(fileURLWithPath: $0) }
let mp4 = option("--mp4").map { URL(fileURLWithPath: $0) }

let width = 960, height = 600
let captionHeight: CGFloat = 76
let footerHeight: CGFloat = 44
let mapRect = CGRect(x: 312, y: footerHeight + 8, width: 624, height: CGFloat(height) - captionHeight - footerHeight - 16)
let panelRect = CGRect(x: 24, y: footerHeight + 8, width: 264, height: mapRect.height)
// Wide cards and screen clips: 16:9, centered.
let wideRect = CGRect(x: (CGFloat(width) - mapRect.height * 16 / 9) / 2, y: mapRect.minY, width: mapRect.height * 16 / 9,
                      height: mapRect.height)
let chapters = ["Middle click", "Left + right", "Keys", "Zoom & rotate", "Spotlight"]
/// Frames are drawn at 2x for the video. The GIF gets them at 1x.
let scale = 2
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

/// The footer: the chapters, with the current one lit. Chapter 0 shows the project address instead.
func drawFooter(chapter: Int, in context: CGContext) {
    guard chapter > 0 else {
        draw("MagicClick · free & open source · github.com/codeFi/MagicClick", size: 16, weight: .medium,
             color: NSColor.white.withAlphaComponent(0.55), in: CGRect(x: 0, y: 0, width: CGFloat(width), height: footerHeight))
        return
    }
    let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let widths = chapters.map { ($0 as NSString).size(withAttributes: [.font: font]).width + 26 }
    let spacing: CGFloat = 8
    var x = (CGFloat(width) - widths.reduce(0, +) - spacing * CGFloat(chapters.count - 1)) / 2
    for (index, name) in chapters.enumerated() {
        let rect = CGRect(x: x, y: (footerHeight - 26) / 2, width: widths[index], height: 26)
        let current = index + 1 == chapter
        context.setFillColor((current ? NSColor.white : NSColor.white.withAlphaComponent(0.08)).cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 13, cornerHeight: 13, transform: nil))
        context.fillPath()
        draw(name, size: 13, weight: .semibold,
             color: current ? NSColor(white: 0.1, alpha: 1) : NSColor.white.withAlphaComponent(index + 1 < chapter ? 0.75 : 0.45),
             in: rect)
        x += widths[index] + spacing
    }
}

func drawCaption(_ caption: String) {
    let accent = caption.hasSuffix("!") ? NSColor(red: 1, green: 0.84, blue: 0.3, alpha: 1) : NSColor.white
    draw(caption, size: 30, weight: .bold, color: accent,
         in: CGRect(x: 0, y: CGFloat(height) - captionHeight, width: CGFloat(width), height: captionHeight))
}

/// Draws one frame at 2x and returns it.
func frame(_ body: (CGContext) -> Void) -> CGImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.interpolationQuality = .high
    context.setFillColor(background.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    body(context)
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

/// A card or clip with rounded corners and a thin border.
func drawRounded(_ image: CGImage, in rect: CGRect, context: CGContext) {
    let path = CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil)
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(image, in: rect)
    context.restoreGState()
    context.addPath(path)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
    context.setLineWidth(1)
    context.strokePath()
}

// MARK: Output

let clipFPS = 10.0
/// The clips file lines: start, end, from crop, to crop, caption.
let clipLines: [[String]] = clipsFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) }.map {
    $0.split(separator: "\n").filter { !$0.hasPrefix("#") }
        .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }.filter { $0.count >= 5 }
} ?? []
func clipTimes(_ fields: [String]) -> [Double] {
    guard let start = Double(fields[0]), let end = Double(fields[1]) else { return [] }
    return Array(stride(from: start, to: end, by: 1 / clipFPS))
}
let clipFrames = movie == nil ? 0 : clipLines.reduce(0) { $0 + clipTimes($1).count }
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString,
                                                  lines.filter { $0[0] != "@clips" }.count + clipFrames, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)

var writer: AVAssetWriter?
var writerInput: AVAssetWriterInput?
var adaptor: AVAssetWriterInputPixelBufferAdaptor?
var videoTime = CMTime.zero
if let mp4 {
    try? FileManager.default.removeItem(at: mp4)
    let assetWriter = try AVAssetWriter(outputURL: mp4, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width * scale, AVVideoHeightKey: height * scale,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000],
    ])
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: width * scale, kCVPixelBufferHeightKey as String: height * scale,
    ])
    assetWriter.add(input)
    assetWriter.startWriting()
    assetWriter.startSession(atSourceTime: .zero)
    writer = assetWriter
    writerInput = input
}

var frameCount = 0
/// Adds one frame to the GIF (at 1x) and to the video (at 2x).
func emit(_ image: CGImage, seconds: Double) {
    let small = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    small.interpolationQuality = .high
    small.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CGImageDestinationAddImage(destination, small.makeImage()!, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: seconds, kCGImagePropertyGIFUnclampedDelayTime: seconds,
    ]] as CFDictionary)
    frameCount += 1

    guard let adaptor, let writerInput, let pool = adaptor.pixelBufferPool else { return }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let buffer else { return }
    CVPixelBufferLockBaseAddress(buffer, [])
    let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width * scale, height: height * scale,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width * scale, height: height * scale))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    while !writerInput.isReadyForMoreMediaData { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    adaptor.append(buffer, withPresentationTime: videoTime)
    videoTime = CMTimeAdd(videoTime, CMTime(seconds: seconds, preferredTimescale: 600))
}

/// The spotlight clips: "start<TAB>end<TAB>from<TAB>to<TAB>caption" in seconds of the recording. From and to are crops
/// "x,y,w,h" in recording pixels, or "full". The crop moves from one to the other in the first half second.
func emitClips(chapter: Int) throws {
    guard let movie, !clipLines.isEmpty else { print("No --movie and --clips, skipping the spotlight clips"); return }
    let asset = AVURLAsset(url: movie)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let track = asset.tracks(withMediaType: .video).first!
    let full = CGRect(origin: .zero, size: track.naturalSize)
    func crop(_ text: String) -> CGRect {
        let values = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return values.count == 4 ? CGRect(x: values[0], y: values[1], width: values[2], height: values[3]) : full
    }
    for fields in clipLines {
        let from = crop(fields[2]), to = crop(fields[3])
        let start = Double(fields[0])!
        for time in clipTimes(fields) {
            let t = min(1, (time - start) / 0.5)
            let e = t * t * (3 - 2 * t)
            let rect = CGRect(x: from.minX + (to.minX - from.minX) * e, y: from.minY + (to.minY - from.minY) * e,
                              width: from.width + (to.width - from.width) * e, height: from.height + (to.height - from.height) * e)
            let shot = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            // The crop is in top-left pixels, like the recording.
            let cropped = shot.cropping(to: rect.integral)!
            emit(frame { context in
                drawRounded(cropped, in: wideRect, context: context)
                drawCaption(fields[4])
                drawFooter(chapter: chapter, in: context)
            }, seconds: 1 / clipFPS)
        }
    }
}

for line in lines {
    let chapter = line.count > 6 ? Int(line[6]) ?? 0 : 0
    if line[0] == "@clips" {
        try emitClips(chapter: chapter)
        continue
    }
    let panel = NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(line[0])))!.cgImage!
    let seconds = Double(line[1]) ?? 1
    let caption = line[2]
    let zoom = Double(line[3]) ?? 1
    let heading = Double(line[4]) ?? 0
    let card = line.count > 5 && !line[5].isEmpty
        ? NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(line[5])))?.cgImage : nil
    let wide = line.count > 5 && line[5].hasPrefix("wide-")
    let mapImage = card == nil ? map(zoom: zoom, heading: heading) : nil

    emit(frame { context in
        if let card, wide {
            context.draw(card, in: wideRect)
        } else {
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
                if let mapImage { drawRounded(mapImage, in: mapRect, context: context) }
                drawPointer(at: CGPoint(x: mapRect.midX, y: mapRect.midY), in: context)
                drawCompass(heading: heading, at: CGPoint(x: mapRect.maxX - 34, y: mapRect.maxY - 34), in: context)
                // Top left, so Apple's map credit at the bottom stays visible.
                let label = CGRect(x: mapRect.minX + 12, y: mapRect.maxY - 36, width: 262, height: 24)
                context.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
                context.addPath(CGPath(roundedRect: label, cornerWidth: 12, cornerHeight: 12, transform: nil))
                context.fillPath()
                draw("San Francisco · rendered with Apple MapKit", size: 12, weight: .medium,
                     color: NSColor.white.withAlphaComponent(0.85), in: label)
            }
        }
        drawCaption(caption)
        drawFooter(chapter: chapter, in: context)
    }, seconds: seconds)
}

guard CGImageDestinationFinalize(destination) else {
    print("Could not write \(output.path)")
    exit(1)
}
print("Wrote \(output.path) (\(width)x\(height), \(frameCount) frames)")
if let writer, let writerInput {
    writerInput.markAsFinished()
    writer.endSession(atSourceTime: videoTime)
    var done = false
    writer.finishWriting { done = true }
    while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    print(writer.status == .completed ? "Wrote \(mp4!.path) (\(width * scale)x\(height * scale))" : "Video failed: \(String(describing: writer.error))")
}
