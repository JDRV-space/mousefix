import CoreGraphics
import Foundation

/// Keeps modifier-key state synchronized with mouse button down/up events.
///
/// Multiple buttons may hold modifiers simultaneously. Releasing one button
/// preserves modifiers still held by another button. `releaseAll()` prevents
/// shutdown or event-tap resets from leaving a modifier logically stuck.
final class HeldModifierController {
    private static let modifierKeyCodes: [(flag: CGEventFlags, keyCode: UInt16)] = [
        (.maskCommand, 0x37),
        (.maskShift, 0x38),
        (.maskAlternate, 0x3A),
        (.maskControl, 0x3B),
    ]

    private let eventSink: (CGEvent) -> Void
    private var modifiersByButton: [Int64: CGEventFlags] = [:]

    private(set) var activeFlags = CGEventFlags()

    init(eventSink: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }) {
        self.eventSink = eventSink
    }

    func press(button: Int64, modifiers: CGEventFlags) {
        guard modifiersByButton[button] == nil else {
            return
        }

        let previousFlags = activeFlags
        modifiersByButton[button] = modifiers
        let nextFlags = combinedFlags()
        postTransitions(from: previousFlags, to: nextFlags)
        activeFlags = nextFlags
    }

    func release(button: Int64) {
        guard modifiersByButton.removeValue(forKey: button) != nil else {
            return
        }

        let previousFlags = activeFlags
        let nextFlags = combinedFlags()
        postTransitions(from: previousFlags, to: nextFlags)
        activeFlags = nextFlags
    }

    func releaseAll() {
        let previousFlags = activeFlags
        modifiersByButton.removeAll()
        postTransitions(from: previousFlags, to: [])
        activeFlags = []
    }

    func applyActiveFlags(to event: CGEvent) {
        guard !activeFlags.isEmpty else {
            return
        }

        var flags = event.flags
        flags.formUnion(activeFlags)
        event.flags = flags
    }

    private func combinedFlags() -> CGEventFlags {
        modifiersByButton.values.reduce(into: CGEventFlags()) { result, flags in
            result.formUnion(flags)
        }
    }

    private func postTransitions(from previousFlags: CGEventFlags, to nextFlags: CGEventFlags) {
        for modifier in Self.modifierKeyCodes {
            let wasActive = previousFlags.contains(modifier.flag)
            let isActive = nextFlags.contains(modifier.flag)
            guard wasActive != isActive,
                  let event = CGEvent(
                      keyboardEventSource: nil,
                      virtualKey: modifier.keyCode,
                      keyDown: isActive
                  ) else {
                continue
            }

            event.flags = nextFlags
            ActionRunner.markSynthetic(event)
            eventSink(event)
        }
    }
}
