# Draw-state stacks — scissor / viewport / blend — design

**Date:** 2026-06-16
**Branch/worktree:** `draw-state` (`../bielik2d-draw-state`)
**Phase:** 19 (remaining slices — draw-state stacks)

## Problem

`Draw` has push/pop stacks for transform, color, layer, scaleMode, and shapeAA, but not for the
three GPU-state knobs CF exposes: **scissor** (clip rect), **viewport** (sub-rect render target),
and **blend mode**. Without them you can't clip a HUD/inventory panel, render to a sub-region
(minimap / split-screen), or draw additive glows. `FEATURES.md` lists all three under the draw
module's "Missing:". This is the meatiest remaining Phase-19 slice.

## Goal

Add `pushScissor`/`pushViewport`/`pushBlendState` (with matching pops and `with { }` support) that
behave like the existing state stacks, and make the renderer honour them per draw call.

## Coverage / decisions (settled in brainstorming)

- **Coordinate space:** scissor and viewport rects are in **logical points** (the same space HUDs
  are drawn in, e.g. the demo's 1280×720), axis-aligned in target space (NOT camera-transformed —
  the standard for clipping). The renderer converts points → target pixels by the target's density
  (display density for the swapchain; 1.0 for offscreen canvases) and clamps scissor to target
  bounds (SDL rejects out-of-bounds scissors).
- **Nesting = replace**, not intersection. A pushed rect becomes the active clip/viewport; popping
  restores the previous. Consistent with the engine's other replace-semantics stacks (layer /
  scaleMode). Nested-clip intersection is a possible later refinement, explicitly out of scope.
- **Blend modes:** the existing `BlendMode { none, alpha, additive, premultipliedAlpha }`.
- **Web backend:** native (`Renderer`) only. `WebRenderer` is unverified and ignores scissor /
  viewport / blend for now. Noted, not implemented.

## Architecture

All three ride the mechanism `layer`/`texture`/`blendMode` already use: per-command state on
`DrawCallState`; any change forces a draw-call boundary; the state is applied during the render
pass. `blendMode` is already a field and `Batcher.setBlend` already splits commands — but
`Renderer.flushList` hardcodes `.alpha` and ignores it, so blend is ~half-wired.

### 1. `DrawCallState` + `Batcher` (`Sources/Bielik2D/Draw/Batcher.swift`)

Add two fields to `DrawCallState` (logical points; `nil` = full target):

```swift
public struct DrawCallState: Equatable {
    public var texture: OpaquePointer?
    public var blendMode: BlendMode
    public var layer: Int
    public var scissor: Rect?       // logical points, target-space; nil = no clip
    public var viewport: Rect?      // logical points, target-space; nil = full target
    // init gains scissor: Rect? = nil, viewport: Rect? = nil
}
```

Add setters mirroring `setBlend`/`setLayer` (each routes through `flushIfChange`, so a change splits
the command):

```swift
public func setScissor(_ r: Rect?)  { flushIfChange { $0.scissor = r } }
public func setViewport(_ r: Rect?) { flushIfChange { $0.viewport = r } }
```

These fields ride along through `commandsSortedByLayer` — each command keeps its own
clip/viewport/blend after the stable layer sort.

### 2. `Draw` (`Sources/Bielik2D/Draw/Draw.swift`)

Three new stacks (initial values = no clip / full target / alpha):

```swift
private var scissors = StateStack(initial: Rect?.none)
private var viewports = StateStack(initial: Rect?.none)
private var blends    = StateStack(initial: BlendMode.alpha)
```

Push/pop sync to the batcher at push/pop time, exactly like `pushLayer`:

```swift
public func pushScissor(_ rect: Rect) { scissors.push(rect); batcher.setScissor(rect) }
public func popScissor()              { _ = scissors.pop(); batcher.setScissor(scissors.peek) }

public func pushViewport(_ rect: Rect) { viewports.push(rect); batcher.setViewport(rect) }
public func popViewport()              { _ = viewports.pop(); batcher.setViewport(viewports.peek) }

public func pushBlendState(_ mode: BlendMode) { blends.push(mode); batcher.setBlend(mode) }
public func popBlendState()                   { _ = blends.pop(); batcher.setBlend(blends.peek) }

public var currentScissor: Rect? { scissors.peek }
public var currentViewport: Rect? { viewports.peek }
public var currentBlendState: BlendMode { blends.peek }
```

Extend `with { }` with `scissor: Rect? = nil`, `viewport: Rect? = nil`, `blendState: BlendMode? =
nil` (push-if-provided, auto-pop in reverse order), matching the existing pattern. As with the
current `with`, a `nil` argument means "don't push this axis" — there is no "push no-clip" via
`with` (structure scopes to clear a clip), keeping the API consistent.

`reset()` (frame teardown) must also reset the three stacks to their initials alongside the
existing ones, so a leaked push can't bleed across frames.

### 3. `RenderPass` (`Sources/Bielik2D/GPU/RenderPass.swift`)

Thin wrappers over SDL (target-pixel ints for scissor, floats for viewport):

```swift
public func setScissor(x: Int, y: Int, width: Int, height: Int) {
    var r = SDL_Rect(x: Int32(x), y: Int32(y), w: Int32(width), h: Int32(height))
    SDL_SetGPUScissor(handle, &r)
}
public func setViewport(x: Float, y: Float, width: Float, height: Float) {
    var vp = SDL_GPUViewport(x: x, y: y, w: width, h: height, min_depth: 0, max_depth: 1)
    SDL_SetGPUViewport(handle, &vp)
}
```

