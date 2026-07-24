import CoreGraphics
import Foundation
import MouseFixCore

// Private Dock API for triggering Mission Control / Expose / Show Desktop.
@_silgen_name("CoreDockSendNotification")
private func CoreDockSendNotification(_ notification: CFString) -> Void

/// Runs parsed actions by posting local input events or Dock notifications.
enum ActionRunner {
    static func fire(_ action: Action) {
        switch action {
        case .keystroke(let modifiers, let keyCode):
            sendKeystroke(keyCode: keyCode, flags: modifiers)
        case .middleClick:
            sendMiddleClick()
        case .missionControl:
            CoreDockSendNotification("com.apple.expose.awake" as CFString)
        case .appExpose:
            CoreDockSendNotification("com.apple.expose.front.awake" as CFString)
        case .showDesktop:
            CoreDockSendNotification("com.apple.showdesktop.awake" as CFString)
        case .laserPointer, .none:
            break
        }
    }

    private static func sendKeystroke(keyCode: UInt16, flags: CGEventFlags) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("[action-runner] Failed to create keyboard event for keyCode \(keyCode)")
            return
        }

        var allFlags = flags
        if keyCode >= 0x7B && keyCode <= 0x7E {
            allFlags.insert(.maskNumericPad)
            allFlags.insert(.maskSecondaryFn)
        }

        let fnKeyCodes: Set<UInt16> = [
            0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,
            0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71,
        ]
        if fnKeyCodes.contains(keyCode) {
            allFlags.insert(.maskSecondaryFn)
        }

        keyDown.flags = allFlags
        keyUp.flags = allFlags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func sendMiddleClick() {
        let source = CGEventSource(stateID: .hidSystemState)
        let loc = CGEvent(source: nil)?.location ?? .zero

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseDown,
            mouseCursorPosition: loc,
            mouseButton: .center
        ),
            let up = CGEvent(
                mouseEventSource: source,
                mouseType: .otherMouseUp,
                mouseCursorPosition: loc,
                mouseButton: .center
            )
        else {
            return
        }

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
