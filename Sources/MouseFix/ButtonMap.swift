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

/// Maps physical button numbers and gesture directions to actions.
struct ButtonMap {
    var button3: Action = .middleClick
    var button4: Action = .none
    var button5: Action = .none
    var button6: Action = .none
    var gestureClick: Action = .none
    var gestureHoldLeft: Action = .none
    var gestureHoldRight: Action = .none
    var gestureHoldUp: Action = .none
    var topButton: Action = .none
    var scrollButton: Action = .none
    var tiltLeft: Action = .none
    var tiltRight: Action = .none

    /// Look up the action for a given mouse button number.
    func action(forButton number: Int64) -> Action? {
        // MX Master 4 button numbers (may vary - use `mousefix discover` to verify):
        //   2 = middle click (button3)
        //   3 = back thumb (button4)
        //   4 = forward thumb (button5)
        //   5 = third thumb button (button6)
        //   6 = top button
        //   7 = below-scroll button (scroll_button)
        switch number {
        case 2: return button3
        case 3: return button4
        case 4: return button5
        case 5: return button6
        case 6: return topButton
        case 7: return scrollButton
        default: return nil
        }
    }
}
