#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/.build/artifacts.noindex"
ISOLATION="$ROOT/Scripts/build_isolation.py"
python3 "$ISOLATION" prepare --root "$ROOT" >/dev/null
DERIVED="${DEVPOCKET_DERIVED_DATA:-$BUILD/DerivedData}"
DERIVED="$(python3 -c 'from pathlib import Path; import sys; p=Path(sys.argv[2]); print((p if p.is_absolute() else Path(sys.argv[1])/p).resolve())' "$ROOT" "$DERIVED")"
mkdir -p "$BUILD"
STAGING=""
cleanup() {
    local code=$?
    trap - EXIT
    if ! python3 "$ISOLATION" cleanup --root "$ROOT"; then
        [[ "$code" -ne 0 ]] || code=1
    fi
    if [[ -n "$STAGING" ]]; then rm -rf "$STAGING"; fi
    exit "$code"
}
trap cleanup EXIT
ICON="$ROOT/DevPocket/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
if [ ! -f "$ICON" ] || [ "$ROOT/Scripts/GenerateIcon.swift" -nt "$ICON" ]; then
    xcrun swiftc -module-cache-path "$BUILD/ModuleCache" "$ROOT/Scripts/GenerateIcon.swift" -o "$BUILD/GenerateIcon"
    "$BUILD/GenerateIcon" "$ROOT/DevPocket/Assets.xcassets/AppIcon.appiconset"
fi
printf 'Building DevPocket for Apple Silicon and Intel…\n'
if ! python3 "$ISOLATION" exec --root "$ROOT" --lane release -- xcodebuild -project "$ROOT/DevPocket.xcodeproj" -scheme DevPocket -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build > "$BUILD/build.log" 2>&1; then
    tail -n 90 "$BUILD/build.log" >&2
    exit 1
fi
STAGING="$(mktemp -d "$BUILD/app.XXXXXX")"
ditto "$DERIVED/Build/Products/Release/DevPocket.app" "$STAGING/DevPocket.app"
codesign --force --sign - "$STAGING/DevPocket.app"
codesign --verify --deep --strict "$STAGING/DevPocket.app"
ARCHITECTURES="$(xcrun lipo -archs "$STAGING/DevPocket.app/Contents/MacOS/DevPocket")"
for architecture in arm64 x86_64; do
    case " $ARCHITECTURES " in *" $architecture "*) ;; *) echo "Missing $architecture" >&2; exit 1 ;; esac
done
rm -rf "$BUILD/DevPocket.app"
mv "$STAGING/DevPocket.app" "$BUILD/DevPocket.app"
printf 'Intermediate app: %s/DevPocket.app (%s). Install the DMG from dist/.\n' "$BUILD" "$ARCHITECTURES"
