# Draw-state Stacks (scissor / viewport / blend) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `pushScissor` / `pushViewport` / `pushBlendState` (with pops + `with { }` support) that behave like the existing draw-state stacks, and honour them per draw call in the renderer.

**Architecture:** Two new fields on `DrawCallState` (scissor, viewport — logical points) plus the existing `blendMode` become per-command flush boundaries via the `Batcher`. `Draw` gains three stacks that sync to the batcher at push/pop time (like `pushLayer`). `Renderer.flushList` applies them per command: pipeline-by-blend (the `PipelineCache` is already keyed on blend), scissor/viewport converted logical→target-pixels with a change-dedup. Replace (not intersection) nesting; native backend only.

**Tech Stack:** Swift 6.3, SDL3 GPU (`SDL_SetGPUScissor`/`SDL_SetGPUViewport`), swift-testing.

**Worktree:** `../bielik2d-draw-state` (branch `draw-state`, `vendor/.install` symlinked). Run all commands there.

**Spec:** `docs/superpowers/specs/2026-06-16-draw-state-stacks-design.md`

**Commit note:** signing fails in this sandbox; the whole history is unsigned — commit with `git -c commit.gpgsign=false commit -m "..."`. Lowercase imperative, no Conventional-Commits prefix, no AI signoff.

**Test note:** GPU calls can't run headless. The pure-data parts (batcher boundaries, the Draw stacks via `Draw(batcher:)`, the logical→pixel conversion, pipeline-key selection) get swift-testing unit tests run with `swift test --filter <name>`. The render-pass wiring is build-gated (`swift build`) and verified visually by the demo slice (Task 6).

---

## File structure

- **Modify** `Sources/Bielik2D/Draw/Batcher.swift` — add `scissor`/`viewport` to `DrawCallState`; add `setScissor`/`setViewport`.
- **Modify** `Sources/Bielik2D/Draw/Draw.swift` — three stacks + push/pop + `currentX` + `with { }` params.
- **Modify** `Sources/Bielik2D/GPU/RenderPass.swift` — `setScissor`/`setViewport` SDL wrappers.
- **Create** `Sources/Bielik2D/Draw/DrawStatePixels.swift` — pure `scissorPixelRect`/`viewportPixelRect` converters (testable).
- **Modify** `Sources/Bielik2D/Draw/Renderer.swift` — `flushList` gains `pointScale`, applies blend pipeline + scissor + viewport per command; thread `pointScale` from the two flush entry points.
- **Create** `Sources/Bielik2DDemo/Scenes/DrawStateScene.swift` + **modify** `Sources/Bielik2DDemo/main.swift` — demo slice.
- **Modify** `Tests/Bielik2DTests/BatcherTests.swift`, `DrawTests.swift`; **create** `Tests/Bielik2DTests/DrawStatePixelsTests.swift`, `Tests/Bielik2DTests/PipelineBlendTests.swift`.
- **Modify** `FEATURES.md`, `TODO.md`.

---

### Task 1: `DrawCallState` scissor/viewport fields + `Batcher` setters

**Files:**
- Modify: `Sources/Bielik2D/Draw/Batcher.swift`
- Test: `Tests/Bielik2DTests/BatcherTests.swift`

- [ ] **Step 1: Write the failing tests** — append to `Tests/Bielik2DTests/BatcherTests.swift`:

