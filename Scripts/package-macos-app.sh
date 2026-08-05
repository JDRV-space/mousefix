#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

swift build -c release --only-use-versions-from-resolved-file

binary_directory="$(swift build -c release --show-bin-path)"
binary_path="$binary_directory/MouseFix"
app_path="$binary_directory/MouseFix.app"
staging_directory="$(mktemp -d "$repository_root/.build/mousefix-package.XXXXXX")"
staged_app="$staging_directory/MouseFix.app"

cleanup() {
    rm -rf -- "$staging_directory"
}
trap cleanup EXIT

version_output="$("$binary_path" version)"
version="${version_output##* }"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Unexpected MouseFix version output: $version_output" >&2
    exit 1
fi

source_revision="$(git rev-parse HEAD)"
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
    source_revision="${source_revision}-dirty"
fi

mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
install -m 0755 "$binary_path" "$staged_app/Contents/MacOS/MouseFix"
install -m 0644 LICENSE NOTICE THIRD_PARTY_NOTICES "$staged_app/Contents/Resources/"

info_plist="$staged_app/Contents/Info.plist"
plutil -create xml1 "$info_plist"
plutil -insert CFBundleDisplayName -string MouseFix "$info_plist"
plutil -insert CFBundleExecutable -string MouseFix "$info_plist"
plutil -insert CFBundleIdentifier -string space.jdrv.mousefix "$info_plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$info_plist"
plutil -insert CFBundleName -string MouseFix "$info_plist"
plutil -insert CFBundlePackageType -string APPL "$info_plist"
plutil -insert CFBundleShortVersionString -string "$version" "$info_plist"
plutil -insert CFBundleVersion -string "$version" "$info_plist"
plutil -insert LSMinimumSystemVersion -string 13.0 "$info_plist"
plutil -insert LSUIElement -bool true "$info_plist"
plutil -insert MouseFixSourceRevision -string "$source_revision" "$info_plist"
plutil -insert NSHighResolutionCapable -bool true "$info_plist"
plutil -insert NSInputMonitoringUsageDescription \
    -string "MouseFix reads mouse buttons and scroll input for local remapping." \
    "$info_plist"

plutil -lint "$info_plist"
codesign --force --sign - --timestamp=none "$staged_app"
codesign --verify --deep --strict "$staged_app"

if [[ -e "$app_path" ]]; then
    rm -rf -- "$app_path"
fi
mv "$staged_app" "$app_path"

echo "Created $app_path"
