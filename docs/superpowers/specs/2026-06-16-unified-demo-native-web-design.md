# Unified `Bielik2DDemo` across native (SDL3) and web (WASI/WebGPU)

**Date:** 2026-06-16
**Status:** Approved design, pending implementation plan

## Context

Bielik2D currently ships two demos: the real `Bielik2DDemo` (an 11-scene native
executable bound to SDL3) and a separate, minimal `Bielik2DWebDemo` (a single
sprite+SDF+text scene on the WASI/WebGPU backend). We want **one** demo — the real
11-scene `Bielik2DDemo` — to build and run on both native and web, with the web
renderer brought to parity. The separate `Bielik2DWebDemo` is retired.

Why this is non-trivial: the web build compiles Swift to `wasm32-unknown-wasip1`
(WASI) via the swift.org wasm SDK and reaches browser APIs through JavaScriptKit.
SDL3's browser support is an **Emscripten** port — an incompatible toolchain — and
SDL3's GPU API has no stable WebGPU backend. So on web there is **no SDL and no
SDL_mixer**: windowing, input, text, asset loading, and audio must be served by
browser APIs (DOM events, Canvas2D, `fetch`, Web Audio) behind the same engine
interfaces the demo already uses.

Decisions taken with the user:
- **Real Web Audio** backend (not a stub).
- **Single `Bielik2DDemo` target** with a conditional (`#if os(WASI)`) main.
- Full design + spec + plan, implemented incrementally, before pushing to GitHub.

Two fixes already landed on `main` and fold into this work: WASI scalar-math imports
(`Easing`/`Manifolds`/`Raycast`) and the web vertex-layout fix (pass the full
`Vertex.bufferLayout`, not `prefix(9)`).

## Goals

1. The same `Bielik2DDemo` source (all 11 scenes) builds and runs on macOS/SDL3 and
   in the browser (WASI/WebGPU).
2. The web renderer reaches functional parity with native for what the demo uses:
   `basic` + `sprite` pipelines, alpha + additive blend, text, render-to-canvas,
   sprites, scissor.
3. Input, audio, and text work on web through the existing engine APIs, so scene
   code is unchanged across platforms.
4. Native `swift test` stays green; the web demo is verified per-scene in-browser.

## Non-goals

- Web sprite **atlas** parity with native auto-atlasing — the web sprite path may
  stay simpler as long as it honors the sprite shader's vertex layout (atlas parity
  remains a tracked Phase-14 follow-up).
- Gamepad on web beyond best-effort (browser Gamepad API; reads disconnected if
  absent).
- Pixel-perfect typographic parity between SDL_ttf and Canvas2D text (close is fine;
  optional bundled-TTF-via-FontFace is a stretch goal, see below).

## Architecture

### Platform seam

`App` is refactored from a monolithic `#if canImport(CSDL3)` block into a
platform-agnostic type composed over seams, with the concrete platform selected at
compile time. `App` keeps its current public surface:

```
App(title:width:height:) throws
update(); deltaTime; time; isRunning
input: Input; renderer: <Renderer seam>; audio: Audio?
drawOntoScreen(_:clear:camera:); makeTextEngine(); destroy()
size; sizeInPixels; pixelDensity; driverName; setPresentMode(_:)
```

- **Native** composes `SDL3Platform` + `Renderer` + SDL audio/text (existing code,
  moved behind the seam).
- **Web** composes an expanded `WebPlatform` + `WebRenderer` + Web Audio + Canvas2D
  text, promoted from `Bielik2DWebDemo` into the `Bielik2DWeb` library.

The existing `RenderBackend` protocol (`render(_ list: DrawList, camera:, clear:)`)
is the rendering seam; it is widened so both renderers also provide
`makeTextEngine()`, `makeCanvas()` + render-to-texture, and sprite creation.

### Lifecycle (single target, conditional main)

The per-frame body is shared; only the driver differs.

```swift
func runFrame() {
    app.update()
    // scene-switch handling (arrows / Q-E)
    scene.update(ctx)
    drawHUD()
    app.drawOntoScreen(draw, clear:, camera:)
}

#if os(WASI)
    // JavaScriptEventLoop installed; Task awaits async asset preload, then schedules
    // runFrame() on requestAnimationFrame. Top-level main returns; RAF keeps it alive.
#else
    setup(); while app.isRunning { runFrame() }; app.destroy()
#endif
```

### Renderer parity (`WebRenderer` in `Bielik2DWeb`)

Promote the demo's inline backend into a real renderer:
- **Pipeline cache** keyed by `(shader, blendMode)`, building both `basic` and
  `sprite` pipelines with **alpha** and **additive** blend (mirrors native
  `PipelineCache`).
- **Text engine**: Canvas2D rasterization (`WebTextRasterizer`) producing textured
  quads fed into the `Batcher`, behind the same `TextEngine` interface.
