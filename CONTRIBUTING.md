# Contributing To MouseFix

Open a GitHub issue before a large behavioral or packaging change so scope and
hardware expectations are explicit. Small, focused fixes can go directly to a
pull request.

GitHub Issues owns current bugs, planned support, and release gaps. Keep stable
behavior and contracts in their code or documentation owners.

## Required Checks

```bash
swift build --only-use-versions-from-resolved-file
swift run --only-use-versions-from-resolved-file MouseFixCoreChecks
swift test --only-use-versions-from-resolved-file
./Scripts/package-macos-app.sh
```

Follow the source-of-truth boundaries in `README.md`. Update an existing owner
instead of adding progress notes or competing guides.

For changes to input routing, permissions, overlays, private APIs, HID++ control,
or receiver support, describe the macOS version, mouse firmware, connection
mode, and manual hardware checks performed. Automated checks are not a substitute
for real input testing.

Report security vulnerabilities privately as described in
[SECURITY.md](SECURITY.md).
