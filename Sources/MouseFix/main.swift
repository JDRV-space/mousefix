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
    mousefix - MX Master 4 button remapper for macOS

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

    // Run the event loop (no NSApplication needed for discover mode).
    CFRunLoopRun()
}

func runDaemon() {
    print("[mousefix] Starting daemon...")

    // Load config.
    let config = Config.load()
    let map = config.defaultProfile

    print("[mousefix] Config loaded")
    printMappings(map)

    // Initialize engines.
    let haptic = HapticEngine()
    let laser = LaserPointer()
    let gesture = GestureEngine(buttonMap: map, hapticEngine: haptic)
    let eventTap = EventTap(buttonMap: map, gestureEngine: gesture, laserPointer: laser)

    // Connect haptic engine (best-effort).
    haptic.connect()

    // Start event tap.
    guard eventTap.start() else {
        print("[mousefix] Failed to start event tap. Check Accessibility permissions.")
        exit(1)
    }

    // Set up signal handlers for clean shutdown.
    setupSignalHandlers {
        print("\n[mousefix] Shutting down...")
        eventTap.stop()
        haptic.disconnect()
        laser.hide()
        print("[mousefix] Goodbye.")
        exit(0)
    }

    // We need NSApplication for the laser pointer's NSWindow.
    // Run as a background app (no dock icon, no menu bar).
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    // Set up laser pointer after app is ready.
    laser.setup()

    print("[mousefix] Daemon running. Press Ctrl+C to stop.")

    // Run the main event loop.
    app.run()
}

// MARK: - Helpers

func setupSignalHandlers(cleanup: @escaping () -> Void) {
    let handler: @convention(c) (Int32) -> Void = { _ in
        // Can't capture cleanup directly in a C function pointer,
        // so we'll use a different approach.
    }
    _ = handler // suppress unused warning

    // Use DispatchSource for clean signal handling.
    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler { cleanup() }
    sigintSource.resume()
    signal(SIGINT, SIG_IGN) // Let DispatchSource handle it.

    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigtermSource.setEventHandler { cleanup() }
    sigtermSource.resume()
    signal(SIGTERM, SIG_IGN)

    // Keep sources alive.
    _signalSources = [sigintSource, sigtermSource]
}

/// Prevent signal sources from being deallocated.
var _signalSources: [Any] = []

func printMappings(_ map: ButtonMap) {
    print("[mousefix] Active mappings:")
    printAction("  button3 (middle)", map.button3)
    printAction("  button4 (back thumb)", map.button4)
    printAction("  button5 (fwd thumb)", map.button5)
    printAction("  button6 (third thumb)", map.button6)
    printAction("  gesture click", map.gestureClick)
    printAction("  gesture hold left", map.gestureHoldLeft)
    printAction("  gesture hold right", map.gestureHoldRight)
    printAction("  gesture hold up", map.gestureHoldUp)
    printAction("  top button", map.topButton)
    printAction("  scroll button", map.scrollButton)
    printAction("  tilt left", map.tiltLeft)
    printAction("  tilt right", map.tiltRight)
}

func printAction(_ label: String, _ action: Action) {
    let desc: String
    switch action {
    case .keystroke(let mods, let key):
        var parts: [String] = []
        if mods.contains(.maskCommand) { parts.append("Cmd") }
        if mods.contains(.maskControl) { parts.append("Ctrl") }
        if mods.contains(.maskShift) { parts.append("Shift") }
        if mods.contains(.maskAlternate) { parts.append("Opt") }
        parts.append("0x\(String(key, radix: 16))")
        desc = parts.joined(separator: "+")
    case .middleClick:
        desc = "MiddleClick"
    case .laserPointer:
        desc = "LaserPointer"
    case .missionControl:
        desc = "MissionControl"
    case .none:
        desc = "(none)"
    }
    print("\(label) → \(desc)")
}
