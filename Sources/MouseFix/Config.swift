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
        if let buttonsDict = dict["buttons"] as? [String: String] {
            for (key, value) in buttonsDict {
                if let num = Int64(key) {
                    map.buttons[num] = Action.parse(value)
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
            2: .middleClick,                   // Middle click (button3)
            3: Action.parse("Cmd+Z"),          // Back thumb (button4) -> Undo
            4: Action.parse("Cmd+Shift+Z"),    // Forward thumb (button5) -> Redo
            5: Action.parse("Cmd+Space"),       // Third thumb (button6) -> Spotlight
            6: Action.parse("Cmd+Shift+4"),    // Top button -> Screenshot
            7: .laserPointer,                  // Below scroll -> Laser pointer
        ]

        // Gesture button: third thumb (button 5) also acts as gesture button.
        // When gesture is enabled, tap fires gesture_click instead of the
        // button's direct action. Set gesture_button to -1 to disable gestures
        // and use the direct Cmd+Space mapping instead.
        map.gestureButton = 5
        map.gestureClick = Action.parse("Cmd+Tab")
        map.gestureHoldLeft = Action.parse("Ctrl+Left")
        map.gestureHoldRight = Action.parse("Ctrl+Right")
        map.gestureHoldUp = Action.parse("Ctrl+Down")

        // Tilt scroll
        map.tiltLeft = Action.parse("Cmd+[")
        map.tiltRight = Action.parse("Cmd+]")

        return map
    }
}
