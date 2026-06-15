# Draw shape primitives — Phase 19, slice 1

**Status:** approved design · **Date:** 2026-06-15 · **Branch:** `draw-shapes`

## Context

Phase 19 ("Draw completeness") in `TODO.md` is three independent deliverables: shape primitives,
draw-state stacks (scissor/viewport/blend), and text effects. This spec covers **only the shape
primitives slice** — the lowest-risk, highest-visual-payoff piece, which also rounds out the
collision debug-draw and HUD surface that the recently-landed collision work needs.

The engine already has a unified SDF pipeline: one `Vertex`, one fragment shader that branches on a
per-vertex `ShapeType`, and crisp HiDPI anti-aliasing via `smoothstep` over a signed distance. The
existing `circleFill` / `line` / `box` (rounded + stroked) / `capsule` shapes are the template; the
most recent addition (`capsule`, plus `Draw.debug(_:)` for collision shapes) shows the end-to-end
pattern: a Swift method emits a bounding quad with shape-local `uv` + shape params, and a shader
branch evaluates the SDF.

This slice adds the remaining CF-parity primitives that are missing, keeping every new shape **crisp**
(consistent with the rest of the engine) and reusing the existing pipeline wherever possible.

## Scope

### In scope
- `Draw.circle(center:radius:thickness:…)` — crisp **outline** circle.
- `Draw.tri(a,b,c,…)` — filled (SDF) and stroked triangle.
- `Draw.polyline(points:thickness:closed:…)` — connected segments with round joins/caps.
- `Draw.poly(points:stroke:…)` — closed polygon **outline**.
- `Draw.boxFill(rect:cornerRadius:…)` — CF-named convenience over the existing filled box.
- `pushShapeAA(_:)` / `popShapeAA()` + `with(shapeAA:)` — ambient AA override.

### Out of scope (explicitly deferred)
- **Filled** convex `poly` — needs a convex-poly SDF / vertex-layout rework; its own follow-up. Stroked
  `poly` (outline) is included and covers collision debug-draw.
- Draw-state stacks `pushScissor` / `pushViewport` / `pushBlendState` (Phase 19 slice 2).
- Text effects: color markup, outline, shadow (Phase 19 slice 3).
- `ScaleMode` → NEAREST/LINEAR/SMOOTH rename (orthogonal mechanical change; separate commit later).

## Design

### Existing pieces reused
- `Sources/Bielik2D/Draw/Primitives.swift` — `ShapeType` enum, `emitSDFQuadCorners`, all current shapes.
- `Sources/Bielik2D/Draw/Vertex.swift` — unified vertex; `attributes: SIMD4<Float>` and
  `uvBounds: SIMD4<Float>` are free channels for SDF shapes (sprite-only today). Both are forwarded to
  the fragment shader as constant-interpolated varyings.
- `Sources/Bielik2D/Draw/StateStack.swift` — generic ambient stack (template for shapeAA).
- `Shaders/src/sprite.frag.hlsl` + `Shaders/wgsl/sprite.frag.wgsl` — the SDF branch dispatcher;
  `sdRoundBox` helper already present. Built by `Shaders/build.sh` into `Sources/Bielik2D/Resources/shaders/`.

### New API (all methods on `Draw`, in `Primitives.swift`)
Signatures follow the existing primitives (default `color: .white`, `aa:` defaulting to the ambient
shape AA — see below):
- `circle(center:radius:thickness:color:aa:)` — outline circle.
- `tri(_ a:_ b:_ c:color:aa:)` (filled) and `tri(_ a:_ b:_ c:stroke:color:aa:)` (outline).
- `polyline(_ points:[SIMD2<Float>], thickness:closed:Bool=false,color:aa:)`.
- `poly(_ points:[SIMD2<Float>], stroke:color:aa:)`.
- `boxFill(_ rect:cornerRadius:Float=0,color:aa:)`.

### Shape implementations
- **Outline circle** — reuse `ShapeType.circle` with `fill:0` + `stroke:thickness`. Requires a tiny
  shader change (circle branch is filled-only today).
