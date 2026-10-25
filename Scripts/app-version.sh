#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(xcodebuild -project "$ROOT/DevPocket.xcodeproj" \
    -scheme DevPocket -configuration Release -destination 'generic/platform=macOS' \
    -showBuildSettings CODE_SIGNING_ALLOWED=NO | \
    awk '$1 == "MARKETING_VERSION" && $2 == "=" { version = $3 } END { if (version == "") exit 1; print version }')"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Invalid MARKETING_VERSION: %s\n' "$VERSION" >&2
    exit 1
fi
printf '%s\n' "$VERSION"
