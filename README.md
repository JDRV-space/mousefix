# MouseFix

MouseFix is a local macOS input remapper built for the Logitech MX Master 4.
It keeps trackpad input native while adding mouse-specific smooth scrolling,
button mappings, gestures, side-wheel navigation, and a laser overlay.

Runtime behavior is owned by `Sources/`; build and dependency requirements are
owned by `Package.swift`, `Package.resolved`, and CI. The example config mirrors
compiled defaults; documentation and test results do not prove current hardware
support or external state.

## Support Status

| Area | Current contract |
|---|---|
| Runtime | The binary deployment target is macOS 13. This is not a hardware-tested support claim. |
| Build host | Building requires a macOS version supported by Xcode 26 or another Swift 6.2+ toolchain. CI uses a pinned macOS 15/Xcode 26 environment. |
| Build tools | Swift 6.2 or newer. CI's exact toolchain is authoritative in [the build workflow](.github/workflows/build.yml). |
| Mouse | The included profile targets the MX Master 4. Button numbers can differ by firmware and connection mode. |
| Connection | The HID++ laser control currently supports Bluetooth Low Energy only. Other button and scroll behavior over Logi Bolt or USB receivers is not hardware-verified. |
| Distribution | Source build only. No Developer ID-signed or notarized release is published. |

## Default Behavior

- Scroll wheel press: native middle click.
- Button `3`: `Cmd+Z`.
- Button `4`: hold Command. It combines with the physical keyboard, so holding
  the mouse button and pressing `R` sends `Cmd+R`.
- Button `5`: `Cmd+Shift+4` screenshot.
- Button `6`: tap for `Cmd+Tab`; hold and move left/right for the adjacent
  Space; hold and move up/down for Mission Control or App Expose.
- Side wheel: plain left/right arrow presses.
- Button below the scroll wheel: laser overlay while held when the mouse is
  connected over Bluetooth Low Energy. This uses HID++ control `0x00C4`.
- Main wheel: continuous, phased scrolling only for the configured Logitech
  mouse. Apple trackpad events pass through unchanged.

Use discovery mode before relying on the included button numbers.

## Build And Install

On a Mac that supports Xcode 26 or another Swift 6.2+ toolchain:

```bash
git clone https://github.com/JDRV-space/mousefix.git
cd mousefix
./Scripts/package-macos-app.sh
sudo ditto .build/release/MouseFix.app /Applications/MouseFix.app
open /Applications/MouseFix.app
```

The packaging script builds from `Package.resolved`, creates the required
`Info.plist`, embeds the source revision and license notices, applies a local
ad-hoc signature, and verifies the bundle. The result is not Developer ID-signed
or notarized. macOS 13 is a deployment target, not a supported build-host claim;
without a prebuilt release, an older target Mac needs a bundle built on a newer
compatible Mac.

Run the executable directly:

```bash
/Applications/MouseFix.app/Contents/MacOS/MouseFix
```

Run discovery mode:

```bash
/Applications/MouseFix.app/Contents/MacOS/MouseFix discover
```

Other CLI commands are `help` and `version`.

## Permissions

MouseFix needs Accessibility permission or its event tap cannot start.

Open **System Settings > Privacy & Security > Accessibility**, click **+**, and
add `/Applications/MouseFix.app`. If macOS requests Input Monitoring, allow the
same app there. Permissions are tied to the installed app identity and path. If
a rebuilt app stops receiving input, remove the old permission entry, add the
new app, and restart MouseFix.

## Configuration

MouseFix reads:

```text
~/.config/mousefix/config.yaml
```

Without that file, the compiled profile in
`Sources/MouseFixCore/Config.swift` is used. The versioned
[config.example.yaml](config.example.yaml) is the complete editable profile and
is tested for parity with those defaults.

A valid local YAML file replaces the complete profile. Omitted button, gesture,
and side-wheel mappings are not inherited. Invalid YAML falls back to compiled
defaults.

```bash
mkdir -p ~/.config/mousefix
cp config.example.yaml ~/.config/mousefix/config.yaml
```

Supported actions are documented inline in `config.example.yaml`. A modifier
without a key, such as `Cmd`, `Shift`, `Ctrl`, or `Opt`, remains active until
the mapped mouse button is released and can combine with physical keyboard or
primary mouse input.

Supported shortcut keys include `A-Z`, `0-9`, punctuation, arrow keys,
`F1-F15`, `Space`, `Tab`, `Return`, `Escape`, `Delete`, `Home`, `End`,
`PageUp`, and `PageDown`.

Scroll settings are clamped at parse time:

- `response`: `0...1`
- `speed`: `0.1...4`

## Security And Privacy

- MouseFix has no network client, telemetry, updater, login item, privileged
  helper, credential storage, or remote-control interface.
- The event tap receives key events so an active mouse-held modifier can be
  merged into them. The runtime does not inspect key codes or log, store, or
  transmit keyboard input.
- Discovery mode prints mouse button numbers and scroll metadata to stdout. It
  does not print keyboard input.
- The laser control uses temporary Logitech HID++ diversion. MouseFix reads the
  original diversion state and restores it on normal disable or shutdown. It
  does not write persistent firmware configuration.
- Haptic output is disabled until verified runtime feature discovery exists.
- The event callback returns borrowed CoreGraphics events without retaining
  them, preventing an input-rate memory leak.
- `Package.resolved` pins every Swift package dependency. CI uses that resolved
  file with read-only repository permissions.

Treat the YAML file as trusted local configuration. Mappings trigger shortcuts
in the foreground application.

MouseFix uses private macOS interfaces for CoreDock actions and physical HID
sender identification. These interfaces can change across macOS releases. If
sender identification is unavailable, MouseFix leaves the scroll event
unchanged.

Report vulnerabilities through the private process in [SECURITY.md](SECURITY.md),
not a public issue.

## Uninstall

1. Quit MouseFix from its menu bar item. Normal shutdown restores any temporary
   HID++ diversion state.
2. Move `/Applications/MouseFix.app` to Trash.
3. Optionally delete `~/.config/mousefix/config.yaml`.
4. Remove MouseFix from Accessibility and Input Monitoring in
   **System Settings > Privacy & Security**.

## Validation

```bash
swift build --only-use-versions-from-resolved-file
swift run --only-use-versions-from-resolved-file MouseFixCoreChecks
swift test --only-use-versions-from-resolved-file
./Scripts/package-macos-app.sh
```

The automated checks cover config parsing and profile parity, bounds, device
classification, held modifiers, arrow flags, side-wheel routing, smooth-scroll
physics and output fields, HID++ parsing, bundle metadata, and code signing.

Accessibility permission, overlay appearance, firmware behavior, receiver
compatibility, and real input delivery still require manual testing on macOS
hardware.

## Architecture

- `MouseFix` composes the menu-bar runtime, event routing, gestures, scrolling,
  overlays, and temporary HID++ control.
- `MouseFixCore` owns configuration parsing, the action model, shortcut
  parsing, and bounded scroll settings.
- `MouseFixHIDBridge` isolates the weakly linked physical-sender lookup.

Input flows from the event tap through device classification into either native
pass-through or a configured action. Private macOS and HID interfaces stay
behind their runtime boundaries so unavailable sender identification can fail
open without reshaping unrelated input.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and contribution scope.

## License

Apache License 2.0. See [LICENSE](LICENSE). Project attribution is in
[NOTICE](NOTICE), and dependency licenses are in
[THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).
