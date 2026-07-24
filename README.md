# MouseFix

MouseFix is a small macOS tool for remapping extra mouse buttons from a YAML file.

I wrote it for an MX Master 4 because I wanted button remapping without keeping Logitech's app running. It is not a full mouse control panel. You build it yourself, grant macOS permissions, and edit the config when your mouse reports different button numbers.

## What It Does

- Intercepts extra mouse buttons and horizontal scroll-wheel tilt with a `CGEvent` tap.
- Maps those inputs to keyboard shortcuts, middle click, a laser-pointer overlay, Mission Control, App Expose, or Show Desktop.
- Supports one hold-and-swipe gesture button.
- Tries to send Logitech HID++ haptic pulses for left/right gesture actions.

## Build And Install

```bash
git clone https://github.com/JDRV-space/mousefix.git
cd mousefix
swift build -c release

mkdir -p /Applications/MouseFix.app/Contents/MacOS
cp .build/release/MouseFix /Applications/MouseFix.app/Contents/MacOS/MouseFix
```

`Package.resolved` pins the reviewed dependency revision. Use
`swift build --only-use-versions-from-resolved-file` in reproducible builds.

This creates a minimal unsigned app bundle. There is no signed or notarized app release in this repo.

Run it:

```bash
/Applications/MouseFix.app/Contents/MacOS/MouseFix
```

Run discovery mode:

```bash
/Applications/MouseFix.app/Contents/MacOS/MouseFix discover
```

If you put the binary on your `PATH` as `mousefix`, use `mousefix` instead of the full path.

## Permissions

MouseFix needs Accessibility permission or the event tap will not start.

Open **System Settings > Privacy & Security > Accessibility**, click **+**, and add `/Applications/MouseFix.app`.

If macOS also asks for Input Monitoring, allow it there too. The permission is tied to the app or binary path, so running from `.build/release/MouseFix` may require a separate approval.

## Local Input And Security Caveats

MouseFix runs locally and posts synthetic keyboard and mouse events through macOS APIs after you grant Accessibility permission. Treat the config file as trusted input. Do not run mappings copied from someone else without reading them, because a mapping can trigger shortcuts in the foreground app.

MouseFix does not install a privileged helper, does not bypass macOS privacy prompts, and does not provide remote control. Discovery mode logs local mouse button numbers to stdout.

`MissionControl`, `AppExpose`, and `ShowDesktop` use private CoreDock notifications. They are isolated in the executable runtime code, but they are still private macOS behavior and can stop working after an OS update.

Haptic feedback is experimental Logitech HID++ output. The current implementation sends a feature query, then uses a hardcoded feature index seen on common MX Master firmware instead of reading and validating the HID++ response. If you do not want MouseFix to send haptic reports, set `haptic.device` to a string that does not match any connected Logitech device.

## Config

MouseFix reads:

```text
~/.config/mousefix/config.yaml
```

If that file is missing, it uses the built-in MX Master 4 defaults.

To customize:

```bash
mkdir -p ~/.config/mousefix
cp config.example.yaml ~/.config/mousefix/config.yaml
```

Edit `~/.config/mousefix/config.yaml`:

```yaml
buttons:
  2: "MiddleClick"
  3: "Cmd+Z"
  4: "Cmd+Shift+Z"
  5: "Cmd+Shift+4"
  6: "Cmd+Space"
  7: "LaserPointer"

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
```

Left click (`0`) and right click (`1`) are not meant to be remapped. When `gesture.button` is enabled, that button uses the gesture tap/hold behavior instead of its direct `buttons` action.

### Action Names

- Keyboard shortcuts: `"Cmd+Z"`, `"Cmd+Shift+4"`, `"Ctrl+Right"`, etc.
- Modifiers: `Cmd`, `Ctrl`, `Shift`, `Opt`.
- Special actions: `MiddleClick`, `LaserPointer`, `MissionControl`, `AppExpose`, `ShowDesktop`, `None`.
- Supported keys: `A-Z`, `0-9`, `[ ] ; ' , . / \ - =`, `Left`, `Right`, `Up`, `Down`, `F1-F15`, `Space`, `Tab`, `Return`, `Escape`, `Delete`, `Home`, `End`, `PageUp`, `PageDown`.

