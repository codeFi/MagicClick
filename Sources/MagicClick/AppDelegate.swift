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
            snapshot(to: arguments[index + 1], demo: arguments.contains("--demo"))
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
    /// `--demo` fills in example fingers and a granted permission.
    private func snapshot(to path: String, demo: Bool) {
        model.persists = false
        if demo {
            model.trusted = true
            model.tapRunning = true
            model.mouseConnected = true
            model.trigger = .media(code: 16)
            model.live = LiveSnapshot(touches: [Touch(id: 1, x: 0.28, y: 0.72), Touch(id: 2, x: 0.72, y: 0.7)],
                                      rightHeld: true, chordActive: true)
            model.showAction("Left click · while right is held")
        }
        showSettings()
        window?.setContentSize(NSSize(width: 580, height: 1240))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Render at 2x so the image stays sharp on Retina screens and in the README.
            if let view = self?.window?.contentView,
               let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2),
                                          pixelsHigh: Int(view.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                          hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0) {
                rep.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        Engine.shared.setLiveUpdates(false)
        if model.isRecording { model.cancelRecording() }
        statusItem?.button?.appearsDisabled = !model.enabled
    }
}
