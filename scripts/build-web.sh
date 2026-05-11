#!/usr/bin/env bash
# Build the Bielik2DWebDemo target for WebAssembly using the Swift SDK
# for WebAssembly. Requires `swiftly install 6.3` and the wasm SDK:
#
#   swift sdk install \
#     https://download.swift.org/swift-6.3-release/wasm-sdk/swift-6.3-RELEASE/swift-6.3-RELEASE_wasm.artifactbundle.tar.gz \
#     --checksum 9fa4016ee632c7e9e906608ec3b55cf13dfc4dff44e47574c5af58064dc33fd9
#
# After install, `swift sdk list` should show the wasm SDK ID (typically
# something like "swift-6.3-RELEASE-wasm32-unknown-wasi").

set -euo pipefail

cd "$(dirname "$0")/.."

SDK_ID="${BIELIK2D_WASM_SDK:-swift-6.3-RELEASE-wasm32-unknown-wasi}"
DIST=web/dist
mkdir -p "$DIST"

echo "==> building Bielik2DWebDemo via Swift SDK '$SDK_ID'"
swift build --swift-sdk "$SDK_ID" --product Bielik2DWebDemo -c release

WASM=".build/wasm32-unknown-wasi/release/Bielik2DWebDemo.wasm"
if [ ! -f "$WASM" ]; then
    echo "build did not produce $WASM" >&2
    exit 1
fi
cp "$WASM" "$DIST/Bielik2DWebDemo.wasm"

if command -v wasm-opt >/dev/null 2>&1; then
    echo "==> optimising with wasm-opt"
    wasm-opt -Os "$DIST/Bielik2DWebDemo.wasm" -o "$DIST/Bielik2DWebDemo.wasm"
else
    echo "==> wasm-opt not on PATH; skipping size optimisation"
fi

ls -lh "$DIST/Bielik2DWebDemo.wasm"
