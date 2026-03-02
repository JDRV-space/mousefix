<div align="center">

<img src="./assets/header.svg" alt="MouseFix" width="100%"/>

<br/>

[![Swift](https://img.shields.io/badge/Swift_5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![macOS](https://img.shields.io/badge/macOS_13+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**Ditch Logi Options+. Keep every button.**

Open-source MX Master 4 remapper. Config-file driven, zero telemetry, no cloud account.

</div>

---

## What It Does

| Feature | Description |
|---------|-------------|
| **Button Remapping** | Map any MX Master button to any keyboard shortcut via YAML config |
| **Gesture Engine** | Tap gesture button for App Switcher, hold+swipe for Spaces/Expose |
| **Tilt Scroll** | Horizontal scroll wheel tilt fires Cmd+[ / Cmd+] (tab switching) |
| **Laser Pointer** | Hold scroll button to project a colored circle overlay on screen |
| **Haptic Feedback** | HID++ protocol sends haptic pulses to the mouse on Space switch |
| **Discovery Mode** | `mousefix discover` logs every button press with its macOS button number |


## Quick Start

### Install

```bash
git clone https://github.com/JDRV-space/mousefix.git
cd mousefix
swift build -c release
cp .build/release/MouseFix /usr/local/bin/mousefix
```

### Grant Permissions

System Settings > Privacy & Security:
- **Accessibility** - for CGEvent tap (intercepting mouse events)
- **Input Monitoring** - for reading mouse button presses

### Discover Your Buttons

Button numbers vary by device and connection method. Run discovery first:

```bash
mousefix discover
# Press each button on your mouse
# Output: [discover] Button DOWN - number: 3
```

### Configure

```bash
mkdir -p ~/.config/mousefix
cp config.example.yaml ~/.config/mousefix/config.yaml
# Edit config.yaml to match your button numbers
```

### Run

```bash
mousefix         # starts the daemon (default)
mousefix run     # same as above
mousefix help    # show all commands
```

Stop with `Ctrl+C`.


## Config

```yaml
# ~/.config/mousefix/config.yaml

default:
  button3: "MiddleClick"              # Middle click
  button4: "Cmd+Z"                    # Back thumb -> Undo
  button5: "Cmd+Shift+Z"             # Forward thumb -> Redo
  button6: "Cmd+Space"               # Third thumb -> Spotlight
  gesture_click: "Cmd+Tab"           # Gesture tap -> App Switcher
  gesture_hold_left: "Ctrl+Left"     # Gesture+left -> Space left (+ haptic)
  gesture_hold_right: "Ctrl+Right"   # Gesture+right -> Space right (+ haptic)
  gesture_hold_up: "Ctrl+Down"       # Gesture+up -> App Expose
  top_button: "Cmd+Shift+4"          # Top button -> Screenshot
  scroll_button: "LaserPointer"      # Below scroll -> Laser pointer (hold)
  tilt_left: "Cmd+["                 # Tilt left -> Previous tab
  tilt_right: "Cmd+]"               # Tilt right -> Next tab
```

### Action Types

| Action | Effect |
|--------|--------|
| `"Cmd+Z"` | Any keyboard shortcut with modifiers |
| `"MiddleClick"` | Pass through as native middle click |
| `"LaserPointer"` | Show laser pointer circle while held |
| `"MissionControl"` | Trigger Mission Control |
| `"None"` | Disable the button entirely |

### Supported Modifiers

`Cmd`, `Ctrl`, `Shift`, `Opt` (also accepts `Command`, `Control`, `Option`, `Alt`)

### Supported Keys

Letters `A-Z`, numbers `0-9`, symbols `[ ] ; ' , . / \ - =`, arrows `Left Right Up Down`, function keys `F1-F15`, special keys `Space Tab Return Escape Delete Home End PageUp PageDown`


## Architecture

```
Sources/MouseFix/
  main.swift            CLI entry, arg parsing, daemon loop, signal handling
  EventTap.swift        CGEvent tap - intercepts otherMouse + scrollWheel events
  KeySynth.swift        Parses "Cmd+Z" strings, synthesizes CGEvent keystrokes
  GestureEngine.swift   Gesture button hold + mouse delta -> directional actions
  HapticEngine.swift    IOKit HID manager + HID++ protocol for haptic feedback
  LaserPointer.swift    NSWindow overlay - transparent circle follows cursor
  Config.swift          YAML config loading via Yams
  ButtonMap.swift       Button number -> Action enum mapping
```

### How It Works

1. **CGEvent tap** intercepts all `otherMouseDown`, `otherMouseUp`, and `scrollWheel` events at the session level
2. Each event's button number is looked up in the **ButtonMap** to find the configured action
3. The original mouse event is **suppressed** and a synthesized keyboard event is posted via `CGEvent.post`
4. **Gesture detection**: when the gesture button is held, mouse movement deltas accumulate until a directional threshold (50px) is exceeded
5. **Tilt scroll**: horizontal axis delta on scrollWheel events fires tab-switch keystrokes with 80ms debounce
6. **Haptic feedback**: on Space-switch gestures, a HID++ short report is sent to the MX Master via IOKit
7. **Laser pointer**: a borderless `NSWindow` at `.screenSaver` level tracks mouse position while the scroll button is held


## Requirements

- macOS 13+ (Ventura or later)
- Swift 5.9+
- Logitech MX Master 4 (other mice work for basic remapping - button numbers may differ)


## Roadmap

- [ ] Per-app profiles (different mappings per frontmost app)
- [ ] `mousefix edit` - opens config in `$EDITOR`
- [ ] LaunchAgent for auto-start on login
- [ ] Homebrew formula
- [ ] Optional menu bar icon


## License

[MIT](LICENSE)