```swift
@Test func scissorChangeFlushesCommand() {
    let b = Batcher()
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setScissor(Rect(x: 10, y: 20, width: 100, height: 50))
    b.emitQuad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 2)
    #expect(cmds[0].state.scissor == nil)
    #expect(cmds[1].state.scissor == Rect(x: 10, y: 20, width: 100, height: 50))
}

@Test func viewportChangeFlushesCommand() {
    let b = Batcher()
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setViewport(Rect(x: 0, y: 0, width: 320, height: 240))
    b.emitQuad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 2)
    #expect(cmds[1].state.viewport == Rect(x: 0, y: 0, width: 320, height: 240))
}

@Test func sameScissorMergesIntoOneCommand() {
    let b = Batcher()
    let s = Rect(x: 1, y: 2, width: 3, height: 4)
    b.setScissor(s)
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setScissor(s)
    b.emitQuad(rect: unit, uv: uv, color: white)
    #expect(b.commands.count == 1)
}

@Test func scissorSurvivesLayerSort() {
    let b = Batcher()
    let s = Rect(x: 5, y: 5, width: 5, height: 5)
    b.setLayer(2)
    b.setScissor(s)
    b.emitQuad(rect: unit, uv: uv, color: white)
    let sorted = b.commandsSortedByLayer
    #expect(sorted.last?.state.scissor == s)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter scissorChangeFlushesCommand`
Expected: FAIL — `DrawCallState` has no `scissor`; `Batcher` has no `setScissor`.

- [ ] **Step 3: Implement** — in `Sources/Bielik2D/Draw/Batcher.swift`, extend `DrawCallState` and add the two setters.

Replace the `DrawCallState` struct with:

```swift
public struct DrawCallState: Equatable {
    public var texture: OpaquePointer?
    public var blendMode: BlendMode
    public var layer: Int
    public var scissor: Rect?       // logical points, target-space; nil = no clip
    public var viewport: Rect?      // logical points, target-space; nil = full target

    public init(texture: OpaquePointer? = nil, blendMode: BlendMode = .alpha, layer: Int = 0,
                scissor: Rect? = nil, viewport: Rect? = nil) {
        self.texture = texture
        self.blendMode = blendMode
        self.layer = layer
        self.scissor = scissor
        self.viewport = viewport
    }
}
```

Add the setters next to `setBlend`/`setLayer` (inside `final class Batcher`):

```swift
    public func setScissor(_ r: Rect?) {
        flushIfChange { $0.scissor = r }
    }

    public func setViewport(_ r: Rect?) {
        flushIfChange { $0.viewport = r }
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter "scissorChangeFlushesCommand|viewportChangeFlushesCommand|sameScissorMergesIntoOneCommand|scissorSurvivesLayerSort"`
Expected: PASS (4). Also `swift test --filter BatcherTests` to confirm no regressions in the existing batcher tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Draw/Batcher.swift Tests/Bielik2DTests/BatcherTests.swift
git -c commit.gpgsign=false commit -m "carry scissor and viewport on draw-call state"
```

---

### Task 2: `Draw` stacks — push/pop, accessors, `with { }`

**Files:**
- Modify: `Sources/Bielik2D/Draw/Draw.swift`
- Test: `Tests/Bielik2DTests/DrawTests.swift`

- [ ] **Step 1: Write the failing tests** — append to `Tests/Bielik2DTests/DrawTests.swift`:

```swift
@Test func pushScissorSplitsAndRestores() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let s = Rect(x: 10, y: 20, width: 100, height: 50)
    d.quad(rect: unit, uv: uv, color: white)
    d.pushScissor(s)
    #expect(d.currentScissor == s)
    d.quad(rect: unit, uv: uv, color: white)
    d.popScissor()
    #expect(d.currentScissor == nil)
    d.quad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 3)
    #expect(cmds[0].state.scissor == nil)
    #expect(cmds[1].state.scissor == s)
    #expect(cmds[2].state.scissor == nil)
}

@Test func pushBlendStateAffectsCommandState() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushBlendState(.additive)
    #expect(d.currentBlendState == .additive)
    d.quad(rect: unit, uv: uv, color: white)
    #expect(b.commands.last?.state.blendMode == .additive)
}

@Test func withScissorScopesAndAutoPops() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let s = Rect(x: 0, y: 0, width: 10, height: 10)
    d.with(scissor: s) {
        d.quad(rect: unit, uv: uv, color: white)
    }
    #expect(d.currentScissor == nil)         // auto-popped
    #expect(b.commands.first?.state.scissor == s)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter pushScissorSplitsAndRestores`
Expected: FAIL — `Draw` has no `pushScissor`/`currentScissor`.

