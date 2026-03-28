import AppKit
import CoreGraphics
import Foundation

// MARK: - CLI Argument Parsing

let args = CommandLine.arguments
let command = args.count > 1 ? args[1] : "run"

switch command {
case "discover":
    runDiscover()
case "run":
    runDaemon()
case "help", "--help", "-h":
    printUsage()
case "version", "--version":
    print("mousefix 0.1.0")
default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}

// MARK: - Commands

func printUsage() {
    print("""
    mousefix - open-source mouse button remapper for macOS

    USAGE:
      mousefix run         Start the daemon (default)
      mousefix discover    Log button numbers for all mouse events
      mousefix help        Show this help
      mousefix version     Show version

    CONFIG:
      ~/.config/mousefix/config.yaml

    PERMISSIONS:
      System Settings > Privacy & Security > Accessibility
      System Settings > Privacy & Security > Input Monitoring
    """)
}

func runDiscover() {
    print("[mousefix] Discovery mode - press mouse buttons to see their numbers")
    print("[mousefix] Press Ctrl+C to exit\n")

    let config = Config(defaultProfile: ButtonMap())
    let haptic = HapticEngine()
    let laser = LaserPointer()
    let gesture = GestureEngine(buttonMap: config.defaultProfile, hapticEngine: haptic)
    let eventTap = EventTap(buttonMap: config.defaultProfile, gestureEngine: gesture, laserPointer: laser)
    eventTap.discoverMode = true

    guard eventTap.start() else {
        print("[mousefix] Failed to start event tap. Check Accessibility permissions.")
        exit(1)
    }

    setupSignalHandlers {
        eventTap.stop()
        print("\n[mousefix] Discovery mode stopped.")
        exit(0)
    }

    CFRunLoopRun()
}