## Default Mappings

These defaults are for an MX Master 4 connected over Bluetooth. Button numbers can change with a different mouse, receiver, connection mode, or firmware.

- Button `2`: middle click.
- Button `3`: `Cmd+Z`.
- Button `4`: `Cmd+Shift+Z`.
- Button `5`: `Cmd+Shift+4`.
- Button `6`: gesture button. Tap sends `Cmd+Tab`; hold and move left/right sends `Ctrl+Right` or `Ctrl+Left`; hold and move up/down sends `MissionControl` or `AppExpose`.
- Button `7`: laser pointer while held.
- Horizontal tilt left/right: left/right arrow keypresses, repeated based on scroll delta.

To find your mouse's numbers:

```bash
/Applications/MouseFix.app/Contents/MacOS/MouseFix discover
```

Press each button. Discovery output looks like:

```text
[discover] Button DOWN - number: 3
[discover] Button UP   - number: 3
```

Then put those numbers in `~/.config/mousefix/config.yaml`.

## CLI

```text
MouseFix              Run the daemon
MouseFix run          Same as above
MouseFix discover     Log button numbers for mouse events
MouseFix help         Show help
MouseFix version      Show version
```

Use the full installed path unless you added `MouseFix` or `mousefix` to your `PATH`.

## Local Validation

Build the package:

```bash
swift build
```

Run deterministic parser/config checks:

```bash
swift run MouseFixCoreChecks
```

This repo uses `MouseFixCoreChecks` as a framework-free check executable, not a SwiftPM test target. That keeps validation runnable on Command Line Tools installations where `XCTest` or Swift `Testing` are unavailable. `swift test` currently reports no tests found.

The check target covers action parsing, YAML button keys, gesture mappings, tilt mappings, haptic device parsing, and invalid YAML fallback. It does not test event taps, Accessibility prompts, synthetic input delivery, CoreDock notifications, AppKit overlay behavior, or Logitech HID++ haptics. Those still require manual hardware testing on macOS.

## Architecture

```text
Sources/MouseFix/
  main.swift            CLI entry, daemon loop, menu bar item, signal handling
  ActionRunner.swift    Runtime action execution through local input and CoreDock APIs
  EventTap.swift        Session `CGEvent` tap for otherMouse and scrollWheel events
  GestureEngine.swift   Hold button plus mouse movement into directional actions
  HapticEngine.swift    IOKit HID manager and Logitech HID++ reports
  LaserPointer.swift    Transparent NSWindow overlay that follows the cursor

Sources/MouseFixCore/
  ButtonMap.swift       Action model and button number to action mapping
  Config.swift          YAML config loading through Yams
  KeySynth.swift        Action string parser and keycode lookup

Tests/MouseFixCoreChecks/
  main.swift            Framework-free parser/config check executable
```

Event flow:

1. `EventTap` receives `otherMouseDown`, `otherMouseUp`, movement, and horizontal `scrollWheel` events.
2. The raw button number or scroll delta is looked up in `ButtonMap`.
3. MouseFix suppresses the original event when it handles a mapping.
4. `ActionRunner`, `GestureEngine`, `LaserPointer`, or `HapticEngine` performs the configured action.

## Limitations

- Accessibility permission is required. Without it, MouseFix does not work.
- Raw button numbers are not stable across all mice, receivers, connection modes, or firmware. Use discovery mode.
- `MissionControl`, `AppExpose`, and `ShowDesktop` use private CoreDock notifications. Apple can break them in a macOS update.
- Haptics are Logitech HID++ only, best effort, use a hardcoded feature index after a feature query, and may fail on some firmware or receiver setups.
- Automated checks cover config/action parsing only. Event tap behavior, synthetic input delivery, overlay behavior, and haptics require manual macOS hardware testing.
- There is no signed or notarized app here. You are running an unsigned local build.
- There is no installer, updater, login item, or GUI config editor.

## Requirements

- macOS 13 or newer.
- Swift 5.9 or newer.
- A multi-button mouse for button remapping.

## License

Apache License 2.0. See [LICENSE](LICENSE).

Attribution notices are listed in [NOTICE](NOTICE).
