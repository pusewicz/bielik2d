#!/usr/bin/env bash
# Install everything scripts/build-web.sh needs:
#   1. swiftly (Swift toolchain manager)
#   2. Swift 6.3 toolchain via swiftly (Xcode's swift lacks wasm32 backend)
#   3. The Swift SDK for WebAssembly (wasm32-unknown-wasip1)
#
# Idempotent: each step skips if already installed.
set -euo pipefail

SWIFT_VERSION="6.3"
SDK_ID="swift-6.3-RELEASE_wasm"
SDK_URL="https://download.swift.org/swift-6.3-release/wasm-sdk/swift-6.3-RELEASE/swift-6.3-RELEASE_wasm.artifactbundle.tar.gz"
SDK_CHECKSUM="9fa4016ee632c7e9e906608ec3b55cf13dfc4dff44e47574c5af58064dc33fd9"

SWIFTLY_BIN="$HOME/.swiftly/bin"
export PATH="$SWIFTLY_BIN:$PATH"

# --- 1. swiftly ----------------------------------------------------------------
if ! command -v swiftly >/dev/null 2>&1; then
    echo "==> installing swiftly"
    case "$(uname -s)" in
        Darwin)
            TMP_PKG="$(mktemp -t swiftly).pkg"
            curl -fsSL -o "$TMP_PKG" "https://download.swift.org/swiftly/darwin/swiftly.pkg"
            installer -pkg "$TMP_PKG" -target CurrentUserHomeDirectory
            rm -f "$TMP_PKG"
            "$HOME/usr/local/bin/swiftly" init --quiet-shell-followup --assume-yes --no-modify-profile || \
                "$SWIFTLY_BIN/swiftly" init --quiet-shell-followup --assume-yes --no-modify-profile
            ;;
        *)
            echo "automatic swiftly install only wired up for macOS; see https://www.swift.org/swiftly/" >&2
            exit 1
            ;;
    esac
else
    echo "==> swiftly already installed"
fi

# --- 2. Swift toolchain --------------------------------------------------------
if ! swiftly list 2>/dev/null | grep -q "$SWIFT_VERSION"; then
    echo "==> installing Swift $SWIFT_VERSION via swiftly"
    swiftly install "$SWIFT_VERSION"
else
    echo "==> Swift $SWIFT_VERSION already installed via swiftly"
fi

swiftly use --global-default "$SWIFT_VERSION" >/dev/null 2>&1 || true

# --- 3. wasm SDK ---------------------------------------------------------------
if swift sdk list 2>/dev/null | grep -qx "$SDK_ID"; then
    echo "==> $SDK_ID already installed"
else
    echo "==> installing $SDK_ID"
    swift sdk install "$SDK_URL" --checksum "$SDK_CHECKSUM"
fi

echo
echo "==> done. Make sure $SWIFTLY_BIN is on your PATH before running scripts/build-web.sh"
swift --version
swift sdk list
