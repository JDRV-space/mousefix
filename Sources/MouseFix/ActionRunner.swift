import CoreGraphics
import Foundation
import MouseFixCore

// Private Dock API for triggering Mission Control / Expose / Show Desktop.
@_silgen_name("CoreDockSendNotification")
private func CoreDockSendNotification(_ notification: CFString) -> Void

/// Runs parsed actions by posting local input events or Dock notifications.
enum ActionRunner {
    static let syntheticMarker: Int64 = 0x4D4F5553454B4559

    static func fire(_ action: Action) {
        switch action {
        case .keystroke(let modifiers, let keyCode):
            sendKeystroke(keyCode: keyCode, flags: modifiers)
        case .heldModifier:
            break
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

    static func sendKeystroke(keyCode: UInt16, flags: CGEventFlags) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("[action-runner] Failed to create keyboard event for keyCode \(keyCode)")
            return
        }

        let allFlags = effectiveFlags(for: keyCode, baseFlags: flags)
        keyDown.flags = allFlags
        keyUp.flags = allFlags
        markSynthetic(keyDown)
        markSynthetic(keyUp)

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static func effectiveFlags(
        for keyCode: UInt16,
        baseFlags: CGEventFlags
    ) -> CGEventFlags {
        var allFlags = baseFlags

        // Plain arrows only need numericPad. macOS global shortcuts such as
        // Control+Left/Right expect the function flag found on physical
        // modified-arrow events.
        if keyCode >= 0x7B && keyCode <= 0x7E {
            allFlags.insert(.maskNumericPad)
            if !baseFlags.isEmpty {
                allFlags.insert(.maskSecondaryFn)
            }
        }

        let fnKeyCodes: Set<UInt16> = [
            0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,
            0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71,
        ]
        if fnKeyCodes.contains(keyCode) {
            allFlags.insert(.maskSecondaryFn)
        }
        return allFlags
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

        markSynthetic(down)
        markSynthetic(up)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func markSynthetic(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
    }

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticMarker
    }
}