func runDaemon() {
    print("[mousefix] Starting daemon...")

    let config = Config.load()
    let map = config.defaultProfile

    printMappings(map)

    let haptic = HapticEngine()
    haptic.setDeviceFilter(map.hapticDeviceName)
    let laser = LaserPointer()
    let gesture = GestureEngine(buttonMap: map, hapticEngine: haptic)
    let eventTap = EventTap(buttonMap: map, gestureEngine: gesture, laserPointer: laser)

    haptic.connect()

    guard eventTap.start() else {
        print("[mousefix] Failed to start event tap. Check Accessibility permissions.")
        exit(1)
    }

    setupSignalHandlers {
        print("\n[mousefix] Shutting down...")
        eventTap.stop()
        haptic.disconnect()
        laser.hide()
        print("[mousefix] Goodbye.")
        exit(0)
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    laser.setup()

    // Menu bar icon
    setupMenuBar(eventTap: eventTap)

    print("[mousefix] Daemon running. Press Ctrl+C to stop.")
    app.run()
}

// MARK: - Menu Bar

private var statusItem: NSStatusItem?
private var eventTapRef: EventTap?

func setupMenuBar(eventTap: EventTap) {
    eventTapRef = eventTap
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.title = "🖱"

    let menu = NSMenu()

    let toggleItem = NSMenuItem(title: "Enabled", action: #selector(MenuActions.toggle(_:)), keyEquivalent: "")
    toggleItem.target = MenuActions.shared
    toggleItem.state = .on
    menu.addItem(toggleItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit", action: #selector(MenuActions.quit(_:)), keyEquivalent: "q")
    quitItem.target = MenuActions.shared
    menu.addItem(quitItem)

    statusItem?.menu = menu
}

final class MenuActions: NSObject {
    static let shared = MenuActions()

    @objc func toggle(_ sender: NSMenuItem) {
        if sender.state == .on {
            eventTapRef?.stop()
            sender.state = .off
            statusItem?.button?.title = "🔇"
            print("[mousefix] Disabled")
        } else {
            _ = eventTapRef?.start()
            sender.state = .on
            statusItem?.button?.title = "🖱"
            print("[mousefix] Enabled")
        }
    }

    @objc func quit(_ sender: NSMenuItem) {
        print("[mousefix] Goodbye.")
        NSApp.terminate(nil)
    }
}

// MARK: - Helpers

func setupSignalHandlers(cleanup: @escaping () -> Void) {
    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler { cleanup() }
    sigintSource.resume()
    signal(SIGINT, SIG_IGN)

    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigtermSource.setEventHandler { cleanup() }
    sigtermSource.resume()
    signal(SIGTERM, SIG_IGN)

    _signalSources = [sigintSource, sigtermSource]
}

var _signalSources: [Any] = []

func printMappings(_ map: ButtonMap) {
    print("[mousefix] Active mappings:")
    fflush(stdout)

    for number in map.buttons.keys.sorted() {
        let action = map.buttons[number]!
        print("  button \(number) -> \(describeAction(action))")
    }

    // Print gesture config.
    if map.gestureButton >= 0 {
        print("  gesture (button \(map.gestureButton)):")
        print("    tap        -> \(describeAction(map.gestureClick))")
        print("    hold+left  -> \(describeAction(map.gestureHoldLeft))")
        print("    hold+right -> \(describeAction(map.gestureHoldRight))")
        print("    hold+up    -> \(describeAction(map.gestureHoldUp))")
        print("    hold+down  -> \(describeAction(map.gestureHoldDown))")
    }

    // Print tilt scroll.
    if map.tiltLeft != .none || map.tiltRight != .none {
        print("  tilt scroll:")
        print("    left  -> \(describeAction(map.tiltLeft))")
        print("    right -> \(describeAction(map.tiltRight))")
    }
}

func describeAction(_ action: Action) -> String {
    switch action {
    case .keystroke(let mods, let key):
        var parts: [String] = []
        if mods.contains(.maskCommand) { parts.append("Cmd") }
        if mods.contains(.maskControl) { parts.append("Ctrl") }
        if mods.contains(.maskShift) { parts.append("Shift") }
        if mods.contains(.maskAlternate) { parts.append("Opt") }
        parts.append(keycodeName(key))
        return parts.joined(separator: "+")
    case .middleClick:
        return "MiddleClick"
    case .laserPointer:
        return "LaserPointer"
    case .missionControl:
        return "MissionControl"
    case .appExpose:
        return "AppExpose"
    case .showDesktop:
        return "ShowDesktop"
    case .none:
        return "(none)"
    }
}

func keycodeName(_ code: UInt16) -> String {
    switch code {
    case 0x00: return "A"
    case 0x01: return "S"
    case 0x02: return "D"
    case 0x03: return "F"
    case 0x04: return "H"
    case 0x05: return "G"
    case 0x06: return "Z"
    case 0x07: return "X"
    case 0x08: return "C"
    case 0x09: return "V"
    case 0x0B: return "B"
    case 0x0C: return "Q"
    case 0x0D: return "W"
    case 0x0E: return "E"
    case 0x0F: return "R"
    case 0x10: return "Y"
    case 0x11: return "T"
    case 0x12: return "1"
    case 0x13: return "2"
    case 0x14: return "3"
    case 0x15: return "4"
    case 0x16: return "6"
    case 0x17: return "5"
    case 0x19: return "9"
    case 0x1A: return "7"
    case 0x1B: return "-"
    case 0x1C: return "8"
    case 0x1D: return "0"
    case 0x1E: return "]"
    case 0x1F: return "O"
    case 0x20: return "U"
    case 0x21: return "["
    case 0x22: return "I"
    case 0x23: return "P"
    case 0x24: return "Return"
    case 0x25: return "L"
    case 0x26: return "J"
    case 0x28: return "K"
    case 0x2D: return "N"
    case 0x2E: return "M"
    case 0x30: return "Tab"
    case 0x31: return "Space"
    case 0x35: return "Escape"
    case 0x7A: return "F1"
    case 0x78: return "F2"
    case 0x63: return "F3"
    case 0x76: return "F4"
    case 0x60: return "F5"
    case 0x61: return "F6"
    case 0x62: return "F7"
    case 0x64: return "F8"
    case 0x7B: return "Left"
    case 0x7C: return "Right"
    case 0x7D: return "Down"
    case 0x7E: return "Up"
    default: return "0x\(String(code, radix: 16))"
    }
}