- [ ] **Step 3: Implement** — in `Sources/Bielik2D/Draw/Draw.swift`.

Add the three stacks next to the existing stack properties (after `shapeAAs`):

```swift
    private var scissors = StateStack(initial: Rect?.none)
    private var viewports = StateStack(initial: Rect?.none)
    private var blends = StateStack(initial: BlendMode.alpha)
```

Add push/pop + accessors (place near the other push/pop methods, e.g. after the shapeAA ones):

```swift
    // MARK: - Scissor / viewport / blend

    /// Clip subsequent draws to `rect` (logical points, target-space). Replace semantics.
    public func pushScissor(_ rect: Rect) { scissors.push(rect); batcher.setScissor(rect) }
    public func popScissor() { _ = scissors.pop(); batcher.setScissor(scissors.peek) }
    public var currentScissor: Rect? { scissors.peek }

    /// Render subsequent draws into `rect` (logical points, target-space) of the target.
    public func pushViewport(_ rect: Rect) { viewports.push(rect); batcher.setViewport(rect) }
    public func popViewport() { _ = viewports.pop(); batcher.setViewport(viewports.peek) }
    public var currentViewport: Rect? { viewports.peek }

    /// Blend mode for subsequent draws.
    public func pushBlendState(_ mode: BlendMode) { blends.push(mode); batcher.setBlend(mode) }
    public func popBlendState() { _ = blends.pop(); batcher.setBlend(blends.peek) }
    public var currentBlendState: BlendMode { blends.peek }
```

Extend `with { }` — replace its signature/body to add the three axes (push-if-provided, auto-pop in reverse). The full method becomes:

```swift
    @discardableResult
    public func with<R>(transform: Mat3x2? = nil,
                        color: Color? = nil,
                        layer: Int? = nil,
                        scaleMode: ScaleMode? = nil,
                        shapeAA: Float? = nil,
                        scissor: Rect? = nil,
                        viewport: Rect? = nil,
                        blendState: BlendMode? = nil,
                        _ body: () throws -> R) rethrows -> R {
        if let transform { pushTransform(transform) }
        if let color { pushColor(color) }
        if let layer { pushLayer(layer) }
        if let scaleMode { pushScaleMode(scaleMode) }
        if let shapeAA { pushShapeAA(shapeAA) }
        if let scissor { pushScissor(scissor) }
        if let viewport { pushViewport(viewport) }
        if let blendState { pushBlendState(blendState) }
        defer {
            if blendState != nil { popBlendState() }
            if viewport != nil { popViewport() }
            if scissor != nil { popScissor() }
            if shapeAA != nil { popShapeAA() }
            if scaleMode != nil { popScaleMode() }
            if layer != nil { popLayer() }
            if color != nil { popColor() }
            if transform != nil { popTransform() }
        }
        return try body()
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter "pushScissorSplitsAndRestores|pushBlendStateAffectsCommandState|withScissorScopesAndAutoPops"`
Expected: PASS (3). Then `swift test --filter DrawTests` for no regressions.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Draw/Draw.swift Tests/Bielik2DTests/DrawTests.swift
git -c commit.gpgsign=false commit -m "add scissor/viewport/blend push-pop stacks to Draw"
```

---

### Task 3: `RenderPass` SDL scissor/viewport wrappers

**Files:**
- Modify: `Sources/Bielik2D/GPU/RenderPass.swift`

(No headless test — these are direct SDL calls. Build-gated; exercised in Task 4's flush + Task 6's demo.)

- [ ] **Step 1: Implement** — add two methods inside `struct RenderPass` (after `draw(...)`):

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

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: `Build complete!` (exit 0). If `SDL_GPUViewport`'s field names differ from `x/y/w/h/min_depth/max_depth`, STOP and report NEEDS_CONTEXT with the actual struct (don't guess).

- [ ] **Step 3: Commit**

```bash
git add Sources/Bielik2D/GPU/RenderPass.swift
git -c commit.gpgsign=false commit -m "add setScissor/setViewport render-pass wrappers"
```

---

### Task 4: pixel converters + wire `flushList`

**Files:**
- Create: `Sources/Bielik2D/Draw/DrawStatePixels.swift`
- Test: `Tests/Bielik2DTests/DrawStatePixelsTests.swift`
- Modify: `Sources/Bielik2D/Draw/Renderer.swift`

- [ ] **Step 1: Write the failing test** — create `Tests/Bielik2DTests/DrawStatePixelsTests.swift`:

```swift
import Testing
@testable import Bielik2D

