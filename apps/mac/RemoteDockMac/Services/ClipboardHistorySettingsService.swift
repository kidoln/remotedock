import Carbon
import AppKit
import Foundation

struct ClipboardHistorySettings: Equatable {
    var maxItems: Int
    var shortcut: ClipboardHistoryShortcut

    static let defaultMaxItems = 100
    static let maxAllowedItems = 200

    static let `default` = ClipboardHistorySettings(
        maxItems: defaultMaxItems,
        shortcut: .default
    )
}

struct ClipboardHistoryShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = ClipboardHistoryShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
    )

    var displayText: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Command")
        }
        parts.append(Self.keyDisplayName(for: keyCode))
        return parts.joined(separator: " + ")
    }

    static func fromEvent(_ event: NSEvent) -> ClipboardHistoryShortcut? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            return nil
        }

        return ClipboardHistoryShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        return modifiers
    }

    private static func keyDisplayName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_Equal: "="
        case kVK_ANSI_9: "9"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_Minus: "-"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_RightBracket: "]"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_LeftBracket: "["
        case kVK_ANSI_I: "I"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_Quote: "'"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_Semicolon: ";"
        case kVK_ANSI_Backslash: "\\"
        case kVK_ANSI_Comma: ","
        case kVK_ANSI_Slash: "/"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_Period: "."
        case kVK_ANSI_Grave: "`"
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Escape: "Escape"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "Forward Delete"
        case kVK_Home: "Home"
        case kVK_End: "End"
        case kVK_PageUp: "Page Up"
        case kVK_PageDown: "Page Down"
        case kVK_LeftArrow: "Left Arrow"
        case kVK_RightArrow: "Right Arrow"
        case kVK_DownArrow: "Down Arrow"
        case kVK_UpArrow: "Up Arrow"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: "Key \(keyCode)"
        }
    }
}

final class ClipboardHistorySettingsService {
    private let maxItemsKey = "remoteDock.clipboardHistory.maxItems.v1"
    private let shortcutKey = "remoteDock.clipboardHistory.shortcut.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ClipboardHistorySettings {
        ClipboardHistorySettings(
            maxItems: loadMaxItems(),
            shortcut: loadShortcut()
        )
    }

    func saveMaxItems(_ maxItems: Int) {
        defaults.set(Self.clampedMaxItems(maxItems), forKey: maxItemsKey)
    }

    func saveShortcut(_ shortcut: ClipboardHistoryShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }
        defaults.set(data, forKey: shortcutKey)
    }

    private func loadMaxItems() -> Int {
        guard defaults.object(forKey: maxItemsKey) != nil else {
            return ClipboardHistorySettings.defaultMaxItems
        }
        return Self.clampedMaxItems(defaults.integer(forKey: maxItemsKey))
    }

    private func loadShortcut() -> ClipboardHistoryShortcut {
        guard let data = defaults.data(forKey: shortcutKey),
              let shortcut = try? JSONDecoder().decode(ClipboardHistoryShortcut.self, from: data) else {
            return .default
        }
        return shortcut
    }

    private static func clampedMaxItems(_ value: Int) -> Int {
        min(max(value, 1), ClipboardHistorySettings.maxAllowedItems)
    }
}
