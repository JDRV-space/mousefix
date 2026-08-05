import CoreGraphics
import Foundation
import MouseFixCore

struct SideScrollCommand: Equatable {
    let action: Action
    let repeatCount: Int

    static func resolve(delta: ScrollVector, buttonMap: ButtonMap) -> SideScrollCommand? {
        guard abs(delta.x) >= 0.01, abs(delta.x) >= abs(delta.y) else {
            return nil
        }

        let action = delta.x < 0 ? buttonMap.tiltLeft : buttonMap.tiltRight
        guard action != .none else {
            return nil
        }

        return SideScrollCommand(
            action: action,
            repeatCount: min(max(1, Int(abs(delta.x) / 30)), 12)
        )
    }
}

/// Intercepts local input events and applies the configured mouse mappings.
final class EventTap {
    private let buttonMap: ButtonMap
    private let gestureEngine: GestureEngine
    private let laserPointer: LaserPointer
    private let deviceResolver: InputDeviceResolver
    private let verticalScrollEngine: SmoothScrollEngine
    private let horizontalScrollEngine: SmoothScrollEngine
    private let heldModifiers: HeldModifierController
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Whether events should be logged instead of remapped.
    var discoverMode = false

    init(
        buttonMap: ButtonMap,
        gestureEngine: GestureEngine,
        laserPointer: LaserPointer,
        deviceResolver: InputDeviceResolver,
        verticalScrollEngine: SmoothScrollEngine,
        horizontalScrollEngine: SmoothScrollEngine,
        heldModifiers: HeldModifierController = HeldModifierController()
    ) {
        self.buttonMap = buttonMap
        self.gestureEngine = gestureEngine
        self.laserPointer = laserPointer
        self.deviceResolver = deviceResolver
        self.verticalScrollEngine = verticalScrollEngine
        self.horizontalScrollEngine = horizontalScrollEngine
        self.heldModifiers = heldModifiers
    }

    /// Starts intercepting events. Must be called on the main thread.
    func start() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPointer
        ) else {
            print("[event-tap] Failed to create event tap.")
            print("[event-tap] Grant Accessibility permission in System Settings.")
            return false
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[event-tap] Listening for input events...")
        return true
    }

    func stop() {
        verticalScrollEngine.stop()
        horizontalScrollEngine.stop()
        heldModifiers.releaseAll()
        laserPointer.hide()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// Returns nil to suppress the event or the event to pass it through.
    func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        if !ActionRunner.isSynthetic(event) {
            heldModifiers.applyActiveFlags(to: event)
        }

        switch type {
        case .keyDown, .keyUp, .flagsChanged,
             .leftMouseDown, .leftMouseUp,
             .rightMouseDown, .rightMouseUp:
            return event
        case .otherMouseDown:
            return handleButtonDown(event: event)
        case .otherMouseUp:
            return handleButtonUp(event: event)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return handleMouseMoved(event: event)
        case .scrollWheel:
            return handleScroll(event: event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            print("[event-tap] Tap was disabled, re-enabling...")
            heldModifiers.releaseAll()
            if let tap {
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

        if gestureEngine.isEnabled, button == gestureEngine.gestureButtonNumber {
            gestureEngine.buttonDown()
            return nil
        }

        guard let action = buttonMap.action(forButton: button) else {
            return event
        }

        switch action {
        case .middleClick:
            guard Self.shouldSynthesizeMiddleClick(forButton: button) else {
                return event
            }
            ActionRunner.fire(action)
            return nil
        case .laserPointer:
            laserPointer.show()
            return nil
        case .heldModifier(let modifiers):
            heldModifiers.press(button: button, modifiers: modifiers)
            return nil
        default:
            ActionRunner.fire(action)
            return nil
        }
    }

    private func handleButtonUp(event: CGEvent) -> CGEvent? {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)

        if discoverMode {
            print("[discover] Button UP   - number: \(button)")
            return event
        }

        if gestureEngine.isEnabled, button == gestureEngine.gestureButtonNumber {
            gestureEngine.buttonUp()
            return nil
        }

        guard let action = buttonMap.action(forButton: button) else {
            return event
        }

        switch action {
        case .middleClick:
            return Self.shouldSynthesizeMiddleClick(forButton: button) ? nil : event
        case .laserPointer:
            laserPointer.hide()
            return nil
        case .heldModifier:
            heldModifiers.release(button: button)
            return nil
        default:
            return nil
        }
    }

    private func handleMouseMoved(event: CGEvent) -> CGEvent? {
        gestureEngine.mouseMoved(event: event)
        if laserPointer.isVisible {
            laserPointer.updatePosition(event: event)
        }
        return event
    }

    private func handleScroll(event: CGEvent) -> CGEvent? {
        if discoverMode {
            let delta = SmoothScrollEngine.pixelDelta(from: event)
            let descriptor = deviceResolver.descriptor(for: event)
            let product = descriptor?.product ?? "unknown"
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
            let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            print(
                "[discover] Scroll device=\(product) x=\(delta.x) y=\(delta.y) " +
                "continuous=\(continuous) phase=\(scrollPhase) momentum=\(momentumPhase)"
            )
            return event
        }

        if SmoothScrollEngine.isSynthetic(event) {
            return event
        }

        // Trackpads and unrelated devices pass through unchanged. Only the
        // configured physical mouse is rewritten.
        guard deviceResolver.kind(for: event) == .targetMouse else {
            return event
        }

        // Do not reshape an event that already carries native gesture phases.
        let hasNativeScrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
        let hasNativeMomentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        if hasNativeScrollPhase || hasNativeMomentum {
            return event
        }

        let delta = SmoothScrollEngine.pixelDelta(from: event)
        if abs(delta.x) >= 0.01, abs(delta.x) >= abs(delta.y) {
            if let command = SideScrollCommand.resolve(delta: delta, buttonMap: buttonMap) {
                for _ in 0 ..< command.repeatCount {
                    ActionRunner.fire(command.action)
                }
                return nil
            }

            let horizontalDelta = ScrollVector(x: delta.x, y: 0)
            return horizontalScrollEngine.consume(event, delta: horizontalDelta) ? nil : event
        }

        let verticalDelta = ScrollVector(x: 0, y: delta.y)
        return verticalScrollEngine.consume(event, delta: verticalDelta) ? nil : event
    }

    static func shouldSynthesizeMiddleClick(forButton button: Int64) -> Bool {
        button != Int64(CGMouseButton.center.rawValue)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let eventTap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
    guard let result = eventTap.handleEvent(type: type, event: event) else {
        return nil
    }

    // CoreGraphics owns the incoming event. Returning it retained leaks one
    // reference for every intercepted mouse or keyboard event.
    return Unmanaged.passUnretained(result)
}
