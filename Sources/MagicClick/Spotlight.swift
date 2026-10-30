import AppKit
import QuartzCore

enum SpotlightStyle: String, CaseIterable {
    /// The screen goes dark, except a circle around the pointer.
    case spotlight
    /// A colored ring around the pointer. The screen stays as it is.
    case ring
}

/// What the spotlight looks like and where it shows.
struct SpotlightSettings: Equatable {
    var on = false
    var style = SpotlightStyle.spotlight
    /// The diameter of the clear circle or the ring, in points.
    var size: CGFloat = 200
    /// How dark the screen gets around the circle, from 0 to 1.
    var dim: CGFloat = 0.6
    /// The width of the soft edge around the clear circle, in points.
    var softness: CGFloat = 40
    var dimColor = NSColor.black
    var ringColor = NSColor.systemYellow
    /// A ring that grows and fades on each click, in the color of the button.
    var pulse = true
    /// Displays the spotlight stays off, by `Spotlight.displayID(of:)`.
    var hiddenDisplays: Set<String> = []
}

/// Dims the screen around the pointer, or draws a ring around it, so people can follow it in a demo or a recording.
/// One clear window covers each display, above all other windows. Clicks go through it. Main thread only.
final class Spotlight {
    static let shared = Spotlight()

    private var settings = SpotlightSettings()
    private var overlays: [SpotlightOverlay] = []
    /// True while the hold key is down.
    private var held = false
    private var visible = false
    /// True while the ⌘⇧4 screenshot tool is open.
    private var screenshotToolOpen = false
    /// When ⌘⇧4 was pressed. The tool's windows take a moment to appear.
    private var screenshotKeyTime: TimeInterval = 0
    /// True while that tool picks one window (after Space). Its picker would choose the spotlight instead of
    /// the app under it, and a one-window capture never shows other windows anyway. Area and full-screen
    /// captures keep the spotlight, so they show what is on the screen.
    private var pausedForScreenshot = false
    /// Where the spotlight is. It stays there while the screenshot tool is open, so you can drag a selection around it.
    private var pointer = CGPoint.zero
    /// Set when the Space that switched to one window was held back, so its key-up is held back too.
    private var swallowSpaceUp = false
    private var screenshotTimer: Timer?

