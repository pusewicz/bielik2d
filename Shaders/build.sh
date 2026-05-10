#!/usr/bin/env bash
# Compiles HLSL shaders in Shaders/src/ to SPIR-V via glslangValidator,
# emitting bytecode into Sources/Bielik2D/Resources/shaders/ where SwiftPM
# bundles them as Resources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Shaders/src"
OUT="$ROOT/Sources/Bielik2D/Resources/shaders"
mkdir -p "$OUT"

compile() {
    local input=$1
    local stage=$2
    local out=$3
    glslangValidator -V -D -S "$stage" --quiet -e main -o "$out" "$input"
    echo "  $(basename "$input") -> $(basename "$out")"
}

echo "==> compiling HLSL shaders"
compile "$SRC/basic.vert.hlsl" vert "$OUT/basic.vert.spv"
compile "$SRC/basic.frag.hlsl" frag "$OUT/basic.frag.spv"
compile "$SRC/sprite.vert.hlsl" vert "$OUT/sprite.vert.spv"
compile "$SRC/sprite.frag.hlsl" frag "$OUT/sprite.frag.spv"
echo "==> done"
