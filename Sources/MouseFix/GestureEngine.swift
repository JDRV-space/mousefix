import CoreGraphics
import Foundation

/// Tracks gesture button hold + mouse movement to detect directional gestures.
///
/// While the gesture button is held:
/// - Moving left → fires gestureHoldLeft action
/// - Moving right → fires gestureHoldRight action
/// - Moving up → fires gestureHoldUp action
/// - Releasing with no significant movement → fires gestureClick action
final class GestureEngine {
    private let buttonMap: ButtonMap
    private let hapticEngine: HapticEngine

    /// Which mouse button number is the gesture button.
    /// Default 5 for MX Master 4 third thumb button - update via `mousefix discover`.
    let gestureButtonNumber: Int64 = 5

    /// Movement threshold in pixels to trigger a directional action.
    private let threshold: Double = 50.0

    /// Accumulated movement while gesture button is held.
    private var deltaX: Double = 0
    private var deltaY: Double = 0
    private var isHeld = false
    private var hasFiredDirection = false

    init(buttonMap: ButtonMap, hapticEngine: HapticEngine) {
        self.buttonMap = buttonMap
        self.hapticEngine = hapticEngine
    }

    func buttonDown(event: CGEvent) {
        isHeld = true
        hasFiredDirection = false
        deltaX = 0
        deltaY = 0
    }

    func buttonUp(event: CGEvent) {
        guard isHeld else { return }
        isHeld = false

        if !hasFiredDirection {
            // No significant movement - treat as a click.
            KeySynth.fire(buttonMap.gestureClick)
        }
    }

    func mouseMoved(event: CGEvent) {
        guard isHeld, !hasFiredDirection else { return }

        let dx = event.getDoubleValueField(.mouseEventDeltaX)
        let dy = event.getDoubleValueField(.mouseEventDeltaY)

        deltaX += dx
        deltaY += dy

        let absX = abs(deltaX)
        let absY = abs(deltaY)

        // Check if we've exceeded the threshold in any direction.
        if absX >= threshold || absY >= threshold {
            hasFiredDirection = true

            if absX > absY {
                // Horizontal dominant
                if deltaX < 0 {
                    KeySynth.fire(buttonMap.gestureHoldLeft)
                    hapticEngine.fireHaptic()
                } else {
                    KeySynth.fire(buttonMap.gestureHoldRight)
                    hapticEngine.fireHaptic()
                }
            } else {
                // Vertical dominant - up only (negative Y = up in screen coordinates)
                if deltaY < 0 {
                    KeySynth.fire(buttonMap.gestureHoldUp)
                } else {
                    // Down gesture - currently unused, could be added later
                    KeySynth.fire(buttonMap.gestureHoldUp)
                }
            }
        }
    }
}
