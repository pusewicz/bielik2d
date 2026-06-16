#!/usr/bin/env bash
# Build Bielik2DDemo (the unified native+web demo) as a WebAssembly + JS bundle
# via the PackageToJS plugin shipped with JavaScriptKit. Requires:
#
#   1. A swift.org toolchain (Xcode's bundled toolchain lacks the wasm32 backend).
#      The simplest install is via swiftly:
#          curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
#          swiftly install 6.3 && swiftly use 6.3
#
#   2. The wasm SDK matching the toolchain:
#          swift sdk install \
#              https://download.swift.org/swift-6.3.1-release/wasm-sdk/swift-6.3.1-RELEASE/swift-6.3.1-RELEASE_wasm.artifactbundle.tar.gz \
#              --checksum bd47baa20771f366d8beed7970afaa30742b2210097afd15f85427226d8f4cf2
#      Note the SDK id from `swift sdk list` and override BIELIK2D_WASM_SDK if it
#      differs from the default.
#
#   3. Asset assembly: shaders/PNGs are copied alongside the WASM so the browser
#      can `fetch()` them. Phase 17+ will list specific files; for the clear-
#      screen demo we only need the WGSL shaders.
set -euo pipefail

cd "$(dirname "$0")/.."

SDK_ID="${BIELIK2D_WASM_SDK:-swift-6.3.1-RELEASE_wasm}"
DIST=web/dist
mkdir -p "$DIST"

# Prefer a swiftly-managed toolchain if installed, since Xcode's bundled swift
# lacks the wasm32 backend. Caller can override by exporting PATH explicitly or
# setting BIELIK2D_SWIFT to a specific swift binary.
if [ -n "${BIELIK2D_SWIFT:-}" ]; then
    SWIFT_BIN="$BIELIK2D_SWIFT"
elif [ -x "$HOME/.swiftly/bin/swift" ]; then
    export PATH="$HOME/.swiftly/bin:$PATH"
    SWIFT_BIN="$HOME/.swiftly/bin/swift"
elif command -v swift >/dev/null 2>&1; then
    SWIFT_BIN="$(command -v swift)"
else
    echo "swift not on PATH — install a swift.org toolchain (see header)." >&2
    exit 1
fi

# Verify the wasm Swift SDK is installed. Cross-compilation happens through the
# SDK, not the host swiftc, so we just check that the requested SDK id exists.
if ! "$SWIFT_BIN" sdk list 2>/dev/null | grep -qx "$SDK_ID"; then
    echo "wasm SDK '$SDK_ID' is not installed." >&2
    echo "Run scripts/install-wasm-sdk.sh, or set BIELIK2D_WASM_SDK to a matching id." >&2
    "$SWIFT_BIN" sdk list 2>&1 | head -20 >&2 || true
    exit 1
fi

echo "==> running PackageToJS plugin for Bielik2DDemo (sdk: $SDK_ID)"
swift package --swift-sdk "$SDK_ID" \
    --disable-sandbox \
    js -c release --product Bielik2DDemo --output "$DIST"

echo "==> copying shader resources"
mkdir -p "$DIST/shaders"
cp Sources/Bielik2D/Resources/shaders/*.wgsl "$DIST/shaders/"

echo "==> copying demo assets"
mkdir -p "$DIST/assets"
cp Sources/Bielik2DDemo/assets/* "$DIST/assets/"

echo "==> installing host page"
cp web/index.html "$DIST/index.html"

ls -lh "$DIST/"
