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

        let engine = Engine.shared
        engine.apply(model.config)
        engine.onAction = { [model] text in model.showAction(text) }
        engine.onLive = { [model] snapshot in
            if model.live != snapshot { model.live = snapshot }
        }

        let multitouch = Multitouch.shared
        multitouch.onFrame = { device, isMouse, touches in
            engine.handleFrame(device: device, isMouse: isMouse, touches: touches)
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
        typealias Step = (touches: [Touch], right: Bool, chord: Bool, action: String?, seconds: Double, caption: String)
        let left = Touch(id: 1, x: 0.24, y: 0.7)
        let top = Touch(id: 2, x: 0.5, y: 0.77)
        let right = Touch(id: 3, x: 0.76, y: 0.7)
        let chordLeft = Touch(id: 4, x: 0.27, y: 0.72)
        let middleCaption = "Rest 3 fingers on the mouse and click"
        let chordCaption = "Hold the right click, touch the left half"
        let steps: [Step] = [
            ([], false, false, nil, 1.2, "MagicClick · the clicks your Magic Mouse is missing"),
            ([left], false, false, nil, 0.25, middleCaption),
            ([left, top], false, false, nil, 0.25, middleCaption),
            ([left, top, right], false, false, nil, 0.7, middleCaption),
            ([left, top, right], false, false, "Middle click · 3 fingers", 1.8, "Middle click!"),
            ([], false, false, nil, 0.6, chordCaption),
            ([right], false, false, nil, 0.5, chordCaption),
            ([right], true, false, nil, 0.9, chordCaption),
            ([chordLeft, right], true, true, "Left click · while right is held", 2.0, "Left and right at the same time!"),
            ([right], true, false, nil, 0.6, "Lift the finger to release the left button"),
            ([], false, false, nil, 0.6, "Or pick any key as the middle button"),
            ([], false, false, "Middle click · Play/Pause", 1.8, "Or pick any key as the middle button"),
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
            model.live = LiveSnapshot(touches: step.touches, rightHeld: step.right, chordActive: step.chord)
            if let action = step.action { model.showAction(action) }
            // Wait for SwiftUI to update and the "last action" animation to settle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                let file = String(format: "frame-%02d.png", index)
                self?.writeWindowImage(to: (directory as NSString).appendingPathComponent(file))
                manifest += "\(file)\t\(step.seconds)\t\(step.caption)\n"
                render(index + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { render(0) }
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
