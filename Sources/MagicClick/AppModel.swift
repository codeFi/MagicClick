import AppKit
import ApplicationServices
import ServiceManagement

/// Settings and status shown in the settings window. Lives on the main thread.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var enabled: Bool { didSet { save() } }
    @Published var fingerClick: Bool { didSet { save() } }
    @Published var fingerCount: Int { didSet { save() } }
    @Published var fingerTap: Bool { didSet { save() } }
    @Published var includeTrackpad: Bool { didSet { save() } }
    @Published var trigger: KeyTrigger? { didSet { save() } }
    @Published var extraButton: Int { didSet { save() } }
    @Published var chord: Bool { didSet { save() } }
    @Published var pinchZoom: Bool { didSet { save() } }
    @Published var rotate: Bool { didSet { save() } }

    @Published var isRecording = false
    @Published var trusted = false
    @Published var tapRunning = false
    @Published var mouseConnected = false
    @Published var live = LiveSnapshot()
    @Published var lastAction: String?
    @Published var lastActionID = 0
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("MagicClick: launch at login failed: \(error)")
            }
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "enabled": true, "fingerClick": true, "fingerCount": 3, "fingerTap": false,
            "includeTrackpad": false, "extraButton": 0, "chord": true, "pinchZoom": true, "rotate": true,
        ])
        enabled = defaults.bool(forKey: "enabled")
        fingerClick = defaults.bool(forKey: "fingerClick")
        fingerCount = defaults.integer(forKey: "fingerCount")
        fingerTap = defaults.bool(forKey: "fingerTap")
        includeTrackpad = defaults.bool(forKey: "includeTrackpad")
        extraButton = defaults.integer(forKey: "extraButton")
        chord = defaults.bool(forKey: "chord")
        pinchZoom = defaults.bool(forKey: "pinchZoom")
        rotate = defaults.bool(forKey: "rotate")
        trigger = defaults.data(forKey: "trigger").flatMap { try? JSONDecoder().decode(KeyTrigger.self, from: $0) }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var config: EngineConfig {
        EngineConfig(enabled: enabled, fingerClick: fingerClick, fingerCount: fingerCount, fingerTap: fingerTap,
                     includeTrackpad: includeTrackpad, trigger: trigger, extraButton: extraButton, chord: chord,
                     pinchZoom: pinchZoom, rotate: rotate)
    }

    /// False while rendering the README screenshot, so demo values are not saved.
    var persists = true

    private func save() {
        guard persists else { return }
        defaults.set(enabled, forKey: "enabled")
        defaults.set(fingerClick, forKey: "fingerClick")
        defaults.set(fingerCount, forKey: "fingerCount")
        defaults.set(fingerTap, forKey: "fingerTap")
        defaults.set(includeTrackpad, forKey: "includeTrackpad")
        defaults.set(extraButton, forKey: "extraButton")
        defaults.set(chord, forKey: "chord")
        defaults.set(pinchZoom, forKey: "pinchZoom")
        defaults.set(rotate, forKey: "rotate")
        defaults.set(trigger.flatMap { try? JSONEncoder().encode($0) }, forKey: "trigger")
        Engine.shared.apply(config)
    }

    func showAction(_ text: String) {
        lastAction = text
        lastActionID += 1
    }

    func startRecording() {
        isRecording = true
        Engine.shared.startRecording { [weak self] trigger in
            self?.isRecording = false
            if let trigger { self?.trigger = trigger }
        }
    }

    func cancelRecording() {
        Engine.shared.cancelRecording()
        isRecording = false
    }

    func refreshPermission() {
        let isTrusted = AXIsProcessTrusted()
        if trusted != isTrusted { trusted = isTrusted }
        if isTrusted, !Engine.shared.isTapRunning { Engine.shared.startTap() }
        if tapRunning != Engine.shared.isTapRunning { tapRunning = Engine.shared.isTapRunning }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
