import CoreGraphics
import Foundation

/// Actions that can be triggered by a button or gesture.
public enum Action {
    case keystroke(modifiers: CGEventFlags, keyCode: UInt16)
    case middleClick
    case laserPointer
    case missionControl
    case appExpose
    case showDesktop
    case none

    /// Parse an action string like "Cmd+Z", "MiddleClick", "LaserPointer".
    public static func parse(_ string: String) -> Action {
        switch string {
        case "MiddleClick":
            return .middleClick
        case "LaserPointer":
            return .laserPointer
        case "MissionControl":
            return .missionControl
        case "AppExpose":
            return .appExpose
        case "ShowDesktop":
            return .showDesktop
        case "None", "":
            return .none
        default:
            return KeySynth.parseActionString(string)
        }
    }
}

extension Action: Equatable {
    public static func == (lhs: Action, rhs: Action) -> Bool {
        switch (lhs, rhs) {
        case (.keystroke(let m1, let k1), .keystroke(let m2, let k2)):
            return m1.rawValue == m2.rawValue && k1 == k2
        case (.middleClick, .middleClick),
             (.laserPointer, .laserPointer),
             (.missionControl, .missionControl),
             (.appExpose, .appExpose),
             (.showDesktop, .showDesktop),
             (.none, .none):
            return true
        default:
            return false
        }
    }
}

/// Maps macOS button numbers to actions.
/// Users define their own number->action pairs via config, so any mouse works.
public struct ButtonMap {
    /// Button number -> action. User populates this from `mousefix discover` output.
    public var buttons: [Int64: Action] = [:]

    /// Gesture engine config (hold button + move mouse).
    public var gestureButton: Int64 = -1  // -1 = disabled
    public var gestureClick: Action = .none
    public var gestureHoldLeft: Action = .none
    public var gestureHoldRight: Action = .none
    public var gestureHoldUp: Action = .none
    public var gestureHoldDown: Action = .none

    /// Tilt scroll actions.
    public var tiltLeft: Action = .none
    public var tiltRight: Action = .none

    /// Haptic device name filter (substring match). Default matches any MX Master.
    public var hapticDeviceName: String = "mx master"

    public init() {}

    /// Look up the action for a given mouse button number.
    public func action(forButton number: Int64) -> Action? {
        return buttons[number]
    }
}
