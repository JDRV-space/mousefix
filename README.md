<div align="center">

<img src="./assets/header.svg" alt="MouseFix" width="100%"/>

<br/>

[![Swift](https://img.shields.io/badge/Swift_5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![macOS](https://img.shields.io/badge/macOS_13+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**Ditch Logi Options+. Keep every button.**

Open-source mouse button remapper for macOS. YAML config, zero telemetry, no cloud account.<br/>
Built for the MX Master 4, works with any multi-button mouse.

</div>

---

## Features

| Feature | Description |
|---------|-------------|
| **Button Remapping** | Map any mouse button to any keyboard shortcut |
| **Gesture Engine** | Hold a button + swipe mouse for directional actions (Spaces, Expose) |
| **Tilt Scroll** | Horizontal scroll wheel tilt fires tab switching |
| **Laser Pointer** | Hold a button to project a colored circle on screen |
| **Haptic Feedback** | Logitech HID++ protocol sends vibration pulses to the mouse |
| **Discovery Mode** | `mousefix discover` shows what number each button reports |
| **Any Mouse** | Config maps raw button numbers to actions - works with any device |


## Quick Start

### 1. Build

```bash
git clone https://github.com/JDRV-space/mousefix.git
cd mousefix
swift build -c release
cp .build/release/MouseFix /usr/local/bin/mousefix
```

### 2. Permissions

MouseFix needs two macOS permissions to intercept and remap mouse events:

**System Settings > Privacy & Security > Accessibility**
Add your terminal app (Terminal, iTerm, Warp, etc.) or the MouseFix binary.

**System Settings > Privacy & Security > Input Monitoring**
Same as above. macOS will prompt you the first time you run MouseFix.

### 3. Run

```bash
mousefix
```

That's it. Your MX Master 4 buttons are now remapped with the defaults below. Stop with `Ctrl+C`.

### Default Mappings (MX Master 4)

These are the out-of-the-box mappings. They work immediately if you have an MX Master 4 connected via Bluetooth.

| Button | Action |
|--------|--------|
| Middle click | MiddleClick (unchanged) |
| Back thumb | Cmd+Z (Undo) |
| Forward thumb | Cmd+Shift+Z (Redo) |
| Third thumb | Cmd+Space (Spotlight) |
| Top button | Cmd+Shift+4 (Screenshot) |
| Below scroll | LaserPointer (hold to show) |

| Gesture (third thumb) | Action |
|------------------------|--------|
| Tap | Cmd+Tab (App Switcher) |
| Hold + swipe left | Ctrl+Left (Space left + haptic) |
| Hold + swipe right | Ctrl+Right (Space right + haptic) |
| Hold + swipe up | Ctrl+Down (App Expose) |

| Tilt Scroll | Action |
|-------------|--------|
| Tilt left | Cmd+[ (Previous tab) |
| Tilt right | Cmd+] (Next tab) |

> The gesture button (third thumb) has dual behavior: quick tap fires App Switcher, hold+swipe fires directional actions. When gesture mode is enabled for a button, it replaces that button's direct action.


## Customizing

### Edit the config

```bash
mkdir -p ~/.config/mousefix
cp config.example.yaml ~/.config/mousefix/config.yaml
```

Open `~/.config/mousefix/config.yaml` in any editor. The format maps macOS button numbers directly to actions:

```yaml
# Map button numbers to actions
buttons:
  2: "MiddleClick"          # Middle click
  3: "Cmd+Z"                # Back thumb -> Undo
  4: "Cmd+Shift+Z"          # Forward thumb -> Redo
  5: "Cmd+Space"             # Third thumb -> Spotlight
  6: "Cmd+Shift+4"          # Top button -> Screenshot
  7: "LaserPointer"          # Below scroll -> Laser pointer

# Gesture: hold a button and swipe
gesture:
  button: 5                  # Which button triggers gestures
  click: "Cmd+Tab"           # Tap -> App Switcher
  hold_left: "Ctrl+Left"    # Swipe left -> Space left
  hold_right: "Ctrl+Right"  # Swipe right -> Space right
  hold_up: "Ctrl+Down"      # Swipe up -> Expose

# Horizontal scroll tilt
tilt_scroll:
  left: "Cmd+["             # Tilt left -> Previous tab
  right: "Cmd+]"            # Tilt right -> Next tab
```

### Using a different mouse

If you're not using an MX Master 4, your button numbers might be different. Run discovery mode to find them:

```bash
mousefix discover
```

Press each button on your mouse. The output shows the number macOS assigns to it:

```
[discover] Button DOWN - number: 3
[discover] Button UP   - number: 3
```

Then edit your config to use those numbers. Any mouse with extra buttons (3+) works for button remapping. Gesture detection and tilt scroll work with any mouse. Haptic feedback is Logitech-only (HID++ protocol).

### Action types

| Action | What it does |
|--------|-------------|
| `"Cmd+Z"` | Any keyboard shortcut. Modifiers: `Cmd`, `Ctrl`, `Shift`, `Opt` |
| `"MiddleClick"` | Native middle click passthrough |
| `"LaserPointer"` | Red circle overlay follows cursor while button is held |
| `"MissionControl"` | Triggers Mission Control (Ctrl+Up) |
| `"None"` | Disables the button |

### Supported keys

`A-Z`, `0-9`, `[ ] ; ' , . / \ - =`, `Left Right Up Down`, `F1-F15`, `Space Tab Return Escape Delete Home End PageUp PageDown`


## CLI

```
mousefix              Run the daemon (default)
mousefix run          Same as above
mousefix discover     Log button numbers for all mouse events
mousefix help         Show help
mousefix version      Show version
```


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

### How it works

1. **CGEvent tap** intercepts `otherMouseDown/Up` and `scrollWheel` events at the session level
2. Button number is looked up in the config to find the mapped action
3. Original mouse event is suppressed and a synthesized keyboard event is posted
4. **Gesture detection**: when the gesture button is held, mouse deltas accumulate until a 50px threshold triggers a directional action
5. **Tilt scroll**: horizontal scrollWheel delta fires tab-switch keystrokes with 80ms debounce
6. **Haptic**: HID++ short report sent to the mouse via IOKit on Space-switch gestures
7. **Laser pointer**: borderless NSWindow at `.screenSaver` level tracks cursor position


## Requirements

- macOS 13+ (Ventura or later)
- Swift 5.9+
- Any multi-button mouse (MX Master 4 defaults built-in, haptic feedback Logitech-only)


## Roadmap

- [ ] Per-app profiles (different mappings per frontmost app)
- [ ] `mousefix edit` opens config in $EDITOR
- [ ] LaunchAgent for auto-start on login
- [ ] Homebrew formula
- [ ] Optional menu bar icon


## License

[MIT](LICENSE)
