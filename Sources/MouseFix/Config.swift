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
        return Config(defaultProfile: defaultButtonMap())
    }

    /// Install the example config to ~/.config/mousefix/config.yaml if none exists.
    static func installDefault(from examplePath: String) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: configPath.path) else { return }
        try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? fm.copyItem(atPath: examplePath, toPath: configPath.path)
    }

    static func parse(yaml: String) -> Config {
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any],
              let defaultDict = dict["default"] as? [String: String] else {
            print("[config] Failed to parse YAML, using defaults")
            return Config(defaultProfile: defaultButtonMap())
        }

        var map = defaultButtonMap()

        if let v = defaultDict["button3"] { map.button3 = Action.parse(v) }
        if let v = defaultDict["button4"] { map.button4 = Action.parse(v) }
        if let v = defaultDict["button5"] { map.button5 = Action.parse(v) }
        if let v = defaultDict["button6"] { map.button6 = Action.parse(v) }
        if let v = defaultDict["gesture_click"] { map.gestureClick = Action.parse(v) }
        if let v = defaultDict["gesture_hold_left"] { map.gestureHoldLeft = Action.parse(v) }
        if let v = defaultDict["gesture_hold_right"] { map.gestureHoldRight = Action.parse(v) }
        if let v = defaultDict["gesture_hold_up"] { map.gestureHoldUp = Action.parse(v) }
        if let v = defaultDict["top_button"] { map.topButton = Action.parse(v) }
        if let v = defaultDict["scroll_button"] { map.scrollButton = Action.parse(v) }
        if let v = defaultDict["tilt_left"] { map.tiltLeft = Action.parse(v) }
        if let v = defaultDict["tilt_right"] { map.tiltRight = Action.parse(v) }

        return Config(defaultProfile: map)
    }

    private static func defaultButtonMap() -> ButtonMap {
        var map = ButtonMap()
        map.button3 = .middleClick
        map.button4 = Action.parse("Cmd+Z")
        map.button5 = Action.parse("Cmd+Shift+Z")
        map.button6 = Action.parse("Cmd+Space")
        map.gestureClick = Action.parse("Cmd+Tab")
        map.gestureHoldLeft = Action.parse("Ctrl+Left")
        map.gestureHoldRight = Action.parse("Ctrl+Right")
        map.gestureHoldUp = Action.parse("Ctrl+Down")
        map.topButton = Action.parse("Cmd+Shift+4")
        map.scrollButton = .laserPointer
        map.tiltLeft = Action.parse("Cmd+[")
        map.tiltRight = Action.parse("Cmd+]")
        return map
    }
}
