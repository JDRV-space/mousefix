import CoreGraphics
import Foundation
import MouseFixCore

private var failures: [String] = []

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures.append(message)
    }
}

private func parsesButtonGestureTiltAndHapticConfig() {
    let yaml = """
    buttons:
      3: "Cmd+Z"
      "8": "LaserPointer"

    gesture:
      button: 6
      click: "Cmd+Tab"
      hold_left: "Ctrl+Right"
      hold_right: "Ctrl+Left"
      hold_up: "MissionControl"
      hold_down: "AppExpose"

    tilt_scroll:
      left: "Left"
      right: "Right"

    haptic:
      device: "MX Master"
    """

    let map = Config.parse(yaml: yaml).defaultProfile

    assertKeystroke(map.buttons[3], keyCode: 0x06, modifiers: .maskCommand)
    expect(map.buttons[8] == .laserPointer, "button 8 should parse as LaserPointer")
    expect(map.gestureButton == 6, "gesture button should parse as 6")
    assertKeystroke(map.gestureClick, keyCode: 0x30, modifiers: .maskCommand)
    assertKeystroke(map.gestureHoldLeft, keyCode: 0x7C, modifiers: .maskControl)
    assertKeystroke(map.gestureHoldRight, keyCode: 0x7B, modifiers: .maskControl)
    expect(map.gestureHoldUp == .missionControl, "hold_up should parse as MissionControl")
    expect(map.gestureHoldDown == .appExpose, "hold_down should parse as AppExpose")
    assertKeystroke(map.tiltLeft, keyCode: 0x7B, modifiers: [])
    assertKeystroke(map.tiltRight, keyCode: 0x7C, modifiers: [])
    expect(map.hapticDeviceName == "MX Master", "haptic device should parse")
}

private func invalidYamlFallsBackToMxMasterDefaults() {
    let map = Config.parse(yaml: "buttons: [").defaultProfile

    expect(map.buttons[2] == .middleClick, "invalid YAML should fall back to middle-click default")
    assertKeystroke(map.buttons[3], keyCode: 0x06, modifiers: .maskCommand)
    expect(map.gestureButton == 6, "invalid YAML should fall back to default gesture button")
}

private func unknownActionParsesToNone() {
    expect(Action.parse("Cmd+NotAKey") == .none, "unknown keys should parse to None")
}

private func assertKeystroke(
    _ action: Action?,
    keyCode: UInt16,
    modifiers: CGEventFlags
) {
    guard let action = action else {
        failures.append("Expected keystroke, got nil")
        return
    }

    guard case let .keystroke(actualModifiers, actualKeyCode) = action else {
        failures.append("Expected keystroke, got \(String(describing: action))")
        return
    }

    expect(actualKeyCode == keyCode, "expected keyCode \(keyCode), got \(actualKeyCode)")
    expect(
        actualModifiers.rawValue == modifiers.rawValue,
        "expected modifiers \(modifiers.rawValue), got \(actualModifiers.rawValue)"
    )
}

parsesButtonGestureTiltAndHapticConfig()
invalidYamlFallsBackToMxMasterDefaults()
unknownActionParsesToNone()

if failures.isEmpty {
    print("[checks] MouseFixCore checks passed")
} else {
    for failure in failures {
        fputs("[checks] \(failure)\n", stderr)
    }
    exit(1)
}
