import CoreGraphics
import Foundation

/// Synthesizes keyboard events from action strings like "Cmd+Z".
enum KeySynth {

    // MARK: - Virtual Keycode Table

    /// Map of key names to macOS virtual keycodes.
    private static let keyCodes: [String: UInt16] = [
        // Letters
        "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "H": 0x04,
        "G": 0x05, "Z": 0x06, "X": 0x07, "C": 0x08, "V": 0x09,
        "B": 0x0B, "Q": 0x0C, "W": 0x0D, "E": 0x0E, "R": 0x0F,
        "Y": 0x10, "T": 0x11, "U": 0x20, "I": 0x22, "O": 0x1F,
        "P": 0x23, "L": 0x25, "J": 0x26, "K": 0x28, "N": 0x2D,
        "M": 0x2E,

        // Numbers
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,

        // Symbols
        "[": 0x21, "]": 0x1E, ";": 0x29, "'": 0x27, ",": 0x2B,
        ".": 0x2F, "/": 0x2C, "\\": 0x2A, "`": 0x32, "-": 0x1B,
        "=": 0x18,

        // Special keys
        "Return": 0x24, "Enter": 0x24, "Tab": 0x30, "Space": 0x31,
        "Delete": 0x33, "Backspace": 0x33, "Escape": 0x35, "Esc": 0x35,

        // Arrow keys
        "Left": 0x7B, "Right": 0x7C, "Down": 0x7D, "Up": 0x7E,

        // Function keys
        "F1": 0x7A, "F2": 0x78, "F3": 0x63, "F4": 0x76,
        "F5": 0x60, "F6": 0x61, "F7": 0x62, "F8": 0x64,
        "F9": 0x65, "F10": 0x6D, "F11": 0x67, "F12": 0x6F,
        "F13": 0x69, "F14": 0x6B, "F15": 0x71,

        // Misc
        "Home": 0x73, "End": 0x77, "PageUp": 0x74, "PageDown": 0x79,
        "ForwardDelete": 0x75,
    ]

    // MARK: - Parsing

    /// Parse "Cmd+Shift+Z" into an Action.
    static func parseActionString(_ string: String) -> Action {
        let parts = string.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        var flags = CGEventFlags()
        var keyName: String?

        for part in parts {
            switch part.lowercased() {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "ctrl", "control":
                flags.insert(.maskControl)
            case "shift":
                flags.insert(.maskShift)
            case "opt", "option", "alt":
                flags.insert(.maskAlternate)
            default:
                keyName = part
            }
        }

        guard let name = keyName,
              let code = resolveKeyCode(name) else {
            print("[keysynth] Unknown key in action: \(string)")
            return .none
        }

        return .keystroke(modifiers: flags, keyCode: code)
    }

    private static func resolveKeyCode(_ name: String) -> UInt16? {
        // Try exact match first
        if let code = keyCodes[name] { return code }
        // Try uppercase
        if let code = keyCodes[name.uppercased()] { return code }
        // Try single character
        if name.count == 1, let code = keyCodes[String(name.first!).uppercased()] { return code }
        return nil
    }

    // MARK: - Event Synthesis

    /// Fire a keystroke action (key down + key up with modifiers).
    static func fire(_ action: Action) {
        switch action {
        case .keystroke(let modifiers, let keyCode):
            sendKeystroke(keyCode: keyCode, flags: modifiers)
        case .middleClick:
            sendMiddleClick()
        case .missionControl:
            sendKeystroke(keyCode: 0x7E, flags: .maskControl) // Ctrl+Up
        case .laserPointer, .none:
            break
        }
    }

    /// Send a keyboard event pair (down + up) with modifiers.
    static func sendKeystroke(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("[keysynth] Failed to create keyboard event for keyCode \(keyCode)")
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Send a middle mouse click (button 2 down + up).
    static func sendMiddleClick() {
        let source = CGEventSource(stateID: .hidSystemState)
        let loc = CGEvent(source: nil)?.location ?? .zero

        guard let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown,
                                 mouseCursorPosition: loc, mouseButton: .center),
              let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp,
                               mouseCursorPosition: loc, mouseButton: .center) else {
            return
        }

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