### 4. `Renderer.flushList` (`Sources/Bielik2D/Draw/Renderer.swift`)

`flushList` gains a `pointScale: Float` parameter (the target's points→pixels factor). Callers:
- swapchain flush (`drawOntoScreen` path) → `Draw.ambientPixelDensity`,
- offscreen canvas flush → `1.0` (canvas coordinate space is its own pixels).

Inside the pass, drop the hardcoded pipeline and, per command, apply state only when it changes
from the previously-applied value (cheap dedup):

```swift
var lastBlend: BlendMode? = nil
var lastScissor: Rect?? = nil      // Optional<Optional<Rect>>: distinguishes "not yet set"
var lastViewport: Rect?? = nil
let targetW = colorTarget.width, targetH = colorTarget.height

for c in commands {
    if lastBlend != c.state.blendMode {
        pass.bind(pipelines.get(PipelineKey(shaderID: 0, colorFormat: colorTarget.format,
                                            blendMode: c.state.blendMode)))
        pass.bindVertexBuffer(vbuf)            // re-bind after a pipeline switch
        lastBlend = c.state.blendMode
    }
    if lastScissor != .some(c.state.scissor) {
        applyScissor(c.state.scissor, pass: pass, scale: pointScale, w: targetW, h: targetH)
        lastScissor = .some(c.state.scissor)
    }
    if lastViewport != .some(c.state.viewport) {
        applyViewport(c.state.viewport, pass: pass, scale: pointScale, w: targetW, h: targetH)
        lastViewport = .some(c.state.viewport)
    }
    let tex = c.state.texture ?? whiteTexture.handle
    pass.bindFragmentSampler(textureHandle: tex, sampler: sampler)
    pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
}
```

Helpers (free functions or private methods), with **scissor clamped to target bounds**:

```swift
func applyScissor(_ r: Rect?, pass: RenderPass, scale: Float, w: Int, h: Int) {
    guard let r else { pass.setScissor(x: 0, y: 0, width: w, height: h); return }
    let x0 = max(0, Int((r.minX * scale).rounded(.down)))
    let y0 = max(0, Int((r.minY * scale).rounded(.down)))
    let x1 = min(w, Int((r.maxX * scale).rounded(.up)))
    let y1 = min(h, Int((r.maxY * scale).rounded(.up)))
    pass.setScissor(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
}
func applyViewport(_ r: Rect?, pass: RenderPass, scale: Float, w: Int, h: Int) {
    guard let r else { pass.setViewport(x: 0, y: 0, width: Float(w), height: Float(h)); return }
    pass.setViewport(x: r.minX * scale, y: r.minY * scale,
                     width: r.width * scale, height: r.height * scale)
}
```

(`pass.bind` must precede the first `draw`; initialise `lastBlend = nil` so the first command always
binds. Reset scissor/viewport to full-target at the start so a target with only `nil`-state commands
still gets a well-defined full scissor.)

A sub-`viewport` squishes the camera's full-target projection into the sub-rect (minimap /
split-screen). Aspect correctness is the caller's concern via their camera — same as CF.

## What this does NOT change

- Vertex layout / shaders (these are GPU-state knobs, not per-vertex data).
- The layer sort, atlas resolution, sprite path, text path.
- The `with { }` ordering contract for the existing axes.

## Testing

GPU calls can't run headless, so the **pure-data** parts get unit tests; visual correctness is a
demo slice.

- `Tests/Bielik2DTests/` `BatcherTests` additions: changing scissor / viewport / blend between
  emits produces separate `DrawCommand`s with the right per-command state; identical state
  coalesces into one command; the fields survive `commandsSortedByLayer`.
- A pure `scissorPixelRect(_ logical: Rect?, scale:, targetW:, targetH:)` helper extracted so the
  point→pixel conversion + clamp is unit-tested directly (full-target on nil; clamps an
  oversized/negative rect into bounds; rounds out so a 1px clip never vanishes).
- Pipeline selection: a command with `.additive` resolves a different `PipelineKey` than `.alpha`
  (assert on the key, not the GPU pipeline).
- Demo: a slice showing a scissor-clipped panel and an additive-blend cluster (its own small
  follow-up; can fold into the Shapes scene or a new one). Not required for the capability to land.

## Docs (same commit as the capability)

- `FEATURES.md` draw row: remove `pushScissor`/`pushViewport`/`pushBlendState` from "Missing:",
  note them as shipped; the row stays 🟡 (text effects + filled poly still pending).
- `TODO.md` Phase 19: check the draw-state-stacks box
  (`pushScissor` / `pushViewport` / `pushBlendState`).

## Build sequence (each step builds + tests green)

1. `DrawCallState` scissor/viewport fields + `Batcher.setScissor`/`setViewport` (+ batcher boundary
   tests, RED first).
2. `Draw` stacks + push/pop + `currentX` accessors + `with { }` params + `reset()` wiring.
3. `RenderPass.setScissor`/`setViewport`.
4. `scissorPixelRect` helper + unit test, then wire `flushList` (pointScale param, per-command
   blend pipeline + scissor + viewport with change-dedup); thread `pointScale` from the two flush
   callers.
5. Pipeline-by-blend test.
6. Demo slice (optional).
7. `FEATURES.md` + `TODO.md` in the capability-landing commit.
