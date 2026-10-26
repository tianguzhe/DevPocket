#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/DevPocket-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
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