- **Canvas / render-to-texture**: `makeCanvas()` + `render(list, to: canvas)` so
  `TextCanvasScene` works.
- **Sprites**: upload honoring the full `Vertex.bufferLayout` (locations 0–11,
  `uvBounds` included).

### Unified text & `Font`

`Font` becomes platform-specific behind the unchanged `draw.text(_, font:, at:,
color:)` API: native = SDL_ttf (`Font(path:ptSize:)`); web = a `Font` carrying a CSS
font spec, rendered via `WebTextRasterizer`. The demo stops hardcoding
`/System/Library/Fonts/Geneva.ttf`; it uses a cross-platform "system font at pt size"
entry resolving to a TTF on native and a CSS family (e.g. `sans-serif`) on web.
**Stretch goal:** bundle a TTF and load it on web via the `FontFace` API for
typographic parity — deferred unless cheap.

### Input on web

Expand `WebPlatform` to feed the existing `Input`/`Keyboard`/`Mouse`/`Gamepad` API:
- `keydown`/`keyup` → pressed/down/released, via a `KeyboardEvent.code` → `Key` map.
- `mousemove`/`mousedown`/`mouseup` → `Mouse` position (canvas-relative,
  density-scaled) + buttons.
- Browser Gamepad API → `Gamepad` (best-effort; disconnected if unavailable).

Scenes run unmodified.

### Web Audio backend

Implement `Audio`/`Sound` on the Web Audio API behind the interface AudioScene uses
(`app.audio?.makeSound(bytes:)`, `sound.play(pan:pitch:)`):
`AudioContext`; `decodeAudioData(bytes)` → `AudioBuffer`; `play` →
`AudioBufferSourceNode` → `StereoPannerNode(pan)` → destination, `playbackRate =
pitch`. Native `Audio` keeps its SDL_mixer implementation behind the same API.

### Async asset loading

Web `fetch` is async; native file I/O is sync. Introduce an `AssetLoader` seam with
an **async preload pass** that runs before the loop (awaited on web, immediate on
native), populating a synchronous cache so per-frame scene code stays synchronous.
Sprite and sound handles are resolved up front (e.g. a scene-declared asset manifest
loaded during bootstrap).

### Shaders at parity

Run `Shaders/build.sh` (glslang → SPIR-V → naga + hand-written WGSL overrides) so
every native pipeline (`basic`, `sprite`) has current, matching WGSL consistent with
`Vertex.bufferLayout` (locations 0–11). Commit the regenerated `.wgsl`.

### Targets / build

`Package.swift`: `Bielik2DDemo` depends on `Bielik2D` always, plus `Bielik2DWeb` +
`JavaScriptKit`/`JavaScriptEventLoop` **conditionally on `.wasi`**. Remove the
`Bielik2DWebDemo` target. `scripts/build-web.sh` builds `--product Bielik2DDemo` and
copies `Sources/Bielik2DDemo/assets/*` (PNGs, sound, optional font) + the `.wgsl`
shaders + `web/index.html` into `web/dist`.

## Per-scene web compatibility

| Scene | Web status |
|---|---|
| Primitives, Shapes, Flow, Collision, SweptTOI, DrawState | Pure draw/math — work as-is once renderer parity lands |
| Sprites, PixelArt | Need async sprite load + sprite pipeline parity |
| TextCanvas | Needs web text engine + render-to-canvas |
| Input | Needs web keyboard+mouse (gamepad best-effort) |
| Audio | Needs Web Audio backend |

## Testing strategy

- **Native:** existing `swift test` must stay green; the platform seam must not
  change observable native behavior. Add unit tests for pure new logic
  (`KeyboardEvent.code`→`Key` map, pipeline-cache key, pan/pitch mapping math).
- **Web:** build via the wasm SDK; serve `web/dist`; drive with Playwright MCP —
  for each scene, switch to it, screenshot, assert no WebGPU validation warnings and
  that expected geometry/text renders; verify keyboard scene-switching, mouse in
  InputScene, and audible playback path in AudioScene (at least no errors + node
  graph created).
- Work proceeds as incremental red-green commits; FEATURES.md/TODO.md move with the
  capability changes per CLAUDE.md.

## Risks

- **Async asset preload** is the biggest API-shape friction; keep the seam small and
  the per-frame path synchronous.
- **Text parity**: Canvas2D metrics differ from SDL_ttf; HUD layout uses fixed
  offsets and should tolerate minor differences.
- **WebGPU coverage in CI/headless** for verification — local Playwright Chrome has
  WebGPU; the GitHub Pages deploy is build-only (no headless render check).
- **Scope**: large port; sequence so native stays green at every step and web comes
  up scene-by-scene.

## Folded-in prior work

- WASI scalar-math imports (committed).
- Web vertex-layout fix — full `Vertex.bufferLayout` (committed); the `WebRenderer`
  promotion supersedes the inline demo backend it was applied to.