    private init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.rebuild() }
    }

    func apply(_ newSettings: SpotlightSettings) {
        let old = settings
        settings = newSettings
        if newSettings.hiddenDisplays != old.hiddenDisplays {
            rebuild()
        } else if newSettings != old {
            overlays.forEach { $0.apply(newSettings) }
            follow(NSEvent.mouseLocation)
        }
        updateVisibility()
    }

    func setHeld(_ down: Bool) {
        held = down
        updateVisibility()
    }

    /// Follows the pointer and pulses on clicks. Gets every event from the event tap, so it returns fast when hidden.
    /// Returns false to drop the event.
    func handle(_ event: CGEvent) -> Bool {
        guard visible else { return true }
        let ours = event.getIntegerValueField(.eventSourceUserData) == Engine.marker
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if !screenshotActive { follow(Self.cocoaPoint(event.location)) }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard !screenshotActive else { return true }
            let point = Self.cocoaPoint(event.location)
            follow(point)
            guard settings.pulse else { return true }
            // The same colors as the live view: blue left, orange right, purple middle.
            let color: NSColor = switch event.type {
            case .leftMouseDown: .systemBlue
            case .rightMouseDown: .systemOrange
            default: .systemPurple
            }
            overlays.first { $0.frame.contains(point) }?.pulse(color, at: point, size: settings.size)
        case .keyDown:
            guard !ours, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return true }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let now = ProcessInfo.processInfo.systemUptime
            if code == 21, event.flags.intersection([.maskCommand, .maskShift, .maskAlternate]) == [.maskCommand, .maskShift] {
                // ⌘⇧4, or ⌃⌘⇧4 to copy: the tool starts in area mode.
                screenshotKeyTime = now
                setPausedForScreenshot(false)
            } else if code == 49, screenshotToolOpen || now - screenshotKeyTime < 1.5 {
                // Space switches the tool between area and one window.
                if pausedForScreenshot {
                    setPausedForScreenshot(false)
                    return true
                }
                // The tool lists the windows when it switches to one window. Hide the spotlight first,
                // then send the Space again, or the tool picks the hidden spotlight and saves a blank picture.
                setPausedForScreenshot(true)
                swallowSpaceUp = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Self.postSpace() }
                return false
            }
        case .keyUp:
            if !ours, swallowSpaceUp, event.getIntegerValueField(.keyboardEventKeycode) == 49 {
                swallowSpaceUp = false
                return false
            }
        default:
            break
        }
        return true
    }

    /// True from ⌘⇧4 until the screenshot tool closes.
    private var screenshotActive: Bool {
        screenshotToolOpen || ProcessInfo.processInfo.systemUptime - screenshotKeyTime < 1.5
    }

    private static func postSpace() {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: down) else { continue }
            event.setIntegerValueField(.eventSourceUserData, value: Engine.marker)
            event.post(tap: .cghidEventTap)
        }
    }

    /// The spotlight windows on screen now, for a window screenshot.
    var windowNumbers: [CGWindowID] {
        visible && !pausedForScreenshot ? overlays.map { CGWindowID($0.window.windowNumber) } : []
    }

    /// A display ID that stays the same after a restart.
    static func displayID(of screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue(),
              let text = CFUUIDCreateString(nil, uuid) else { return screen.localizedName }
        return text as String
    }

    private func rebuild() {
        overlays.forEach { $0.close() }
        overlays = NSScreen.screens
            .filter { !settings.hiddenDisplays.contains(Self.displayID(of: $0)) }
            .map { SpotlightOverlay(screen: $0, settings: settings) }
        if visible, !pausedForScreenshot {
            follow(NSEvent.mouseLocation)
            overlays.forEach { $0.show() }
        }
    }

    private func updateVisibility() {
        let shouldShow = settings.on || held
        guard shouldShow != visible else { return }
        visible = shouldShow
        if visible {
            if overlays.isEmpty { rebuild() }
            follow(NSEvent.mouseLocation)
            overlays.forEach { $0.show() }
            let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in self?.checkScreenshotTool() }
            RunLoop.main.add(timer, forMode: .common)
            screenshotTimer = timer
        } else {
            screenshotTimer?.invalidate()
            screenshotTimer = nil
            pausedForScreenshot = false
            overlays.forEach { $0.hide() }
        }
    }

    /// Notices when the screenshot tool closes, so the spotlight comes back after a one-window screenshot.
    private func checkScreenshotTool() {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let wasActive = screenshotActive
        screenshotToolOpen = list.contains { ($0[kCGWindowOwnerName as String] as? String) == "screencapture" }
        if wasActive, !screenshotActive {
            // The tool closed: follow the pointer again.
            setPausedForScreenshot(false)
            follow(NSEvent.mouseLocation)
        }
    }

    private func setPausedForScreenshot(_ paused: Bool) {
        guard paused != pausedForScreenshot else { return }
        pausedForScreenshot = paused
        if paused {
            overlays.forEach { $0.hideNow() }
        } else {
            follow(screenshotActive ? pointer : NSEvent.mouseLocation)
            overlays.forEach { $0.show() }
        }
    }

    private func follow(_ point: CGPoint) {
        pointer = point
        overlays.forEach { $0.move(to: point) }
    }

    /// Event locations start at the top left of the main display. AppKit starts at its bottom left.
    private static func cocoaPoint(_ point: CGPoint) -> CGPoint {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: height - point.y)
    }
}

/// The clear window on one display.
private final class SpotlightOverlay {
    let frame: CGRect
    let window: NSWindow
    private let scale: CGFloat
    private var settings: SpotlightSettings
    /// The soft hole around the pointer, and four dark bands that fill the rest of the display.
    private let hole = CALayer()
    private let bands = (0..<4).map { _ in CALayer() }
    private let ring = CAShapeLayer()
    private var lastPoint = CGPoint(x: -10_000, y: -10_000)

