#!/usr/bin/env bash
# Compiles HLSL shaders in Shaders/src/ to SPIR-V via glslangValidator
# (consumed by SDL_shadercross at runtime on macOS) and transpiles each
# SPIR-V to WGSL via naga (consumed by the WebGPU backend on web).
# Both outputs land in Sources/Bielik2D/Resources/shaders/ where SwiftPM
# bundles them as Resources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Shaders/src"
OUT="$ROOT/Sources/Bielik2D/Resources/shaders"
mkdir -p "$OUT"

have_naga=true
if ! command -v naga >/dev/null 2>&1; then
    have_naga=false
    echo "warning: naga not on PATH; skipping WGSL emission (run 'brew install naga-cli')" >&2
fi

compile() {
    local input=$1
    local stage=$2
    local spv=$3
    glslangValidator -V -D -S "$stage" --quiet -e main -o "$spv" "$input"
    echo "  $(basename "$input") -> $(basename "$spv")"

    if $have_naga; then
        local wgsl="${spv%.spv}.wgsl"
        if naga "$spv" "$wgsl" 2>/dev/null; then
            echo "  $(basename "$spv") -> $(basename "$wgsl")"
        else
            echo "  naga skipped $(basename "$spv") (see Shaders/wgsl/ for the hand-written override)"
        fi
    fi
}

echo "==> compiling HLSL shaders"
compile "$SRC/basic.vert.hlsl" vert "$OUT/basic.vert.spv"
compile "$SRC/basic.frag.hlsl" frag "$OUT/basic.frag.spv"
compile "$SRC/sprite.vert.hlsl" vert "$OUT/sprite.vert.spv"
compile "$SRC/sprite.frag.hlsl" frag "$OUT/sprite.frag.spv"

WGSL_OVERRIDES="$ROOT/Shaders/wgsl"
if [ -d "$WGSL_OVERRIDES" ]; then
    for f in "$WGSL_OVERRIDES"/*.wgsl; do
        [ -e "$f" ] || continue
        name="$(basename "$f")"
        cp "$f" "$OUT/$name"
        echo "  override $name"
    done
fi
echo "==> done"
