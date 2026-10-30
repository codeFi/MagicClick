import AppKit
import ApplicationServices
import ServiceManagement

/// The things a recorded key can do. One key does only one of them.
enum KeyRole: CaseIterable {
    case middle, spotlightToggle, spotlightHold, windowShot

    var keyPath: ReferenceWritableKeyPath<AppModel, KeyTrigger?> {
        switch self {
        case .middle: \.trigger
        case .spotlightToggle: \.spotlightToggle
        case .spotlightHold: \.spotlightHold
        case .windowShot: \.windowShotKey
        }
    }
}

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
    @Published var spotlightOn: Bool { didSet { save() } }
    @Published var spotlightStyle: SpotlightStyle { didSet { save() } }
    @Published var spotlightSize: Double { didSet { save() } }
    @Published var spotlightDim: Double { didSet { save() } }
    @Published var spotlightSoftness: Double { didSet { save() } }
    @Published var spotlightColor: NSColor { didSet { save() } }
    @Published var ringColor: NSColor { didSet { save() } }
    @Published var spotlightPulse: Bool { didSet { save() } }
    @Published var spotlightToggle: KeyTrigger? { didSet { save() } }
    @Published var spotlightHold: KeyTrigger? { didSet { save() } }
    @Published var windowShotKey: KeyTrigger? { didSet { save() } }
    @Published var spotlightHiddenDisplays: Set<String> { didSet { save() } }

    /// The key the settings window waits for, if any.
    @Published var recording: KeyRole?
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
            "spotlightOn": false, "spotlightStyle": SpotlightStyle.spotlight.rawValue, "spotlightSize": 220.0,
            "spotlightDim": 0.6, "spotlightSoftness": 40.0, "spotlightPulse": true,
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
        spotlightOn = defaults.bool(forKey: "spotlightOn")
        spotlightStyle = SpotlightStyle(rawValue: defaults.string(forKey: "spotlightStyle") ?? "") ?? .spotlight
        spotlightSize = defaults.double(forKey: "spotlightSize")
        spotlightDim = defaults.double(forKey: "spotlightDim")
        spotlightSoftness = defaults.double(forKey: "spotlightSoftness")
        spotlightColor = Self.color(defaults.data(forKey: "spotlightColor")) ?? .black
        ringColor = Self.color(defaults.data(forKey: "ringColor")) ?? .systemYellow
        spotlightPulse = defaults.bool(forKey: "spotlightPulse")
        spotlightHiddenDisplays = Set(defaults.stringArray(forKey: "spotlightHiddenDisplays") ?? [])
        trigger = Self.key(defaults.data(forKey: "trigger"))
        spotlightToggle = Self.key(defaults.data(forKey: "spotlightToggle"))
        spotlightHold = Self.key(defaults.data(forKey: "spotlightHold"))
        windowShotKey = Self.key(defaults.data(forKey: "windowShotKey"))
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var config: EngineConfig {
        EngineConfig(enabled: enabled, fingerClick: fingerClick, fingerCount: fingerCount, fingerTap: fingerTap,
                     includeTrackpad: includeTrackpad, trigger: trigger, extraButton: extraButton, chord: chord,
                     pinchZoom: pinchZoom, rotate: rotate, spotlightToggle: spotlightToggle, spotlightHold: spotlightHold,
                     windowShot: windowShotKey)
    }

    var spotlight: SpotlightSettings {
        SpotlightSettings(on: spotlightOn, style: spotlightStyle, size: spotlightSize, dim: spotlightDim,
                          softness: spotlightSoftness, dimColor: spotlightColor, ringColor: ringColor, pulse: spotlightPulse,
                          hiddenDisplays: spotlightHiddenDisplays)
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
        defaults.set(spotlightOn, forKey: "spotlightOn")
        defaults.set(spotlightStyle.rawValue, forKey: "spotlightStyle")
        defaults.set(spotlightSize, forKey: "spotlightSize")
        defaults.set(spotlightDim, forKey: "spotlightDim")
        defaults.set(spotlightSoftness, forKey: "spotlightSoftness")
        defaults.set(try? NSKeyedArchiver.archivedData(withRootObject: spotlightColor, requiringSecureCoding: true),
                     forKey: "spotlightColor")
        defaults.set(try? NSKeyedArchiver.archivedData(withRootObject: ringColor, requiringSecureCoding: true), forKey: "ringColor")
        defaults.set(spotlightPulse, forKey: "spotlightPulse")
        defaults.set(spotlightHiddenDisplays.sorted(), forKey: "spotlightHiddenDisplays")
        defaults.set(trigger.flatMap { try? JSONEncoder().encode($0) }, forKey: "trigger")
        defaults.set(spotlightToggle.flatMap { try? JSONEncoder().encode($0) }, forKey: "spotlightToggle")
        defaults.set(spotlightHold.flatMap { try? JSONEncoder().encode($0) }, forKey: "spotlightHold")
        defaults.set(windowShotKey.flatMap { try? JSONEncoder().encode($0) }, forKey: "windowShotKey")
        Engine.shared.apply(config)
        Spotlight.shared.apply(spotlight)
    }

    private static func key(_ data: Data?) -> KeyTrigger? {
        data.flatMap { try? JSONDecoder().decode(KeyTrigger.self, from: $0) }
    }

    private static func color(_ data: Data?) -> NSColor? {
        data.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: $0) }
    }

    func showAction(_ text: String) {
        lastAction = text
        lastActionID += 1
    }

    func startRecording(_ role: KeyRole) {
        if recording != nil { Engine.shared.cancelRecording() }
        recording = role
        Engine.shared.startRecording { [weak self] trigger in
            guard let self else { return }
            recording = nil
            guard let trigger else { return }
            // A key that already does something else stops doing it.
            for other in KeyRole.allCases where other != role && self[keyPath: other.keyPath] == trigger {
                self[keyPath: other.keyPath] = nil
            }
            self[keyPath: role.keyPath] = trigger
        }
    }

    func cancelRecording() {
        Engine.shared.cancelRecording()
        recording = nil
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
