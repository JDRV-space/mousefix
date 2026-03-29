import Foundation
import Yams

struct Config {
    let defaultProfile: ButtonMap

    static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mousefix")
    static let configPath = configDir.appendingPathComponent("config.yaml")

    /// Load config from ~/.config/mousefix/config.yaml, falling back to defaults.
    static func load() -> Config {
        if let data = try? Data(contentsOf: configPath),
           let yaml = String(data: data, encoding: .utf8) {
            return parse(yaml: yaml)
        }

        print("[config] No config at \(configPath.path), using defaults")
        return Config(defaultProfile: mxMasterDefaults())
    }

    static func parse(yaml: String) -> Config {
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any] else {
            print("[config] Failed to parse YAML, using defaults")
            return Config(defaultProfile: mxMasterDefaults())
        }

        var map = ButtonMap()

        // Parse button mappings: "buttons" is a dict of number -> action string.
        // Yams parses bare integer keys (e.g. 3:) as Int, not String.
        if let buttonsRaw = dict["buttons"] as? [AnyHashable: Any] {
            for (key, value) in buttonsRaw {
                let num: Int64?
                if let intKey = key as? Int { num = Int64(intKey) }
                else if let strKey = key as? String { num = Int64(strKey) }
                else { num = nil }

                if let num = num, let actionStr = value as? String {
                    map.buttons[num] = Action.parse(actionStr)
                }
            }
        }

        // Parse gesture config.
        if let gestureDict = dict["gesture"] as? [String: Any] {
            if let btn = gestureDict["button"] as? Int {
                map.gestureButton = Int64(btn)
            }
            if let v = gestureDict["click"] as? String { map.gestureClick = Action.parse(v) }
            if let v = gestureDict["hold_left"] as? String { map.gestureHoldLeft = Action.parse(v) }
            if let v = gestureDict["hold_right"] as? String { map.gestureHoldRight = Action.parse(v) }
            if let v = gestureDict["hold_up"] as? String { map.gestureHoldUp = Action.parse(v) }
            if let v = gestureDict["hold_down"] as? String { map.gestureHoldDown = Action.parse(v) }
        }

        // Parse tilt scroll config.
        if let tiltDict = dict["tilt_scroll"] as? [String: String] {
            if let v = tiltDict["left"] { map.tiltLeft = Action.parse(v) }
            if let v = tiltDict["right"] { map.tiltRight = Action.parse(v) }
        }

        // Parse haptic device name (optional).
        if let hapticDict = dict["haptic"] as? [String: String] {
            if let name = hapticDict["device"] {
                map.hapticDeviceName = name
            }
        }

        return Config(defaultProfile: map)
    }

    /// MX Master 4 defaults - works out of the box.
    /// These match the button mappings from the original plan.
    /// Run `mousefix discover` only if your numbers differ.
    static func mxMasterDefaults() -> ButtonMap {
        var map = ButtonMap()

        map.buttons = [
            2: .middleClick,                   // Middle click
            3: Action.parse("Cmd+Z"),          // Back thumb -> Undo
            4: Action.parse("Cmd+Shift+Z"),    // Forward thumb -> Redo
            5: Action.parse("Cmd+Shift+4"),    // Top button -> Screenshot
            6: Action.parse("Cmd+Space"),       // Third thumb -> Spotlight
            7: .laserPointer,                  // Below scroll -> Laser pointer
        ]

        // Gesture button: third thumb (button 6) also acts as gesture button.
        // When gesture is enabled, tap fires gesture_click instead of the
        // button's direct action. Set gesture_button to -1 to disable gestures
        // and use the direct Cmd+Space mapping instead.
        map.gestureButton = 6
        map.gestureClick = Action.parse("Cmd+Tab")
        map.gestureHoldLeft = Action.parse("Ctrl+Right")
        map.gestureHoldRight = Action.parse("Ctrl+Left")
        map.gestureHoldUp = .missionControl
        map.gestureHoldDown = .appExpose

        // Tilt scroll
        map.tiltLeft = Action.parse("Left")
        map.tiltRight = Action.parse("Right")

        return map
    }
}
