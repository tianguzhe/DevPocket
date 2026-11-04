#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISOLATION="$ROOT/Scripts/build_isolation.py"
python3 "$ISOLATION" prepare --root "$ROOT" >/dev/null
TEST_ROOT="$ROOT/.build/artifacts.noindex/tests"
mkdir -p "$TEST_ROOT"
TEST_DIR="$(mktemp -d "$TEST_ROOT/run.XXXXXX")"
cleanup() {
    local code=$?
    trap - EXIT
    if ! python3 "$ISOLATION" cleanup --root "$ROOT"; then
        [[ "$code" -ne 0 ]] || code=1
    fi
    rm -rf "$TEST_DIR"
    exit "$code"
}
trap cleanup EXIT
for script in "$ROOT"/Scripts/*.sh; do bash -n "$script"; done
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_DIR/ModuleCache" \
    "$ROOT/DevPocket/ToolEngine.swift" "$ROOT/DevPocket/AESEngine.swift" "$ROOT/DevPocket/QRCodeEngine.swift" \
    "$ROOT/Tests/ToolEngineTests.swift" -o "$TEST_DIR/Tests"
"$TEST_DIR/Tests"
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_DIR/ModuleCache" \
    "$ROOT/DevPocket/ToolEngine.swift" "$ROOT/DevPocket/AESEngine.swift" "$ROOT/DevPocket/QRCodeEngine.swift" \
    "$ROOT/DevPocket/WorkspaceStore.swift" "$ROOT/Tests/WorkspaceStoreTests.swift" -o "$TEST_DIR/WorkspaceTests"
"$TEST_DIR/WorkspaceTests"
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_DIR/ModuleCache" \
    "$ROOT/DevPocket/ToolEngine.swift" "$ROOT/DevPocket/AESEngine.swift" "$ROOT/DevPocket/QRCodeEngine.swift" \
    "$ROOT/Tests/QRCodeEngineTests.swift" -o "$TEST_DIR/QRCodeTests"
"$TEST_DIR/QRCodeTests"