@Test func nilScissorIsFullTarget() {
    let s = scissorPixelRect(nil, scale: 1, targetW: 800, targetH: 600)
    #expect(s.x == 0 && s.y == 0 && s.w == 800 && s.h == 600)
}

@Test func scissorScalesByDensity() {
    let s = scissorPixelRect(Rect(x: 10, y: 20, width: 100, height: 50),
                             scale: 2, targetW: 1000, targetH: 1000)
    #expect(s.x == 20 && s.y == 40 && s.w == 200 && s.h == 100)
}

@Test func scissorClampsToTargetBounds() {
    // Rect extends past the 100×100 target and starts negative -> clamped into [0,100].
    let s = scissorPixelRect(Rect(x: -20, y: -20, width: 200, height: 200),
                             scale: 1, targetW: 100, targetH: 100)
    #expect(s.x == 0 && s.y == 0 && s.w == 100 && s.h == 100)
}

@Test func nilViewportIsFullTarget() {
    let v = viewportPixelRect(nil, scale: 1, targetW: 640, targetH: 480)
    #expect(v.x == 0 && v.y == 0 && v.w == 640 && v.h == 480)
}

@Test func viewportScalesByDensity() {
    let v = viewportPixelRect(Rect(x: 10, y: 5, width: 100, height: 80),
                              scale: 2, targetW: 1000, targetH: 1000)
    #expect(v.x == 20 && v.y == 10 && v.w == 200 && v.h == 160)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter nilScissorIsFullTarget`
Expected: FAIL — `scissorPixelRect` undefined.

- [ ] **Step 3: Implement the converters** — create `Sources/Bielik2D/Draw/DrawStatePixels.swift`:

```swift
/// Convert a logical-point scissor rect to clamped target-pixel ints. `nil` → full target.
/// Rounds the rect outward (floor min, ceil max) so a sub-pixel clip never collapses to nothing,
/// then clamps each edge into `[0, target]` (SDL rejects out-of-bounds scissors).
func scissorPixelRect(_ logical: Rect?, scale: Float, targetW: Int, targetH: Int)
    -> (x: Int, y: Int, w: Int, h: Int) {
    guard let r = logical else { return (0, 0, targetW, targetH) }
    let x0 = max(0, min(targetW, Int((r.minX * scale).rounded(.down))))
    let y0 = max(0, min(targetH, Int((r.minY * scale).rounded(.down))))
    let x1 = max(0, min(targetW, Int((r.maxX * scale).rounded(.up))))
    let y1 = max(0, min(targetH, Int((r.maxY * scale).rounded(.up))))
    return (x0, y0, max(0, x1 - x0), max(0, y1 - y0))
}

/// Convert a logical-point viewport rect to target-pixel floats. `nil` → full target.
func viewportPixelRect(_ logical: Rect?, scale: Float, targetW: Int, targetH: Int)
    -> (x: Float, y: Float, w: Float, h: Float) {
    guard let r = logical else { return (0, 0, Float(targetW), Float(targetH)) }
    return (r.minX * scale, r.minY * scale, r.width * scale, r.height * scale)
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter "Scissor|Viewport"`
Expected: PASS (5 from this file).

- [ ] **Step 5: Wire `flushList`** — in `Sources/Bielik2D/Draw/Renderer.swift`.

(a) Change the signature to add `pointScale`:

```swift
    private func flushList(_ list: DrawList, into colorTarget: Texture, clear: Color?, camera: Camera,
                           on cmd: CommandBuffer, cycleTarget: Bool = false, pointScale: Float = 1.0) {
```

(b) Replace the render-pass body (the `cmd.withRenderPass { pass in ... }` block) with per-command state application:

```swift
        cmd.pushVertexUniform(camera.viewProjection)
        cmd.withRenderPass(colorTarget: colorTarget, clear: clear, cycle: cycleTarget) { pass in
            guard byteCount > 0 else { return }
            pass.bindVertexBuffer(vbuf)
            let tw = colorTarget.width, th = colorTarget.height
            var lastBlend: BlendMode? = nil
            var lastScissor: Rect?? = nil
            var lastViewport: Rect?? = nil
            for c in commands {
                if lastBlend != c.state.blendMode {
                    pass.bind(pipelines.get(PipelineKey(shaderID: 0, colorFormat: colorTarget.format,
                                                        blendMode: c.state.blendMode)))
                    lastBlend = c.state.blendMode
                }
                if lastScissor != .some(c.state.scissor) {
                    let s = scissorPixelRect(c.state.scissor, scale: pointScale, targetW: tw, targetH: th)
                    pass.setScissor(x: s.x, y: s.y, width: s.w, height: s.h)
                    lastScissor = .some(c.state.scissor)
                }
                if lastViewport != .some(c.state.viewport) {
                    let v = viewportPixelRect(c.state.viewport, scale: pointScale, targetW: tw, targetH: th)
                    pass.setViewport(x: v.x, y: v.y, width: v.w, height: v.h)
                    lastViewport = .some(c.state.viewport)
                }
                let tex = c.state.texture ?? whiteTexture.handle
                pass.bindFragmentSampler(textureHandle: tex, sampler: sampler)
                pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
            }
        }
```

(The vertex buffer is bound once — SDL keeps vertex bindings across pipeline binds. `lastBlend = nil` guarantees the first command binds a pipeline before drawing.)

(c) Thread `pointScale` from the two callers:
- In `render(_ list: DrawList, camera:, clear:)` (swapchain): change the call to
  `flushList(list, into: swap, clear: clear, camera: camera, on: cmd, pointScale: Draw.ambientPixelDensity)`.
- In `render(_ draw: Draw, to canvas:, ...)` (offscreen): the canvas coordinate space is its own
  pixels, so leave `pointScale` at its `1.0` default — the existing call
  `flushList(list, into: canvas.texture, clear: clear, camera: cam, on: cmd, cycleTarget: true)`
  is unchanged.

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!` (exit 0).

- [ ] **Step 7: Commit**

```bash
git add Sources/Bielik2D/Draw/DrawStatePixels.swift Tests/Bielik2DTests/DrawStatePixelsTests.swift Sources/Bielik2D/Draw/Renderer.swift
git -c commit.gpgsign=false commit -m "apply per-command blend, scissor, and viewport at flush"
```

---

### Task 5: pipeline-key selection by blend mode

Locks in that distinct blend modes resolve distinct pipeline keys (the mechanism the flush relies on).

**Files:**
- Test: `Tests/Bielik2DTests/PipelineBlendTests.swift`

- [ ] **Step 1: Write the test** — create `Tests/Bielik2DTests/PipelineBlendTests.swift`:

```swift
import Testing
@testable import Bielik2D

@Test func blendModeDistinguishesPipelineKey() {
    let alpha = PipelineKey(shaderID: 0, colorFormat: .bgra8Unorm, blendMode: .alpha)
    let additive = PipelineKey(shaderID: 0, colorFormat: .bgra8Unorm, blendMode: .additive)
    #expect(alpha != additive)
    #expect(alpha == PipelineKey(shaderID: 0, colorFormat: .bgra8Unorm, blendMode: .alpha))
}
```

- [ ] **Step 2: Run**

Run: `swift test --filter blendModeDistinguishesPipelineKey`
Expected: PASS. If `PipelineKey`'s initializer/field names differ (it's `struct PipelineKey { shaderID; colorFormat; blendMode }` in `PipelineCache.swift`), adjust the literal to match and re-run; do not change the source.

- [ ] **Step 3: Commit**

```bash
git add Tests/Bielik2DTests/PipelineBlendTests.swift
git -c commit.gpgsign=false commit -m "assert blend mode keys distinct pipelines"
```

---

### Task 6: Demo slice — scissor clip + additive blend

Adds a scene to the (already scene-based) demo, both to verify visually and to showcase the new API.

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/DrawStateScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create the scene** — `Sources/Bielik2DDemo/Scenes/DrawStateScene.swift`:

```swift
import Bielik2D
import Foundation

/// pushScissor clips drawing to a rect; pushBlendState(.additive) makes overlaps brighten.
final class DrawStateScene: Scene {
    let name = "Draw State: Scissor & Blend"
    let summary = "pushScissor clips to a rect (drifting circles stay inside); pushBlendState .additive glows"
    let controls = ""

    init(app: App) {}

    func update(_ ctx: SceneContext) {
        let d = ctx.draw
        let panel = Rect(x: ctx.stage.x + 40, y: ctx.stage.y + 60, width: 320, height: 200)
        d.boxFill(panel, cornerRadius: 0, color: Color(r: 0.14, g: 0.15, b: 0.22))
        d.with(scissor: panel) {
            let drift = (sin(ctx.time) * 0.5 + 0.5) * 280
            for i in 0..<8 {
                let cx = panel.x - 40 + drift + Float(i) * 70
                d.circleFill(center: SIMD2(cx, panel.y + 100), radius: 48,
                             color: Color(r: 0.4, g: 0.8, b: 1.0))
            }
        }
        d.box(panel, stroke: 2, color: Color(r: 0.5, g: 0.9, b: 1.0))
        d.text("pushScissor", font: ctx.font, at: SIMD2(panel.x, panel.maxY + 8), color: .white)

        let bx = ctx.stage.x + 460
        let by = ctx.stage.y + 150
        d.with(blendState: .additive) {
            d.circleFill(center: SIMD2(bx, by), radius: 60, color: Color(r: 0.8, g: 0.15, b: 0.15))
            d.circleFill(center: SIMD2(bx + 72, by), radius: 60, color: Color(r: 0.15, g: 0.8, b: 0.15))
            d.circleFill(center: SIMD2(bx + 36, by + 64), radius: 60, color: Color(r: 0.15, g: 0.2, b: 0.9))
        }
        d.text("pushBlendState(.additive)", font: ctx.font, at: SIMD2(bx - 30, by + 150), color: .white)
    }
}
```

- [ ] **Step 2: Register it** — in `Sources/Bielik2DDemo/main.swift`, append to the `scenes` array (after `SweptTOIScene(app: app),`):

```swift
    DrawStateScene(app: app),
```

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Launch and verify (manual)**

Run: `swift run Bielik2DDemo`, flip to the last scene ("Draw State: Scissor & Blend").
Expected: the blue circles drift but are **clipped to the panel rectangle** (nothing draws outside it); the three RGB circles on the right **brighten where they overlap** (additive). Other scenes still render normally (no global blend/scissor leak). Close the window.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/DrawStateScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "showcase scissor and additive blend in the demo"
```

---

### Task 7: Update FEATURES.md and TODO.md

**Files:**
- Modify: `FEATURES.md`
- Modify: `TODO.md`

- [ ] **Step 1: `FEATURES.md` draw row** (exact replacement; row stays 🟡). Replace this exact substring:

```
Scoped state via `with{}` + `pushTransform`/`pushColor`/`pushLayer`/`pushScaleMode`/`pushShapeAA`. **Missing:** filled convex `poly`; `pushScissor`/`pushViewport`/`pushBlendState`. (Phase 19 remaining slices)
```

with:

```
Scoped state via `with{}` + `pushTransform`/`pushColor`/`pushLayer`/`pushScaleMode`/`pushShapeAA`/`pushScissor`/`pushViewport`/`pushBlendState`. **Missing:** filled convex `poly`. (Phase 19 remaining slices)
```

- [ ] **Step 2: `FEATURES.md` "What to build next"** — exact replacement. Replace this exact block (the item-1 bullet):

```
1. **Draw completeness (Phase 19, remaining slices)** — the shape primitives landed (outline
   `circle`, `tri`, `polyline`, `poly` outline, `boxFill`, `pushShapeAA`); still to do are the
   draw-state stacks (`pushScissor`/`pushViewport`/`pushBlendState`) and text effects (color
   markup, outline, shadow), plus filled convex `poly`.
```

with:

```
1. **Draw completeness (Phase 19, remaining slices)** — shape primitives and the draw-state stacks
   (`pushScissor`/`pushViewport`/`pushBlendState`) have landed; still to do are text effects (color
   markup, outline, shadow) and filled convex `poly`.
```

(If the committed wording differs slightly, match the real text — the goal is: remove the draw-state stacks from "still to do", leave text effects + filled `poly`.)

- [ ] **Step 3: `TODO.md` Phase 19** — change the unchecked draw-state-stacks line:

```
- [ ] Draw-state stacks `pushScissor` / `pushViewport` / `pushBlendState`
      (reuse the generic `StateStack<T>` in `Draw.swift`).
```

to:

```
- [x] Draw-state stacks `pushScissor` / `pushViewport` / `pushBlendState` (reuse the generic
      `StateStack<T>`; per-command state applied at flush — scissor/viewport in logical points
      scaled to target pixels, blend selects the pipeline).
```

Also update the Phase 6 line that reads `- [ ] \`pushScissor\` / \`pushViewport\` / \`pushShapeAA\` / \`pushBlendState\` — not yet implemented.` — `pushShapeAA` already shipped; now the rest have too, so change it to:

```
- [x] `pushScissor` / `pushViewport` / `pushShapeAA` / `pushBlendState`.
```

- [ ] **Step 4: Build + full test once more**

Run: `swift build && swift test`
Expected: build clean; full suite PASS.

- [ ] **Step 5: Commit**

```bash
git add FEATURES.md TODO.md
git -c commit.gpgsign=false commit -m "mark draw-state stacks shipped in features and todo"
```

---

## Notes for the implementer

- **Run from the worktree** `../bielik2d-draw-state`. If a build fails on `SDL_shadercross.h`, recreate the symlink: `ln -s /Users/piotr/Work/GitHub/pusewicz/bielik2d/vendor/.install vendor/.install`.
- **Scissor/viewport are logical points, target-space** (not camera-transformed) — the conversion to pixels happens only at flush via `pointScale`. Don't transform them by the camera.
- **Nesting is replace, not intersection** — a nested `pushScissor` overrides the parent. This is intentional (see spec); don't add intersection logic.
- `Draw(batcher:)` is the headless test initializer (no GPU) — use it in `DrawTests`.
- Don't touch the WebGPU backend; native only this cycle.

## Self-review notes (author)

- **Spec coverage:** DrawCallState fields + Batcher setters (T1); Draw stacks/push-pop/`with{}`/accessors (T2); RenderPass wrappers (T3); logical→pixel converters + clamp + flushList per-command blend/scissor/viewport + pointScale threading (T4); pipeline-by-blend (T5); demo slice (T6); FEATURES/TODO (T7). The spec's "no reset wiring" point is honoured — `DrawCallState` defaults make `batcher.reset()` clear the new fields automatically, and no Draw-side reset is added.
- **Type consistency:** `setScissor`/`setViewport`/`pushScissor`/`pushViewport`/`pushBlendState`/`currentScissor`/`currentViewport`/`currentBlendState`/`scissorPixelRect`/`viewportPixelRect`/`flushList(...pointScale:)` are referenced with identical signatures across tasks. `Rect?` field type matches everywhere; `BlendMode` is the existing enum.
- **No placeholders:** every step has concrete code or an exact command + expected output.
