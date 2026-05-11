#!/usr/bin/env bash
# Build Bielik2DWebDemo as a WebAssembly + JS bundle via the PackageToJS
# plugin shipped with JavaScriptKit. Requires:
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

SWIFT_BIN="$(command -v swift || true)"
if [ -z "$SWIFT_BIN" ] || [[ "$SWIFT_BIN" == /usr/bin/swift ]] || [[ "$SWIFT_BIN" == /Applications/Xcode*.app/* ]]; then
    echo "active swift is '${SWIFT_BIN:-not found}', which doesn't support wasm32." >&2
    echo "Install a swift.org toolchain (see header of this script)." >&2
    exit 1
fi

echo "==> running PackageToJS plugin for Bielik2DWebDemo (sdk: $SDK_ID)"
swift package --swift-sdk "$SDK_ID" \
    --disable-sandbox \
    js -c release --product Bielik2DWebDemo --output "$DIST"

echo "==> copying shader resources"
mkdir -p "$DIST/shaders"
cp Sources/Bielik2D/Resources/shaders/*.wgsl "$DIST/shaders/"

if [ ! -f "$DIST/index.html" ]; then
    echo "==> installing minimal host page"
    cp web/index.html "$DIST/index.html"
fi

ls -lh "$DIST/"
