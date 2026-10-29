import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let model = AppModel.shared
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
            var demo: String?
            if let demoIndex = arguments.firstIndex(of: "--demo") {
                demo = demoIndex + 1 < arguments.count ? arguments[demoIndex + 1] : "middle"
            }
            snapshot(to: arguments[index + 1], demo: demo)
            return
        }
        if let index = arguments.firstIndex(of: "--demo-frames"), index + 1 < arguments.count {
            renderDemoFrames(to: arguments[index + 1])
            return
        }
        if let index = arguments.firstIndex(of: "--gesture-frames"), index + 1 < arguments.count {
            renderGestureFrames(to: arguments[index + 1])
            NSApp.terminate(nil)
            return
        }

        let engine = Engine.shared
        engine.apply(model.config)
        engine.onAction = { [model] text in model.showAction(text) }
        engine.onLive = { [model] snapshot in
            if model.live != snapshot { model.live = snapshot }
        }

        let multitouch = Multitouch.shared
        multitouch.onFrame = { device, isMouse, aspect, touches in
            engine.handleFrame(device: device, isMouse: isMouse, aspect: aspect, touches: touches)
        }
        multitouch.onDevicesChanged = { [model] connected in model.mouseConnected = connected }
        multitouch.start()

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Multitouch.shared.scheduleRestart(after: 2)
        }

        setUpStatusItem()
        model.refreshPermission()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [model] _ in
            model.refreshPermission()
        }

        if !model.trusted || !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "MagicClick")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: "MagicClick", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let status: String
        if !model.trusted {
            status = "Needs Accessibility permission"
        } else if !model.enabled {
            status = "Paused"
        } else {
            status = model.mouseConnected ? "Active · Magic Mouse connected" : "Active · no Magic Mouse found"
        }
        let statusLine = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = model.enabled ? .on : .off
        menu.addItem(toggle)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit MagicClick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggleEnabled() {
        model.enabled.toggle()
        statusItem?.button?.appearsDisabled = !model.enabled
    }

    @objc private func openSettings() {
        showSettings()
    }

    // MARK: Settings window

    func showSettings() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().environmentObject(model))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "MagicClick"
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            newWindow.titlebarAppearsTransparent = true
            newWindow.isReleasedWhenClosed = false
            newWindow.setContentSize(NSSize(width: 580, height: 820))
            newWindow.center()
            newWindow.delegate = self
            window = newWindow
        }
        Engine.shared.setLiveUpdates(true)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Renders the settings window to a PNG and quits. Used for the README screenshot.
    /// `--demo middle` shows a 3-finger middle click, `--demo chord` a left click while right is held.
    /// Both also show a granted permission.
    private func snapshot(to path: String, demo: String?) {
        model.persists = false
        if let demo {
            model.trusted = true
            model.tapRunning = true
            model.mouseConnected = true
            model.trigger = .media(code: 16)
            if demo == "chord" {
                model.live = LiveSnapshot(touches: [Touch(id: 1, x: 0.27, y: 0.72), Touch(id: 2, x: 0.73, y: 0.7)],
                                          rightHeld: true, chordActive: true)
                model.showAction("Left click · while right is held")
            } else {
                model.live = LiveSnapshot(touches: [Touch(id: 1, x: 0.24, y: 0.7), Touch(id: 2, x: 0.5, y: 0.77),
                                                    Touch(id: 3, x: 0.76, y: 0.7)])
                model.showAction("Middle click · 3 fingers")
            }
        }
        showSettings()
        window?.setContentSize(NSSize(width: 580, height: 1240))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.writeWindowImage(to: path)
            NSApp.terminate(nil)
        }
    }

    /// Plays a scripted demo in the live view and saves one PNG per step, plus `frames.txt`
    /// with "file<TAB>seconds<TAB>caption" lines. `scripts/make-gif.swift` turns them into a GIF.
    private func renderDemoFrames(to directory: String) {
        typealias Step = (touches: [Touch], right: Bool, chord: Bool, gestures: Set<GestureKind>, action: String?,
                         seconds: Double, caption: String)
        let left = Touch(id: 1, x: 0.24, y: 0.7)
        let top = Touch(id: 2, x: 0.5, y: 0.77)
        let right = Touch(id: 3, x: 0.76, y: 0.7)
        let chordLeft = Touch(id: 4, x: 0.27, y: 0.72)
        let middleCaption = "Rest 3 fingers on the mouse and click"
        let chordCaption = "Hold the right click, touch the left half"
        let zoomCaption = "Spread two fingers to zoom"
        let rotateCaption = "Turn two fingers to rotate"
        // Two fingers that spread apart, then two fingers that turn around a point, in `step` stages.
        func pinchA(_ step: Int) -> Touch { Touch(id: 5, x: 0.4 - 0.06 * Float(step), y: 0.7 - 0.02 * Float(step)) }
        func pinchB(_ step: Int) -> Touch { Touch(id: 6, x: 0.6 + 0.06 * Float(step), y: 0.74 + 0.02 * Float(step)) }
        func turn(_ degrees: Float, id: Int32) -> Touch {
            let angle = degrees * .pi / 180
            // The drawing is taller than wide, so a circle needs a smaller radius in y.
            return Touch(id: id, x: 0.5 + 0.26 * cos(angle), y: 0.72 + 0.15 * sin(angle))
        }
        func turnA(_ step: Int) -> Touch { turn(200 + 20 * Float(step), id: 7) }
        func turnB(_ step: Int) -> Touch { turn(20 + 20 * Float(step), id: 8) }
        let steps: [Step] = [
            ([], false, false, [], nil, 1.2, "MagicClick · the clicks and gestures your Magic Mouse is missing"),
            ([left], false, false, [], nil, 0.25, middleCaption),
            ([left, top], false, false, [], nil, 0.25, middleCaption),
            ([left, top, right], false, false, [], nil, 0.7, middleCaption),
            ([left, top, right], false, false, [], "Middle click · 3 fingers", 1.8, "Middle click!"),
            ([], false, false, [], nil, 0.6, chordCaption),
            ([right], false, false, [], nil, 0.5, chordCaption),
            ([right], true, false, [], nil, 0.9, chordCaption),
            ([chordLeft, right], true, true, [], "Left click · while right is held", 2.0, "Left and right at the same time!"),
            ([right], true, false, [], nil, 0.6, "Lift the finger to release the left button"),
            ([pinchA(0), pinchB(0)], false, false, [], nil, 0.7, zoomCaption),
            ([pinchA(1), pinchB(1)], false, false, [.zoom], "Pinch to zoom", 0.3, zoomCaption),
            ([pinchA(2), pinchB(2)], false, false, [.zoom], nil, 0.3, zoomCaption),
            ([pinchA(3), pinchB(3)], false, false, [.zoom], nil, 1.6, "Zoom where the pointer is, like a trackpad"),
            ([turnA(0), turnB(0)], false, false, [], nil, 0.7, rotateCaption),
            ([turnA(1), turnB(1)], false, false, [.rotate], "Rotate", 0.3, rotateCaption),
            ([turnA(2), turnB(2)], false, false, [.rotate], nil, 0.3, rotateCaption),
            ([turnA(3), turnB(3)], false, false, [.rotate], nil, 1.6, "Rotate maps, photos and PDFs"),
            ([], false, false, [], nil, 0.6, "Or pick any key as the middle button"),
            ([], false, false, [], "Middle click · Play/Pause", 1.8, "Or pick any key as the middle button"),
        ]

        model.persists = false
        model.trusted = true
        model.tapRunning = true
        model.mouseConnected = true
        model.trigger = .media(code: 16)
        showSettings()
        window?.setContentSize(NSSize(width: 580, height: 620))
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        var manifest = ""
        func render(_ index: Int) {
            guard index < steps.count else {
                try? manifest.write(toFile: (directory as NSString).appendingPathComponent("frames.txt"), atomically: true, encoding: .utf8)
                NSApp.terminate(nil)
                return
            }
            let step = steps[index]
            model.live = LiveSnapshot(touches: step.touches, rightHeld: step.right, chordActive: step.chord,
                                      gestures: step.gestures)
            if let action = step.action { model.showAction(action) }
            // Wait for SwiftUI to update and the "last action" animation to settle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                let file = String(format: "frame-%02d.png", index)
                self?.writeWindowImage(to: (directory as NSString).appendingPathComponent(file))
                manifest += "\(file)\t\(step.seconds)\t\(step.caption)\n"
                render(index + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // The settings are taller than the window, so start at the top where the live view is.
            self?.scrollToTop(self?.window?.contentView)
            render(0)
        }
    }

    private func scrollToTop(_ view: NSView?) {
        guard let view else { return }
        if let scrollView = view as? NSScrollView, let document = scrollView.documentView {
            let top = document.isFlipped ? document.bounds.minY : document.bounds.maxY - 1
            document.scrollToVisible(NSRect(x: 0, y: top, width: 1, height: 1))
            return
        }
        view.subviews.forEach(scrollToTop)
    }

    /// Draws the mouse for a scripted demo of every feature and saves one PNG per step, plus `frames.txt` with
    /// "file<TAB>seconds<TAB>caption<TAB>zoom<TAB>heading<TAB>card" lines. Zoom 1 is the starting map scale and heading
    /// is the map rotation in degrees. Click scenes name a card PNG for the right side instead of a map.
    /// `scripts/make-maps-gif.swift` puts it together.
    private func renderGestureFrames(to directory: String) {
        struct Card { var symbol: String; var title: String; var lines: [String]; var key: String? }
        struct Step {
            var touches: [Touch] = []; var right = false; var chord = false; var gestures: Set<GestureKind> = []
            var action: String?; var seconds: Double; var caption: String
            var zoom = 1.0; var heading = 0.0; var card: Card?; var active = false
        }
        // Two fingers on a circle around the middle of the mouse. The drawing is 1.75 times taller than wide,
        // so a real circle needs a smaller radius in y.
        func fingers(_ degrees: Double, _ radius: Double) -> [Touch] {
            [0.0, 180.0].enumerated().map { index, offset in
                let angle = (degrees + offset) * .pi / 180
                return Touch(id: Int32(index + 1), x: Float(0.5 + radius * cos(angle)), y: Float(0.66 + radius * sin(angle) / 1.75))
            }
        }
        func ease(_ t: Double) -> Double { t * t * (3 - 2 * t) }
        let left = Touch(id: 1, x: 0.24, y: 0.7)
        let top = Touch(id: 2, x: 0.5, y: 0.77)
        let right = Touch(id: 3, x: 0.76, y: 0.7)
        let chordLeft = Touch(id: 4, x: 0.27, y: 0.72)
        let middleCard = Card(symbol: "plus.square.on.square", title: "Middle click",
                              lines: ["Open links in a new tab", "Close tabs with one click", "Pan in Blender, CAD and 3D apps"])
        let chordCard = Card(symbol: "gamecontroller.fill", title: "Left + right click together",
                             lines: ["Hold right, touch the left half", "For games and pro apps", "Left stays down until you lift"])
        let keyCard = Card(symbol: "keyboard", title: "Any key as the middle button",
                           lines: ["F-keys, media keys and fn", "Right ⌘ ⌥ ⌃ ⇧ on their own", "Hold the key to middle-drag"],
                           key: "⏯  Play/Pause")
        let middleCaption = "Rest 3 fingers on the mouse and click"
        let chordCaption = "Hold the right click, touch the left half"
        let keyCaption = "Or pick any key as the middle button"

        var steps: [Step] = [
            Step(seconds: 1.6, caption: "The clicks and gestures your Magic Mouse is missing"),
            Step(touches: [left], seconds: 0.25, caption: middleCaption, card: middleCard),
            Step(touches: [left, top], seconds: 0.25, caption: middleCaption, card: middleCard),
            Step(touches: [left, top, right], seconds: 0.7, caption: middleCaption, card: middleCard),
            Step(touches: [left, top, right], action: "Middle click", seconds: 1.8, caption: "Middle click!", card: middleCard, active: true),
            Step(seconds: 0.5, caption: chordCaption, card: chordCard),
            Step(touches: [right], seconds: 0.5, caption: chordCaption, card: chordCard),
            Step(touches: [right], right: true, seconds: 0.9, caption: chordCaption, card: chordCard),
            Step(touches: [chordLeft, right], right: true, chord: true, action: "Left + right", seconds: 2.0,
                 caption: "Left and right at the same time!", card: chordCard, active: true),
            Step(touches: [right], right: true, seconds: 0.6, caption: "Lift the finger to release the left button", card: chordCard),
            Step(seconds: 0.7, caption: keyCaption, card: keyCard),
            Step(action: "Middle click", seconds: 1.8, caption: keyCaption, card: keyCard, active: true),
            Step(seconds: 1.2, caption: "And trackpad gestures, right where the pointer is"),
            Step(touches: fingers(30, 0.12), seconds: 0.5, caption: "Spread two fingers to zoom in"),
        ]
        let frames = 14
        for i in 1...frames {
            let t = ease(Double(i) / Double(frames))
            steps.append(Step(touches: fingers(30, 0.12 + 0.2 * t), gestures: [.zoom], action: "Pinch to zoom", seconds: 0.07,
                              caption: "Spread two fingers to zoom in", zoom: pow(3.5, t)))
        }
        steps[steps.count - 1].seconds = 1.0
        steps.append(Step(action: "Pinch to zoom", seconds: 0.4, caption: "It zooms where the pointer is", zoom: 3.5))
        steps.append(Step(touches: fingers(20, 0.26), seconds: 0.5, caption: "Turn two fingers to rotate", zoom: 3.5))
        for i in 1...frames {
            let t = ease(Double(i) / Double(frames))
            steps.append(Step(touches: fingers(20 + 70 * t, 0.26), gestures: [.rotate], action: "Rotate", seconds: 0.07,
                              caption: "Turn two fingers to rotate", zoom: 3.5, heading: 70 * t))
        }
        steps[steps.count - 1].seconds = 1.0
        steps.append(Step(action: "Rotate", seconds: 0.4, caption: "Zoom and rotate at the same time", zoom: 3.5, heading: 70))
        steps.append(Step(touches: fingers(100, 0.3), seconds: 0.5, caption: "Zoom and rotate at the same time", zoom: 3.5, heading: 70))
        for i in 1...frames {
            let t = ease(Double(i) / Double(frames))
            steps.append(Step(touches: fingers(100 - 70 * t, 0.3 - 0.17 * t), gestures: [.zoom, .rotate], action: "Zoom + rotate",
                              seconds: 0.07, caption: "Zoom and rotate at the same time", zoom: 3.5 * pow(1 / 3.5, t), heading: 70 * (1 - t)))
        }
        steps[steps.count - 1].seconds = 1.2
        steps.append(Step(action: "Zoom + rotate", seconds: 1.6, caption: "MagicClick · free & open source"))

        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        @MainActor func write<Content: View>(_ view: Content, to file: String) -> Bool {
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
            return (try? data.write(to: URL(fileURLWithPath: (directory as NSString).appendingPathComponent(file)))) != nil
        }
        var manifest = ""
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            for (index, step) in steps.enumerated() {
                let live = LiveSnapshot(touches: step.touches, rightHeld: step.right, chordActive: step.chord, gestures: step.gestures)
                let panel = VStack(spacing: 18) {
                    MouseDiagram(live: live, middleCount: 3)
                        .frame(width: 160, height: 280)
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                        Text(step.action ?? "Ready").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    }
                    .opacity(step.action == nil ? 0.4 : 1)
                }
                .padding(20)
                let file = String(format: "gesture-%02d.png", index)
                guard write(panel, to: file) else { continue }
                var cardFile = ""
                if let card = step.card {
                    cardFile = String(format: "card-%02d.png", index)
                    let view = DemoCard(symbol: card.symbol, title: card.title, lines: card.lines, key: card.key, active: step.active)
                    if !write(view, to: cardFile) { cardFile = "" }
                }
                manifest += "\(file)\t\(step.seconds)\t\(step.caption)\t\(step.zoom)\t\(step.heading)\t\(cardFile)\n"
            }
        }
        try? manifest.write(toFile: (directory as NSString).appendingPathComponent("frames.txt"), atomically: true, encoding: .utf8)
    }

    /// Writes the settings window content as a 2x PNG.
    private func writeWindowImage(to path: String) {
        guard let view = window?.contentView,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2),
                                         pixelsHigh: Int(view.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    func windowWillClose(_ notification: Notification) {
        Engine.shared.setLiveUpdates(false)
        if model.isRecording { model.cancelRecording() }
        statusItem?.button?.appearsDisabled = !model.enabled
    }
}

/// The right side of a click scene in the demo GIF: what the click is good for.
private struct DemoCard: View {
    let symbol: String
    let title: String
    let lines: [String]
    let key: String?
    let active: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(active ? Color.yellow : Color.white.opacity(0.85))
            if let key {
                Text(key)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(active ? 0.3 : 0.12)))
            }
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(line).foregroundStyle(Color.white.opacity(0.85))
                    }
                    .font(.system(size: 19, weight: .medium))
                }
            }
        }
        .frame(width: 624, height: 464)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.17)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? Color.yellow : Color.clear, lineWidth: 3))
    }
}
