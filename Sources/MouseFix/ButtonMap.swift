import CoreGraphics
import Foundation

/// Actions that can be triggered by a button or gesture.
enum Action {
    case keystroke(modifiers: CGEventFlags, keyCode: UInt16)
    case middleClick
    case laserPointer
    case missionControl
    case none

    /// Parse an action string like "Cmd+Z", "MiddleClick", "LaserPointer".
    static func parse(_ string: String) -> Action {
        switch string {
        case "MiddleClick":
            return .middleClick
        case "LaserPointer":
            return .laserPointer
        case "MissionControl":
            return .missionControl
        case "None", "":
            return .none
        default:
            return KeySynth.parseActionString(string)
        }
    }
}

extension Action: Equatable {
    static func == (lhs: Action, rhs: Action) -> Bool {
        switch (lhs, rhs) {
        case (.keystroke(let m1, let k1), .keystroke(let m2, let k2)):
            return m1.rawValue == m2.rawValue && k1 == k2
        case (.middleClick, .middleClick),
             (.laserPointer, .laserPointer),
             (.missionControl, .missionControl),
             (.none, .none):
            return true
        default:
            return false
        }
    }
}

/// Maps macOS button numbers to actions.
/// Users define their own number->action pairs via config, so any mouse works.
struct ButtonMap {
    /// Button number -> action. User populates this from `mousefix discover` output.
    var buttons: [Int64: Action] = [:]

    /// Gesture engine config (hold button + move mouse).
    var gestureButton: Int64 = -1  // -1 = disabled
    var gestureClick: Action = .none
    var gestureHoldLeft: Action = .none
    var gestureHoldRight: Action = .none
    var gestureHoldUp: Action = .none

    /// Tilt scroll actions.
    var tiltLeft: Action = .none
    var tiltRight: Action = .none

    /// Haptic device name filter (substring match). Default matches any MX Master.
    var hapticDeviceName: String = "mx master"

    /// Look up the action for a given mouse button number.
    func action(forButton number: Int64) -> Action? {
        return buttons[number]
    }
}