    init(screen: NSScreen, settings: SpotlightSettings) {
        frame = screen.frame
        scale = screen.backingScaleFactor
        self.settings = settings
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.level = .screenSaver
        // On every desktop and over full-screen apps.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.alphaValue = 0

        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        window.contentView = view
        window.setFrame(frame, display: false)
        let root = view.layer!
        for layer in bands + [hole, ring] {
            layer.contentsScale = scale
            layer.actions = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "contents": NSNull(),
                             "hidden": NSNull(), "backgroundColor": NSNull(), "path": NSNull()]
            root.addSublayer(layer)
        }
        apply(settings)
    }

    func apply(_ newSettings: SpotlightSettings) {
        settings = newSettings
        let isSpotlight = settings.style == .spotlight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hole.isHidden = !isSpotlight
        bands.forEach { $0.isHidden = !isSpotlight }
        ring.isHidden = isSpotlight
        if isSpotlight {
            let image = Self.holeImage(settings, scale: scale)
            hole.contents = image
            hole.bounds.size = CGSize(width: CGFloat(image?.width ?? 0) / scale, height: CGFloat(image?.height ?? 0) / scale)
            let dim = Self.srgb(settings.dimColor).withAlphaComponent(settings.dim).cgColor
            bands.forEach { $0.backgroundColor = dim }
        } else {
            let size = settings.size
            ring.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            ring.path = CGPath(ellipseIn: ring.bounds.insetBy(dx: 2, dy: 2), transform: nil)
            ring.lineWidth = 4
            ring.strokeColor = settings.ringColor.cgColor
            ring.fillColor = settings.ringColor.withAlphaComponent(0.12).cgColor
            ring.shadowColor = NSColor.black.cgColor
            ring.shadowOpacity = 0.45
            ring.shadowRadius = 3
            ring.shadowOffset = .zero
        }
        CATransaction.commit()
        move(to: lastPoint)
    }

    /// `point` is in screen coordinates. The display stays fully dark when the pointer is on another display.
    func move(to point: CGPoint) {
        lastPoint = point
        let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if settings.style == .spotlight {
            // Whole pixels, so the hole and the bands meet without a visible line.
            let size = hole.bounds.size
            let origin = CGPoint(x: (round((local.x - size.width / 2) * scale)) / scale,
                                 y: (round((local.y - size.height / 2) * scale)) / scale)
            let square = CGRect(origin: origin, size: size)
            hole.frame = square
            let width = frame.width, height = frame.height
            func clampX(_ x: CGFloat) -> CGFloat { min(max(x, 0), width) }
            func clampY(_ y: CGFloat) -> CGFloat { min(max(y, 0), height) }
            let bottom = clampY(square.minY), top = clampY(square.maxY)
            let left = clampX(square.minX), right = clampX(square.maxX)
            bands[0].frame = CGRect(x: 0, y: 0, width: width, height: bottom)
            bands[1].frame = CGRect(x: 0, y: top, width: width, height: height - top)
            bands[2].frame = CGRect(x: 0, y: bottom, width: left, height: top - bottom)
            bands[3].frame = CGRect(x: right, y: bottom, width: width - right, height: top - bottom)
        } else {
            ring.position = local
        }
        CATransaction.commit()
    }

    func pulse(_ color: NSColor, at point: CGPoint, size: CGFloat) {
        guard let root = window.contentView?.layer else { return }
        let diameter = min(max(size * 0.6, 40), 220)
        let layer = CAShapeLayer()
        layer.contentsScale = scale
        layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        layer.position = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        layer.path = CGPath(ellipseIn: layer.bounds.insetBy(dx: 3, dy: 3), transform: nil)
        layer.lineWidth = 5
        layer.strokeColor = color.cgColor
        layer.fillColor = color.withAlphaComponent(0.25).cgColor
        layer.opacity = 0

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.35
        grow.toValue = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        root.addSublayer(layer)
        layer.add(group, forKey: "pulse")
        CATransaction.commit()
    }

    private var shown = false

    func show() {
        shown = true
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1
        }
    }

    func hide() {
        shown = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Shown again while it faded out.
            guard let self, !self.shown else { return }
            self.window.orderOut(nil)
        })
    }

    func hideNow() {
        shown = false
        window.alphaValue = 0
        window.orderOut(nil)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }

    /// A square that is clear in the middle, with a soft edge, and dark in the corners.
    private static func holeImage(_ settings: SpotlightSettings, scale: CGFloat) -> CGImage? {
        let radius = settings.size / 2
        let inner = max(0, radius - settings.softness / 2)
        let outer = max(radius + settings.softness / 2, inner + 1)
        let side = Int(ceil((outer + 1) * 2 * scale))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let color = srgb(settings.dimColor)
        let colors = [color.withAlphaComponent(0).cgColor, color.withAlphaComponent(0).cgColor,
                      color.withAlphaComponent(settings.dim).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, inner / outer, 1]) else { return nil }
        let center = CGPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: outer * scale,
                                   options: [.drawsAfterEndLocation])
        return context.makeImage()
    }

    private static func srgb(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.sRGB) ?? .black
    }
}
