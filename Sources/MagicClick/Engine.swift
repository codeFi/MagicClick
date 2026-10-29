import AppKit
import CoreGraphics

/// What the user turned on in the settings window.
struct EngineConfig: Equatable {
    var enabled = true
    var fingerClick = true
    var fingerCount = 3
    var fingerTap = false
    var includeTrackpad = false
    var trigger: KeyTrigger?
    /// 0 is off. Otherwise the zero-based button number of an extra mouse button (3 is "button 4").
    var extraButton = 0
    var chord = true
    var pinchZoom = true
    var rotate = true
}

/// A two-finger gesture that MagicClick sends as a trackpad gesture.
enum GestureKind { case zoom, rotate }

/// What the live view in the settings window draws.
struct LiveSnapshot: Equatable {
    var touches: [Touch] = []
    var rightHeld = false
    var chordActive = false
    var gesture: GestureKind?
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
    guard let result = Engine.shared.handle(type, event) else { return nil }
    return Unmanaged.passUnretained(result)
}

/// Turns finger touches and key presses into middle clicks, and touches on the left
/// half into left clicks while the right button is held.
///
/// The event tap runs on the main thread. Multitouch frames arrive on a private
/// thread. Everything both sides read is guarded by `lock`.
final class Engine {
    static let shared = Engine()
    /// Marks the events we post, so our own tap lets them through untouched.
    static let marker: Int64 = 0x4D43_4C4B

    /// Called on the main thread with a short description of each action.
    var onAction: ((String) -> Void)?
    /// Called on the main thread about 30 times a second while live updates are on.
    var onLive: ((LiveSnapshot) -> Void)?
    /// Non-nil while the settings window waits for a key. Called on the main thread.
    private(set) var recorder: ((KeyTrigger?) -> Void)?

    private let lock = NSLock()
    private var config = EngineConfig()
    private var liveEnabled = false
    private var lastLiveSend: TimeInterval = 0
    private var deviceTouches: [MTDeviceRef: [Touch]] = [:]
    private var deviceIsMouse: [MTDeviceRef: Bool] = [:]
    private var rightHeld = false
    private var rightBaseline: Set<Int32> = []
    private var chordFinger: Int32?
    private var gestures: [MTDeviceRef: Gesture] = [:]
    private var pinch: Pinch?
    /// Until this time, scroll momentum left over from a pinch is dropped.
    private var swallowScrollUntil: TimeInterval = 0

    // Main thread only.
    private var tap: CFMachPort?
    private var convertedButton: CGMouseButton?
    private var keyMiddleDown = false
    private var recordModifier: Int?
    private var swallowKeyUp: Int?

    private let source = CGEventSource(stateID: .hidSystemState)
    private let clicks = ClickCounter()

    private struct Gesture {
        var start: TimeInterval
        var maxCount = 0
        var origins: [Int32: (x: Float, y: Float)] = [:]
        var moved = false
        var clicked = false
    }

    /// Two fingers on the mouse that may become a zoom or a rotation.
    private struct Pinch {
        let ids: [Int32]
        var origins: [Int32: (x: Float, y: Float)]
        var startDistance: Float
        var lastDistance: Float
        var startAngle: Float
        var lastAngle: Float
        /// Nil until the fingers move enough. Then it stays the same until a finger lifts.
        var kind: GestureKind?
        /// Set when the fingers slide the same way or a button is down. Then it never becomes a gesture.
        var blocked = false
        var active: Bool { kind != nil }
    }

    // Private CGEvent fields for trackpad gestures, as the trackpad driver sends them.
    private static let gestureEventType = CGEventType(rawValue: 29)
    private static let gestureHIDTypeField = CGEventField(rawValue: 110)
    private static let gestureZoomField = CGEventField(rawValue: 113)
    private static let gestureRotationField = CGEventField(rawValue: 114)
    private static let gesturePhaseField = CGEventField(rawValue: 132)
    private static let hidZoomType: Int64 = 8
    private static let hidRotationType: Int64 = 5
    private enum GesturePhase: Int64 { case began = 1, changed = 2, ended = 4 }
    /// How much the fingers must move apart or together before the zoom starts.
    private static let pinchThreshold: Float = 0.06
    /// Converts the change in finger distance to the zoom amount macOS expects.
    private static let pinchGain = 1.5
    /// How far the fingers must turn, in degrees, before the rotation starts.
    private static let rotateThreshold: Float = 15
    /// How far each finger must travel along the turn, so close fingers that wiggle do not rotate.
    private static let rotateTravel: Float = 0.05