- **Triangle** — new `ShapeType.triangle = 5`. Emit the triangle's AABB as a bounding quad, padded by
  `aa (+ stroke/2)`. Work in a **local frame** (e.g. centred on the triangle centroid): the quad's
  `uv` carries the fragment's local position; the three corners (local) are packed into the free vertex
  channels:
  - `attributes.xy = p0`, `attributes.zw = p1`, `uvBounds.xy = p2` (all 6 verts identical).
  - `fill = stroke <= 0 ? 1 : 0`, `stroke`, `aa` as usual.
  This fits the current vertex layout with no rework.
- **polyline / poly / stroked tri** — pure Swift: emit one `capsule` per segment (round caps give round
  joins for free). `polyline(closed:true)` and `poly` wrap the last point back to the first.
  Stroked `tri` = a closed 3-point polyline. **No shader change.**
- **boxFill** — thin convenience calling the existing filled `box` path.

### Shader contract (HLSL + WGSL, kept in sync)
1. **Circle branch** gains a stroked path:
   ```
   if (fill > 0.5)  a = smoothstep(aa, -aa, d - radius);          // existing fill
   else             a = smoothstep(stroke/2 + aa, stroke/2 - aa, abs(d - radius));  // new outline
   ```
2. **New triangle branch** (`t == 5`): unpack `p0 = attributes.xy`, `p1 = attributes.zw`,
   `p2 = uvBounds.xy`; `d = sdTriangle(uv, p0, p1, p2)` (Inigo Quilez); fill/stroke smoothstep identical
   to box/capsule. Add `sdTriangle` helper alongside `sdRoundBox`. Derivatives, if any, stay outside the
   branch (uniform control flow), matching existing shaders.
3. Rebuild with `Shaders/build.sh`; commit the regenerated `.spv` (+ `.wgsl`) under
   `Sources/Bielik2D/Resources/shaders/`.

### Ambient shape AA
- Add a `StateStack<Float>` (`shapeAA`) to `Draw`, initialised to `1.5 / Draw.ambientPixelDensity`
  (today's per-call default). Every primitive's `aa:` parameter defaults to `currentShapeAA`. Extend the
  `with(...)` scoped helper with a `shapeAA: Float? = nil` axis.

## Testing (TDD, swift-testing, no GPU)
Mirror `Tests/Bielik2DTests/PrimitivesTests.swift` — emit into a `Batcher`, assert on the produced
vertices:
- `circle` outline emits `.circle` type with `fill == 0` and the given `stroke`.
- `tri` filled emits `.triangle` (fill 1); the three corners round-trip through
  `attributes.xy/.zw` + `uvBounds.xy`; stroked `tri` emits capsule segments instead.
- `polyline` of N points emits N−1 capsule segments (N when `closed`); `poly` wraps closed.
- `boxFill` emits a filled box (`fill == 1`).
- Ambient `pushShapeAA` overrides the default `aa` on a subsequently emitted primitive; `with(shapeAA:)`
  pops correctly.
All deterministic, pure geometry assertions.

## Demo
Add a shapes row to `Sources/Bielik2DDemo/main.swift`: outline circle, rounded box (`boxFill` +
`cornerRadius`), filled and stroked triangle, a `polyline`/`poly`, and a visible `with(shapeAA:)`
contrast. Eyeball AA crispness on Metal.

## Commit sequence (atomic, each `swift test` green)
1. Ambient `shapeAA` stack + `with(shapeAA:)` (+ tests).
2. Outline `circle` — shader circle-branch stroke path + `Draw.circle` (+ tests, rebuild shaders).
3. `triangle` SDF — `ShapeType.triangle`, shader branch + `sdTriangle`, `Draw.tri` filled (+ tests, rebuild shaders).
4. `polyline` / `poly` / stroked `tri` over capsule segments (+ tests).
5. `boxFill` convenience (+ test).
6. Demo shapes row.

## Verification
- `swift test` green after each commit.
- `Shaders/build.sh` runs clean; regenerated artifacts committed.
- `swift run Bielik2DDemo` on Metal — new shapes render crisp at HiDPI; stroked/filled and AA override
  visibly correct.
- Update `TODO.md` Phase 19 checkboxes for the shipped primitives and `FEATURES.md` `draw` row
  (per the CLAUDE.md rule) in the same commit as the code that ships them.
