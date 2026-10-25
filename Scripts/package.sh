#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --skip-build ]; }; then
    printf 'Usage: bash Scripts/package.sh [--skip-build]\n' >&2
    exit 2
fi
if [ "${1:-}" != --skip-build ]; then bash "$ROOT/Scripts/build.sh"; fi
APP="$ROOT/build/DevPocket.app"
codesign --verify --deep --strict "$APP"
ARCHITECTURES="$(xcrun lipo -archs "$APP/Contents/MacOS/DevPocket")"
for architecture in arm64 x86_64; do
    case " $ARCHITECTURES " in *" $architecture "*) ;; *) echo "Missing $architecture" >&2; exit 1 ;; esac
done
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
mkdir -p "$ROOT/dist"
WORK="$(mktemp -d "$ROOT/build/package.XXXXXX")"
MOUNT=""
cleanup() {
    if [ -n "$MOUNT" ]; then
        hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
        rmdir "$MOUNT" 2>/dev/null || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT
mkdir "$WORK/contents"
ditto "$APP" "$WORK/contents/DevPocket.app"
ln -s /Applications "$WORK/contents/Applications"
hdiutil create -volname DevPocket -srcfolder "$WORK/contents" -format UDZO -fs HFS+ \
    -ov "$WORK/DevPocket.dmg" >/dev/null
hdiutil verify "$WORK/DevPocket.dmg" >/dev/null
MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/DevPocket-mount.XXXXXX")"
hdiutil attach "$WORK/DevPocket.dmg" -readonly -nobrowse -mountpoint "$MOUNT" >/dev/null
codesign --verify --deep --strict "$MOUNT/DevPocket.app"
COPIED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT/DevPocket.app/Contents/Info.plist")"
[ "$COPIED_VERSION" = "$VERSION" ]
[ "$(readlink "$MOUNT/Applications")" = /Applications ]
hdiutil detach "$MOUNT" >/dev/null
rmdir "$MOUNT"
MOUNT=""
mv -f "$WORK/DevPocket.dmg" "$ROOT/dist/DevPocket.dmg"
(cd "$ROOT/dist" && shasum -a 256 DevPocket.dmg > DevPocket.dmg.sha256 && shasum -a 256 -c DevPocket.dmg.sha256)
printf 'Packaged DevPocket %s: %s/dist/DevPocket.dmg\n' "$VERSION" "$ROOT"
