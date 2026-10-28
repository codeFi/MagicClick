import Carbon
import CoreGraphics

/// A keyboard key that acts as the middle mouse button.
struct KeyTrigger: Codable, Equatable {
    enum Kind: String, Codable {
        /// A normal key, optionally with modifiers (for example F13 or ⌥F5).
        case key
        /// A modifier key pressed on its own (for example Right ⌥ Option or fn).
        case modifier
        /// A media or special key (for example Play/Pause or Volume Up).
        case media
    }

    var kind: Kind
    var code: Int
    var modifiers: UInt64
    var name: String

    static let modifierMask: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

    static func key(code: Int, flags: CGEventFlags) -> KeyTrigger {
        let mods = flags.intersection(modifierMask)
        return KeyTrigger(kind: .key, code: code, modifiers: mods.rawValue, name: symbols(for: mods) + keyName(code))
    }

    static func modifier(code: Int) -> KeyTrigger {
        KeyTrigger(kind: .modifier, code: code, modifiers: 0, name: modifierNames[code] ?? "Modifier \(code)")
    }

    static func media(code: Int) -> KeyTrigger {
        KeyTrigger(kind: .media, code: code, modifiers: 0, name: mediaNames[code] ?? "Special key \(code)")
    }

    // Device-dependent flag bits tell left and right modifiers apart.
    static let modifierBits: [Int: UInt64] = [
        59: 0x0000_0001, // left control
        56: 0x0000_0002, // left shift
        60: 0x0000_0004, // right shift
        55: 0x0000_0008, // left command
        54: 0x0000_0010, // right command
        58: 0x0000_0020, // left option
        61: 0x0000_0040, // right option
        62: 0x0000_2000, // right control
        63: CGEventFlags.maskSecondaryFn.rawValue,
    ]

    /// The generic flag a modifier key sets, used to hide it from the clicks we send.
    static let modifierFlags: [Int: CGEventFlags] = [
        59: .maskControl, 62: .maskControl,
        56: .maskShift, 60: .maskShift,
        55: .maskCommand, 54: .maskCommand,
        58: .maskAlternate, 61: .maskAlternate,
        63: .maskSecondaryFn,
    ]

    static let modifierNames: [Int: String] = [
        59: "Left ⌃ Control", 62: "Right ⌃ Control",
        56: "Left ⇧ Shift", 60: "Right ⇧ Shift",
        55: "Left ⌘ Command", 54: "Right ⌘ Command",
        58: "Left ⌥ Option", 61: "Right ⌥ Option",
        63: "fn / 🌐 Globe",
    ]

    static let mediaNames: [Int: String] = [
        0: "Volume Up", 1: "Volume Down", 2: "Brightness Up", 3: "Brightness Down",
        5: "Help", 7: "Mute", 10: "Eject", 16: "Play/Pause", 17: "Next Track",
        18: "Previous Track", 19: "Fast Forward", 20: "Rewind",
        21: "Keyboard Light Up", 22: "Keyboard Light Down", 23: "Keyboard Light Toggle",
    ]

    private static let specialKeyNames: [Int: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "Forward Delete",
        115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑", 114: "Help", 76: "Enter", 71: "Clear",
        160: "Mission Control", 131: "Launchpad", 177: "Spotlight", 176: "Dictation",
        178: "Do Not Disturb", 179: "🌐 Globe",
    ]

    private static func symbols(for flags: CGEventFlags) -> String {
        var text = ""
        if flags.contains(.maskControl) { text += "⌃" }
        if flags.contains(.maskAlternate) { text += "⌥" }
        if flags.contains(.maskShift) { text += "⇧" }
        if flags.contains(.maskCommand) { text += "⌘" }
        return text
    }

    private static func keyName(_ code: Int) -> String {
        if let name = specialKeyNames[code] { return name }
        if let char = typedCharacter(code), !char.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return char.uppercased()
        }
        return "Key \(code)"
    }

    /// Asks the current keyboard layout which character a key code types.
    private static func typedCharacter(_ code: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