    var isTapRunning: Bool { tap != nil }

    // MARK: Setup

    func apply(_ newConfig: EngineConfig) {
        let old = lock.withLock { () -> EngineConfig in
            let old = config
            config = newConfig
            return old
        }
        if keyMiddleDown, !newConfig.enabled || newConfig.trigger != old.trigger {
            pressMiddle(false, trigger: old.trigger)
        }
    }

    func setLiveUpdates(_ on: Bool) {
        lock.withLock { liveEnabled = on }
    }

    /// Creates the event tap. Fails until the app has Accessibility permission.
    @discardableResult
    func startTap() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .mouseMoved, .scrollWheel, .keyDown, .keyUp, .flagsChanged,
        ]
        var mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        mask |= 1 << 14 // NSEventTypeSystemDefined: media and special keys
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: mask, callback: eventTapCallback, userInfo: nil) else {
            return false
        }
        tap = port
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    // MARK: Key recording

    func startRecording(_ completion: @escaping (KeyTrigger?) -> Void) {
        recordModifier = nil
        recorder = completion
    }

    func cancelRecording() {
        finishRecording(nil)
    }

    private func finishRecording(_ trigger: KeyTrigger?) {
        let completion = recorder
        recorder = nil
        recordModifier = nil
        completion?(trigger)
    }

    /// Returns true to swallow the event, false to pass it on, nil when recording does not care.
    private func record(_ type: CGEventType, _ event: CGEvent) -> Bool? {
        switch type {
        case .keyDown:
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return true }
            let code = Self.keyCode(event)
            if code == 53, event.flags.intersection(KeyTrigger.modifierMask).isEmpty {
                finishRecording(nil)
            } else {
                finishRecording(.key(code: code, flags: event.flags))
            }
            swallowKeyUp = code
            return true
        case .keyUp:
            return true
        case .flagsChanged:
            let code = Self.keyCode(event)
            guard let bit = KeyTrigger.modifierBits[code] else { return true }
            if event.flags.rawValue & bit != 0 {
                recordModifier = code
            } else if recordModifier == code {
                // Released without another key: the modifier on its own is the trigger.
                finishRecording(.modifier(code: code))
            }
            return true
        default:
            guard type.rawValue == 14, let media = Self.mediaKey(event) else { return nil }
            if media.down { finishRecording(.media(code: media.code)) }
            return true
        }
    }

    // MARK: Event tap

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return event
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return event }
        if recorder != nil, let swallow = record(type, event) { return swallow ? nil : event }
        if type == .keyUp, let code = swallowKeyUp, code == Self.keyCode(event) {
            swallowKeyUp = nil
            return nil
        }

        let config = lock.withLock { self.config }
        guard config.enabled else { return event }

        switch type {
        case .leftMouseDown, .rightMouseDown:
            return mouseDown(type, event, config)
        case .leftMouseDragged, .rightMouseDragged:
            if convertedButton == Self.button(of: type) { convert(event, to: .otherMouseDragged) }
            return event
        case .leftMouseUp, .rightMouseUp:
            if convertedButton == Self.button(of: type) {
                convertedButton = nil
                convert(event, to: .otherMouseUp)
            } else if type == .rightMouseUp {
                lock.withLock { rightHeld = false }
            }
            return event
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            if config.extraButton > 0, event.getIntegerValueField(.mouseEventButtonNumber) == Int64(config.extraButton) {
                event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            }
            return event
        case .mouseMoved:
            // While a key holds the middle button, moving the mouse is a middle drag.
            if keyMiddleDown {
                convert(event, to: .otherMouseDragged)
                event.flags = event.flags.subtracting(Self.hiddenFlags(config.trigger))
            }
            return event
        case .scrollWheel:
            return scrollEvent(event)
        case .keyDown, .keyUp, .flagsChanged:
            return keyEvent(type, event, config)
        default:
            return type.rawValue == 14 ? mediaEvent(event, config) : event
        }
    }

    private func mouseDown(_ type: CGEventType, _ event: CGEvent, _ config: EngineConfig) -> CGEvent? {
        let fingers = lock.withLock { () -> Int in
            for device in gestures.keys { gestures[device]?.clicked = true }
            return middleFingerCount(config)
        }
        if config.fingerClick, fingers >= config.fingerCount {
            convertedButton = Self.button(of: type)
            convert(event, to: .otherMouseDown)
            report("Middle click · \(fingers) fingers")
            return event
        }
        if type == .rightMouseDown {
            lock.withLock {
                rightHeld = true
                rightBaseline = Set(mouseTouches().map(\.id))
            }
        }
        return event
    }

    /// Drops the mouse's own scrolling while a pinch runs, and the momentum after it.
    private func scrollEvent(_ event: CGEvent) -> CGEvent? {
        lock.withLock {
            if pinch?.active == true { return nil }
            guard ProcessInfo.processInfo.systemUptime < swallowScrollUntil else { return event }
            // A new scroll that starts after the pinch is the user's, so let it through.
            if event.getIntegerValueField(.scrollWheelEventScrollPhase) == 1 {
                swallowScrollUntil = 0
                return event
            }
            return nil
        }
    }

    private func keyEvent(_ type: CGEventType, _ event: CGEvent, _ config: EngineConfig) -> CGEvent? {
        guard let trigger = config.trigger else { return event }
        let code = Self.keyCode(event)
        guard code == trigger.code else { return event }
        switch (type, trigger.kind) {
        case (.keyDown, .key):
            guard event.flags.intersection(KeyTrigger.modifierMask).rawValue == trigger.modifiers else { return event }
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { pressMiddle(true, trigger: trigger) }
            return nil
        case (.keyUp, .key) where keyMiddleDown:
            pressMiddle(false, trigger: trigger)
            return nil
        case (.flagsChanged, .modifier):
            guard let bit = KeyTrigger.modifierBits[code] else { return event }
            pressMiddle(event.flags.rawValue & bit != 0, trigger: trigger)
            return nil
        default:
            return event
        }
    }

    private func mediaEvent(_ event: CGEvent, _ config: EngineConfig) -> CGEvent? {
        guard let trigger = config.trigger, trigger.kind == .media,
              let media = Self.mediaKey(event), media.code == trigger.code else { return event }
        pressMiddle(media.down, trigger: trigger)
        return nil
    }

    private func pressMiddle(_ down: Bool, trigger: KeyTrigger?) {
        guard down != keyMiddleDown else { return }
        keyMiddleDown = down
        post(down ? .otherMouseDown : .otherMouseUp, button: .center, hiding: Self.hiddenFlags(trigger))
        if down, let trigger { report("Middle click · \(trigger.name)") }
    }

    // MARK: Multitouch

    func handleFrame(device: MTDeviceRef, isMouse: Bool, touches: [Touch]) {
        var actions: [() -> Void] = []
        var live: LiveSnapshot?
        let now = ProcessInfo.processInfo.systemUptime

        lock.withLock {
            deviceTouches[device] = touches
            deviceIsMouse[device] = isMouse
            let config = self.config

            if config.enabled, isMouse {
                // Left click while the right button is held: a new finger on the left half.
                if let id = chordFinger, !touches.contains(where: { $0.id == id }) {
                    chordFinger = nil
                    actions.append { self.post(.leftMouseUp, button: .left) }
                }
                if config.chord, rightHeld, chordFinger == nil {
                    for touch in touches where !rightBaseline.contains(touch.id) {
                        if touch.x < 0.5 {
                            chordFinger = touch.id
                            actions.append {
                                self.post(.leftMouseDown, button: .left)
                                self.report("Left click · while right is held")
                            }
                            break
                        }
                        // A finger that lands on the right half never counts, even if it slides left.
                        rightBaseline.insert(touch.id)
                    }
                }
            }

            if isMouse {
                if config.enabled, config.pinchZoom || config.rotate {
                    trackPinch(touches: touches, now: now, config: config, actions: &actions)
                } else {
                    endPinch(now: now, actions: &actions)
                }
            }

            if config.enabled, config.fingerTap, isMouse || config.includeTrackpad {
                trackTap(device: device, touches: touches, now: now, config: config, actions: &actions)
            }

            if liveEnabled, isMouse, now - lastLiveSend > 1.0 / 30 || touches.isEmpty {
                lastLiveSend = now
                live = LiveSnapshot(touches: touches, rightHeld: rightHeld, chordActive: chordFinger != nil,
                                    gesture: pinch?.kind)
            }
        }

        actions.forEach { $0() }
        if let live {
            DispatchQueue.main.async { self.onLive?(live) }
        }
    }

    /// A quick tap with exactly the chosen number of fingers, without pressing, is a middle click.
    private func trackTap(device: MTDeviceRef, touches: [Touch], now: TimeInterval, config: EngineConfig,
                          actions: inout [() -> Void]) {
        guard !touches.isEmpty else {
            if let gesture = gestures.removeValue(forKey: device), gesture.maxCount == config.fingerCount,
               !gesture.moved, !gesture.clicked, !rightHeld, now - gesture.start < 0.3 {
                actions.append {
                    self.post(.otherMouseDown, button: .center)
                    self.post(.otherMouseUp, button: .center)
                    self.report("Middle click · \(config.fingerCount)-finger tap")
                }
            }
            return
        }
        var gesture = gestures[device] ?? Gesture(start: now)
        gesture.maxCount = max(gesture.maxCount, touches.count)
        for touch in touches {
            if let origin = gesture.origins[touch.id] {
                if hypot(touch.x - origin.x, touch.y - origin.y) > 0.05 { gesture.moved = true }
            } else {
                gesture.origins[touch.id] = (touch.x, touch.y)
            }
        }
        gestures[device] = gesture
    }

    /// Two fingers that move apart or together zoom, and two fingers that turn rotate,
    /// like the same gestures on the trackpad.
    private func trackPinch(touches: [Touch], now: TimeInterval, config: EngineConfig, actions: inout [() -> Void]) {
        let ids = touches.map(\.id).sorted()
        guard touches.count == 2, !rightHeld, chordFinger == nil else {
            endPinch(now: now, actions: &actions)
            return
        }
        if pinch?.ids != ids { endPinch(now: now, actions: &actions) }
        // Ordered by finger ID, so the angle does not jump when the fingers cross.
        let pair = touches.sorted { $0.id < $1.id }
        let distance = hypot(pair[0].x - pair[1].x, pair[0].y - pair[1].y)
        let angle = atan2(pair[1].y - pair[0].y, pair[1].x - pair[0].x) * 180 / .pi
        guard var current = pinch else {
            let buttonDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
                || CGEventSource.buttonState(.combinedSessionState, button: .right)
            pinch = Pinch(ids: ids, origins: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, ($0.x, $0.y)) }),
                          startDistance: distance, lastDistance: distance, startAngle: angle, lastAngle: angle,
                          blocked: buttonDown)
            return
        }
        defer { pinch = current }

        guard let kind = current.kind else {
            guard !current.blocked else { return }
            let turned = abs(Self.angleDifference(angle, current.startAngle))
            let zooms = config.pinchZoom && abs(distance - current.startDistance) > Self.pinchThreshold
            let rotates = config.rotate && turned > Self.rotateThreshold
                && turned * .pi / 180 * distance / 2 > Self.rotateTravel
            guard zooms || rotates else { return }
            // Both fingers sliding the same way is a scroll or a swipe, not a gesture.
            let moves = touches.map { touch -> (x: Float, y: Float) in
                let origin = current.origins[touch.id] ?? (touch.x, touch.y)
                return (touch.x - origin.x, touch.y - origin.y)
            }
            let lengths = moves.map { hypot($0.x, $0.y) }
            if lengths.allSatisfy({ $0 > 0.02 }),
               (moves[0].x * moves[1].x + moves[0].y * moves[1].y) / (lengths[0] * lengths[1]) > 0.5 {
                current.blocked = true
                return
            }
            let started: GestureKind = zooms ? .zoom : .rotate
            current.kind = started
            current.lastDistance = distance
            current.lastAngle = angle
            actions.append {
                self.postGesture(started, .began, 0)
                self.report(started == .zoom ? "Pinch to zoom" : "Rotate")
            }
            return
        }

        switch kind {
        case .zoom:
            let amount = Double(distance / current.lastDistance - 1) * Self.pinchGain
            guard abs(amount) > 0.002 else { return }
            current.lastDistance = distance
            actions.append { self.postGesture(.zoom, .changed, amount) }
        case .rotate:
            let degrees = Double(Self.angleDifference(angle, current.lastAngle))
            guard abs(degrees) > 0.2 else { return }
            current.lastAngle = angle
            actions.append { self.postGesture(.rotate, .changed, degrees) }
        }
    }

    // Call with `lock` held.
    private func endPinch(now: TimeInterval, actions: inout [() -> Void]) {
        guard let current = pinch else { return }
        pinch = nil
        if let kind = current.kind {
            swallowScrollUntil = now + 2
            actions.append { self.postGesture(kind, .ended, 0) }
        }
    }

    /// The shortest turn from `b` to `a`, in degrees from -180 to 180.
    private static func angleDifference(_ a: Float, _ b: Float) -> Float {
        var difference = a - b
        while difference > 180 { difference -= 360 }
        while difference < -180 { difference += 360 }
        return difference
    }

    // Call with `lock` held.
    private func mouseTouches() -> [Touch] {
        deviceTouches.filter { deviceIsMouse[$0.key] == true }.flatMap(\.value)
    }

    // Call with `lock` held.
    private func middleFingerCount(_ config: EngineConfig) -> Int {
        deviceTouches
            .filter { deviceIsMouse[$0.key] == true || config.includeTrackpad }
            .map(\.value.count)
            .max() ?? 0
    }

    // MARK: Helpers

    private func convert(_ event: CGEvent, to type: CGEventType) {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
    }

    private func post(_ type: CGEventType, button: CGMouseButton, hiding: CGEventFlags = []) {
        let location = CGEvent(source: nil)?.location ?? .zero
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: button) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.setIntegerValueField(.mouseEventClickState, value: clicks.state(for: type, button: button, at: location))
        if !hiding.isEmpty { event.flags = event.flags.subtracting(hiding) }
        event.post(tap: .cghidEventTap)
    }

    /// Sends a zoom or rotate gesture at the pointer, the same event a trackpad makes.
    /// A zoom amount is a change in scale. A rotation is in degrees, counterclockwise is positive.
    private func postGesture(_ kind: GestureKind, _ phase: GesturePhase, _ value: Double) {
        guard let type = Self.gestureEventType, let hidType = Self.gestureHIDTypeField,
              let valueField = kind == .zoom ? Self.gestureZoomField : Self.gestureRotationField,
              let phaseField = Self.gesturePhaseField, let event = CGEvent(source: nil) else { return }
        event.type = type
        event.location = CGEvent(source: nil)?.location ?? .zero
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.setIntegerValueField(hidType, value: kind == .zoom ? Self.hidZoomType : Self.hidRotationType)
        event.setDoubleValueField(valueField, value: value)
        event.setIntegerValueField(phaseField, value: phase.rawValue)
        event.post(tap: .cghidEventTap)
    }

    private func report(_ text: String) {
        DispatchQueue.main.async { self.onAction?(text) }
    }

    private static func button(of type: CGEventType) -> CGMouseButton {
        switch type {
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged: return .right
        default: return .left
        }
    }

    private static func keyCode(_ event: CGEvent) -> Int {
        Int(event.getIntegerValueField(.keyboardEventKeycode))
    }

    /// Modifier flags that belong to the trigger itself, so the click we send does not carry them.
    private static func hiddenFlags(_ trigger: KeyTrigger?) -> CGEventFlags {
        guard let trigger else { return [] }
        switch trigger.kind {
        case .key: return CGEventFlags(rawValue: trigger.modifiers)
        case .modifier: return KeyTrigger.modifierFlags[trigger.code] ?? []
        case .media: return []
        }
    }

    /// Decodes a media or special key from a system-defined event (subtype 8).
    private static func mediaKey(_ event: CGEvent) -> (code: Int, down: Bool)? {
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else { return nil }
        let data = nsEvent.data1
        let state = (data & 0xFF00) >> 8
        guard state == 0xA || state == 0xB else { return nil }
        return ((data & 0xFFFF_0000) >> 16, state == 0xA)
    }
}

/// Counts repeated clicks so the clicks we send can be double and triple clicks.
private final class ClickCounter {
    private let lock = NSLock()
    private let interval = NSEvent.doubleClickInterval
    private var last: [UInt32: (time: TimeInterval, location: CGPoint, count: Int64)] = [:]

    func state(for type: CGEventType, button: CGMouseButton, at location: CGPoint) -> Int64 {
        lock.withLock {
            let key = button.rawValue
            guard [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) else {
                return last[key]?.count ?? 1
            }
            let now = ProcessInfo.processInfo.systemUptime
            var count: Int64 = 1
            if let previous = last[key], now - previous.time < interval,
               hypot(previous.location.x - location.x, previous.location.y - location.y) < 5 {
                count = previous.count + 1
            }
            last[key] = (now, location, count)
            return count
        }
    }
}
