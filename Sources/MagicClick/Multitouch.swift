import Foundation
import IOKit

// Layout of one contact as reported by the private MultitouchSupport framework.
// It must stay exactly 96 bytes; `Multitouch.start()` checks this.
struct MTPoint { var x: Float; var y: Float }
struct MTVector { var position: MTPoint; var velocity: MTPoint }
struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTVector
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTVector
    var zero2: Int32
    var zero3: Int32
    var density: Float
}

/// A finger that is touching the surface. `x` goes 0 (left) to 1 (right), `y` 0 (bottom) to 1 (top).
struct Touch: Equatable {
    let id: Int32
    let x: Float
    let y: Float
}

typealias MTDeviceRef = UnsafeMutableRawPointer
private typealias MTFrameCallback = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
private typealias MTCreateListFn = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterFn = @convention(c) (MTDeviceRef, MTFrameCallback) -> Void
private typealias MTStartFn = @convention(c) (MTDeviceRef, Int32) -> Int32
private typealias MTStopFn = @convention(c) (MTDeviceRef) -> Int32
private typealias MTBoolFn = @convention(c) (MTDeviceRef) -> Bool
private typealias MTFamilyFn = @convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> Int32
private typealias MTDimsFn = @convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32

private let mtLibrary = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)

private func mtSymbol<T>(_ name: String, as type: T.Type) -> T? {
    guard let mtLibrary, let pointer = dlsym(mtLibrary, name) else { return nil }
    return unsafeBitCast(pointer, to: type)
}

private let mtCreateList = mtSymbol("MTDeviceCreateList", as: MTCreateListFn.self)
private let mtRegister = mtSymbol("MTRegisterContactFrameCallback", as: MTRegisterFn.self)
private let mtUnregister = mtSymbol("MTUnregisterContactFrameCallback", as: MTRegisterFn.self)
private let mtStart = mtSymbol("MTDeviceStart", as: MTStartFn.self)
private let mtStop = mtSymbol("MTDeviceStop", as: MTStopFn.self)
private let mtIsBuiltIn = mtSymbol("MTDeviceIsBuiltIn", as: MTBoolFn.self)
private let mtFamily = mtSymbol("MTDeviceGetFamilyID", as: MTFamilyFn.self)
private let mtDimensions = mtSymbol("MTDeviceGetSensorSurfaceDimensions", as: MTDimsFn.self)

// Contact states 3 (make touch) and 4 (touching) mean the finger is on the surface.
private let frameCallback: MTFrameCallback = { device, contacts, count, _, _ in
    guard let device else { return 0 }
    var touches: [Touch] = []
    if let contacts, count > 0 {
        let list = contacts.bindMemory(to: MTContact.self, capacity: Int(count))
        for index in 0..<Int(count) {
            let contact = list[index]
            if contact.state == 3 || contact.state == 4 {
                touches.append(Touch(id: contact.identifier, x: contact.normalized.position.x, y: contact.normalized.position.y))
            }
        }
    }
    Multitouch.shared.deliver(device: device, touches: touches)
    return 0
}

/// Reads raw finger positions from the Magic Mouse and trackpads.
final class Multitouch {
    static let shared = Multitouch()

    /// Called on the multitouch thread for every frame.
    var onFrame: ((_ device: MTDeviceRef, _ isMouse: Bool, _ touches: [Touch]) -> Void)?
    /// Called on the main thread when the set of devices changes.
    var onDevicesChanged: ((_ mouseConnected: Bool) -> Void)?

    private let lock = NSLock()
    private var devices: [MTDeviceRef] = []
    private var mouseDevices: Set<MTDeviceRef> = []
    // Old device lists are kept alive so a late callback never touches freed memory.
    private var retiredLists: [CFArray] = []
    private var currentList: CFArray?
    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var restartWork: DispatchWorkItem?

    var isAvailable: Bool { mtCreateList != nil && mtRegister != nil && mtStart != nil }

    func deliver(device: MTDeviceRef, touches: [Touch]) {
        let isMouse = lock.withLock { mouseDevices.contains(device) }
        onFrame?(device, isMouse, touches)
    }

    func start() {
        precondition(MemoryLayout<MTContact>.stride == 96, "MTContact layout changed")
        guard isAvailable, let mtCreateList, let mtRegister, let mtStart else { return }
        guard let list = mtCreateList()?.takeRetainedValue() else { return }
        currentList = list

        var found: [MTDeviceRef] = []
        var mice: Set<MTDeviceRef> = []
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            found.append(device)
            if Self.isMouse(device) { mice.insert(device) }
        }
        lock.withLock {
            devices = found
            mouseDevices = mice
        }
        for device in found {
            mtRegister(device, frameCallback)
            _ = mtStart(device, 0)
        }
        onDevicesChanged?(!mice.isEmpty)
        watchForDeviceChanges()
    }

    func stop() {
        let old = lock.withLock { () -> [MTDeviceRef] in
            let old = devices
            devices = []
            mouseDevices = []
            return old
        }
        for device in old {
            mtUnregister?(device, frameCallback)
            _ = mtStop?(device)
        }
        if let currentList { retiredLists.append(currentList) }
        currentList = nil
    }

    /// Restarts after a short pause, so a burst of device events causes one restart.
    func scheduleRestart(after delay: TimeInterval = 1.0) {
        restartWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.stop()
            self?.start()
        }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // Magic Mouse family IDs are 112 and 113. Unknown external devices that are taller
    // than wide are treated as mice too.
    private static func isMouse(_ device: MTDeviceRef) -> Bool {
        var family: Int32 = 0
        _ = mtFamily?(device, &family)
        if family == 112 || family == 113 { return true }
        if mtIsBuiltIn?(device) == true { return false }
        var width: Int32 = 0, height: Int32 = 0
        _ = mtDimensions?(device, &width, &height)
        return height > width && width > 0
    }

    private func watchForDeviceChanges() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        let callback: IOServiceMatchingCallback = { _, iterator in
            while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
            Multitouch.shared.scheduleRestart()
        }
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(port, type, IOServiceMatching("AppleMultitouchDevice"), callback, nil, &iterator)
            guard result == KERN_SUCCESS else { continue }
            // Drain once to arm the notification; existing devices are already started.
            while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
            iterators.append(iterator)
        }
    }
}
