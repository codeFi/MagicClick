import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Saves the window under the pointer with the spotlight on top, as you see it.
/// A one-window macOS screenshot holds only that window, so it can never show the spotlight.
enum WindowShot {
    /// Called on the main thread with a short message for the live view.
    static var onResult: ((String) -> Void)?

    private struct Failure: Error {}

    /// Main thread only.
    static func capture() {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            onResult?("Allow Screen Recording for MagicClick, then quit and open it again")
            return
        }
        let pointer = CGEvent(source: nil)?.location ?? .zero
        guard let target = windowID(at: pointer) else {
            onResult?("No window under the pointer")
            return
        }
        let spotlight = Spotlight.shared.windowNumbers
        Task { @MainActor in
            do {
                let url = try await save(target, spotlight: spotlight, pointer: pointer)
                NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
                        byReference: true)?.play()
                onResult?("Window screenshot · \(url.deletingPathExtension().lastPathComponent)")
            } catch {
                NSLog("MagicClick: window screenshot failed: \(error)")
                onResult?("Window screenshot failed")
            }
        }
    }

    /// The front window under `point` that is not MagicClick's. `point` is in event coordinates.
    private static func windowID(at point: CGPoint) -> CGWindowID? {
        let me = getpid()
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0, (info[kCGWindowOwnerPID as String] as? pid_t) != me,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo), bounds.contains(point),
                  let number = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            return number
        }
        return nil
    }

    /// Draws only the window and the spotlight windows, cut to the window's frame, without the cursor.
    @MainActor
    private static func save(_ target: CGWindowID, spotlight: [CGWindowID], pointer: CGPoint) async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == target }),
              let display = content.displays.first(where: { $0.frame.contains(pointer) }) else { throw Failure() }
        let filter = SCContentFilter(display: display,
                                     including: [window] + content.windows.filter { spotlight.contains($0.windowID) })
        let rect = window.frame.intersection(display.frame)
        guard !rect.isEmpty else { throw Failure() }
        let config = SCStreamConfiguration()
        config.sourceRect = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        config.width = Int((rect.width * CGFloat(filter.pointPixelScale)).rounded())
        config.height = Int((rect.height * CGFloat(filter.pointPixelScale)).rounded())
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = folder().appendingPathComponent("MagicClick Screenshot \(formatter.string(from: Date())).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure()
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure() }
        return url
    }

    /// Where macOS saves screenshots: the folder set in ⌘⇧5 → Options, or the Desktop.
    private static func folder() -> URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
}
