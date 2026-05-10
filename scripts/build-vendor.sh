#!/usr/bin/env bash
# Build SDL_shadercross into vendor/.install/.
# Uses system SPIRV-Cross/Tools/Headers from Homebrew (brew install
# spirv-cross spirv-tools spirv-headers), and turns off DXC since dxc isn't
# in Homebrew. Shaders go HLSL → SPIR-V at build time via glslangValidator,
# then SPIR-V → MSL/DXIL/SPIR-V at runtime via shadercross.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/SDL_shadercross"
BUILD="$SRC/build"
INSTALL="$ROOT/vendor/.install"
BREW_PREFIX="$(brew --prefix)"

echo "==> configuring shadercross"
cmake -S "$SRC" -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" \
    -DCMAKE_PREFIX_PATH="$BREW_PREFIX" \
    -DSDLSHADERCROSS_DXC=OFF \
    -DSDLSHADERCROSS_VENDORED=OFF \
    -DSDLSHADERCROSS_SPIRVCROSS_SHARED=OFF \
    -DSDLSHADERCROSS_CLI=OFF \
    -DSDLSHADERCROSS_TESTS=OFF \
    -DSDLSHADERCROSS_INSTALL=ON \
    -DSDLSHADERCROSS_SHARED=ON \
    -DSDLSHADERCROSS_STATIC=OFF

echo "==> building shadercross"
cmake --build "$BUILD" --config Release --parallel

echo "==> installing into $INSTALL"
cmake --install "$BUILD"

echo "==> done"
echo "  headers: $INSTALL/include"
echo "  libs:    $INSTALL/lib"
