import CoreGraphics
import Foundation

/// Intercepts mouse events via CGEvent tap and remaps them according to the button map.
final class EventTap {
    private let buttonMap: ButtonMap
    private let gestureEngine: GestureEngine
    private let laserPointer: LaserPointer
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Whether we're in discovery mode (log events instead of remapping).
    var discoverMode = false

    init(buttonMap: ButtonMap, gestureEngine: GestureEngine, laserPointer: LaserPointer) {
        self.buttonMap = buttonMap
        self.gestureEngine = gestureEngine
        self.laserPointer = laserPointer
    }

    /// Start intercepting mouse events. Must be called on the main thread.
    func start() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        // Store self in an unmanaged pointer to pass through the C callback.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("[event-tap] Failed to create event tap.")
            print("[event-tap] Make sure MouseFix has Accessibility permission:")
            print("[event-tap]   System Settings > Privacy & Security > Accessibility")
            return false
        }

        self.tap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[event-tap] Listening for mouse events...")
        return true
    }

    func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    // MARK: - Event Handling

    /// Called for every intercepted event. Returns nil to suppress, or the event to pass through.
    func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        switch type {
        case .otherMouseDown:
            return handleButtonDown(event: event)
        case .otherMouseUp:
            return handleButtonUp(event: event)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return handleMouseMoved(event: event)
        case .scrollWheel:
            return handleScroll(event: event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Re-enable the tap if macOS disables it.
            print("[event-tap] Tap was disabled, re-enabling...")
            if let tap = tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return event
        default:
            return event
        }
    }

    private func handleButtonDown(event: CGEvent) -> CGEvent? {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)

        if discoverMode {
            print("[discover] Button DOWN - number: \(button)")
            return event
        }

        // Check if this is the gesture button.
        if gestureEngine.isEnabled && button == gestureEngine.gestureButtonNumber {
            gestureEngine.buttonDown(event: event)
            return nil // suppress
        }

        // Check if this is the scroll button (laser pointer trigger).
        if let action = buttonMap.action(forButton: button) {
            if action == .laserPointer {
                laserPointer.show()
                return nil
            }
            KeySynth.fire(action)
            return nil // suppress original
        }

        return event
    }

    private func handleButtonUp(event: CGEvent) -> CGEvent? {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)

        if discoverMode {
            print("[discover] Button UP   - number: \(button)")
            return event
        }

        if gestureEngine.isEnabled && button == gestureEngine.gestureButtonNumber {
            gestureEngine.buttonUp(event: event)
            return nil
        }

        if let action = buttonMap.action(forButton: button) {
            if action == .laserPointer {
                laserPointer.hide()
                return nil
            }
            return nil // already fired on down
        }

        return event
    }

    private func handleMouseMoved(event: CGEvent) -> CGEvent? {
        // Feed movement to gesture engine if gesture button is held.
        gestureEngine.mouseMoved(event: event)

        // Update laser pointer position if visible.
        if laserPointer.isVisible {
            laserPointer.updatePosition(event: event)
        }

        return event
    }

    private func handleScroll(event: CGEvent) -> CGEvent? {
        // Check horizontal axis for tilt scroll.
        let horizontal = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)

        if horizontal == 0 { return event }

        if discoverMode {
            print("[discover] Scroll tilt - horizontal delta: \(horizontal)")
            return event
        }

        // Proportional: 1 arrow per 30 delta units, minimum 1
        let absDelta = abs(Int(horizontal))
        let repeats = max(1, absDelta / 30)
        let action = horizontal < 0 ? buttonMap.tiltLeft : buttonMap.tiltRight

        for _ in 0..<repeats {
            KeySynth.fire(action)
        }

        return nil // suppress original tilt
    }
}

// MARK: - C Callback

/// The CGEvent tap callback - bridges to EventTap.handleEvent.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }

    let tap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()

    if let result = tap.handleEvent(type: type, event: event) {
        return Unmanaged.passRetained(result)
    }
    return nil // suppress event
}
