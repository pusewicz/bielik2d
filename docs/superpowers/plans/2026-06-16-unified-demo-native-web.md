# Unified `Bielik2DDemo` (native + web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the real 11-scene `Bielik2DDemo` build and run on both macOS/SDL3 and the browser (WASI/WebGPU) from one source, with the web renderer, text, input, and audio at functional parity.

**Architecture:** A **twin-`App`** seam. The native `App` stays in `Bielik2D` under `#if canImport(CSDL3)`; a web `App` with the *identical public API* lives in `Bielik2DWeb` under `#if os(WASI)`. Only one compiles per platform, so the demo and scenes — which only touch `App`, `Draw`, `Font`, `Input`, `Camera`, `Audio`, `Sprite`, `Scene` — compile unchanged on both. Cross-platform seams (`TextEngine`, `AssetLoader`, `Audio`/`Sound`) live in `Bielik2D`; their web implementations live in `Bielik2DWeb`. `Bielik2DDemo` gains a conditional dependency on `Bielik2DWeb`+JavaScriptKit on `.wasi` and a `#if os(WASI)` main (RAF loop) vs native (while loop). The separate `Bielik2DWebDemo` target is removed.

**Tech stack:** Swift 6.3 (swift.org wasm SDK, `wasm32-unknown-wasip1`), SDL3 GPU (native), WebGPU + Web Audio + Canvas2D via JavaScriptKit (web), PackageToJS, naga (shader WGSL).

**Spec:** `docs/superpowers/specs/2026-06-16-unified-demo-native-web-design.md`

**Conventions for every commit:** sign-off disabled (`git -c commit.gpgsign=false commit ...`), human-voice messages (no Conventional Commits prefixes, no AI signoff), atomic. After each phase, native `swift build && swift test` must stay green; web is built with `./scripts/build-web.sh` and verified in-browser with the Playwright MCP against `python3 -m http.server -d web/dist 8000`.

---

## File structure (created / modified)

**Cross-platform seams (in `Bielik2D`, no SDL guard):**
- `Sources/Bielik2D/Text/TextEngine.swift` — make `TextEngine` a protocol (or keep concrete native + add a protocol the web engine conforms to) and ensure `Font`'s public API is platform-neutral.
- `Sources/Bielik2D/Draw/AssetLoader.swift` (new) — `protocol AssetLoader` + a sync texture cache type.
- `Sources/Bielik2D/Audio/Audio.swift` — split into a platform-neutral `Audio`/`Sound` API + native SDL_mixer impl behind `#if canImport(CSDL3)`.

**Web implementations (in `Bielik2DWeb`, `#if os(WASI)`):**
- `Sources/Bielik2DWeb/WebApp.swift` (new) — web `App` mirroring native `App`'s API.
- `Sources/Bielik2DWeb/WebRenderer.swift` (new; promote from `Bielik2DWebDemo/main.swift`) — pipeline cache, text engine, canvas, sprites, `render`.
- `Sources/Bielik2DWeb/WebPlatform.swift` — expand: keyup, mouse, gamepad, feed `Input`.
- `Sources/Bielik2DWeb/WebAudio.swift` (new) — Web Audio `Audio`/`Sound`.
- `Sources/Bielik2DWeb/WebFont.swift` (new) — web `TextEngine` + font (CSS) via `WebTextRasterizer`.
- `Sources/Bielik2DWeb/WebAssetLoader.swift` — conform to `AssetLoader`.

**Demo (single target):**
- `Sources/Bielik2DDemo/main.swift` — extract `runFrame()`, conditional loop.
- `Sources/Bielik2DDemo/Scene.swift` — `SceneContext` unchanged if possible.
- Scene files — should need **no** changes; verify per phase.

**Build:**
- `Package.swift` — `Bielik2DDemo` conditional deps; remove `Bielik2DWebDemo`.
- `scripts/build-web.sh` — `--product Bielik2DDemo`; copy demo `assets/`.
- `Shaders/build.sh` outputs — regenerate `.wgsl`.

---

## Phase 0 — Baseline & shader regeneration

### Task 0.1: Confirm green baseline
- [ ] **Step 1:** Run native build+test.
  Run: `swift build && swift test`
  Expected: PASS (baseline before refactor).
- [ ] **Step 2:** Build web and snapshot current behavior.
  Run: `./scripts/build-web.sh` then serve and open in Playwright; screenshot the current minimal demo.
  Expected: builds; minimal demo renders (sprite/SDF/text), 0 WebGPU warnings.

### Task 0.2: Regenerate WGSL shaders at parity
**Files:** `Shaders/src/*.hlsl`, `Shaders/wgsl/*` (overrides), output `Sources/Bielik2D/Resources/shaders/*.wgsl`
- [ ] **Step 1:** Run `./Shaders/build.sh`. Confirm `naga` is on PATH (`command -v naga`).
- [ ] **Step 2:** Diff the regenerated `.wgsl` against committed. For each of `basic.vert/frag`, `sprite.vert/frag`, confirm the vertex inputs match `Vertex.bufferLayout` (locations 0–11; sprite consumes 0–8,10,11). Keep hand-written overrides where naga output is wrong (document why in a header comment, as the existing `sprite.vert.wgsl` does).
- [ ] **Step 3:** Native build still green: `swift build`.
- [ ] **Step 4:** Commit.
  `git -c commit.gpgsign=false commit -am "regenerate WGSL shaders for both pipelines"`

---

## Phase 1 — Cross-platform Audio API seam

Goal: `Audio`/`Sound` becomes a platform-neutral API in `Bielik2D`; native impl stays behind `#if canImport(CSDL3)`. No web impl yet — just the seam, native stays green.

### Task 1.1: Extract the Audio/Sound public protocol
**Files:** Modify `Sources/Bielik2D/Audio/Audio.swift`
- [ ] **Step 1:** Read the current `Audio` and `Sound` types and `AudioScene` usage to capture the exact public API used by the demo: `Audio()` init, `Audio.current`, `makeSound(bytes:)`, `Sound.play(pan:pitch:)`, `Audio.update()`, `Audio.destroy()`.
- [ ] **Step 2:** Define platform-neutral protocols (or a neutral class with a backing) so the same names resolve on web. Recommended: keep concrete `final class Audio`/`final class Sound` names but move the SDL_mixer body behind `#if canImport(CSDL3)`, and let `Bielik2DWeb` provide the `#if os(WASI)` variants with the same names in that module. (Mirrors the twin-`App` approach.) Ensure `AudioScene` only references the neutral surface.
- [ ] **Step 3:** `swift build && swift test` — native green.
- [ ] **Step 4:** Commit: `"carve the audio API into a platform-neutral surface"`.

---

## Phase 2 — AssetLoader seam + async preload

Goal: introduce a small `AssetLoader` protocol and a synchronous texture cache, plus an async preload entrypoint, without changing native behavior (native loader becomes a conformer; sync path preserved).

### Task 2.1: Define `AssetLoader` + cache
**Files:** Create `Sources/Bielik2D/Draw/AssetLoader.swift`
- [ ] **Step 1:** Write the protocol and a cache keyed by path. Full code:

```swift
/// Loads image bytes/textures for sprites. Native loads synchronously from disk;
/// web fetches asynchronously. The demo preloads through `prefetch` before its
/// loop so per-frame scene code reads from the populated cache synchronously.
public protocol AssetLoader: AnyObject {
    /// Asynchronously ensure `path` is resident. On native this may complete
    /// immediately; on web it awaits `fetch`/`createImageBitmap`.
    func prefetch(_ paths: [String]) async throws
    /// Synchronous lookup of an already-prefetched image's decoded RGBA bytes
    /// and size, or nil if not yet resident.
    func image(_ path: String) -> LoadedImage?
}

public struct LoadedImage {
    public let width: Int
    public let height: Int
    public let rgba: [UInt8]      // tightly packed, RGBA8, top-left origin
    public init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = width; self.height = height; self.rgba = rgba
    }
}
```
- [ ] **Step 2:** `swift build` — compiles (no consumers yet).
- [ ] **Step 3:** Commit: `"add an AssetLoader seam with an async prefetch pass"`.

### Task 2.2: Native loader conforms
**Files:** Modify `Sources/Bielik2D/Backend/SDL3AssetLoader.swift`, sprite registry path.
- [ ] **Step 1:** Read current `SDL3AssetLoader.loadImage(path:)` and `SpriteRegistry`. Make the native loader conform to `AssetLoader` (sync `prefetch` decodes into the cache via existing `IMG_Load` path; `image(_:)` returns the cached `LoadedImage`).
- [ ] **Step 2:** Keep existing synchronous `Sprite(path:)` working (it can call `prefetch` synchronously on native then read the cache).
- [ ] **Step 3:** `swift build && swift test` — native green; sprites still load in SpritesScene (run `swift run Bielik2DDemo` briefly or rely on tests).
- [ ] **Step 4:** Commit: `"make the SDL asset loader conform to AssetLoader"`.

---

## Phase 3 — Web renderer parity (promote & extend)

Goal: move the inline `WebRenderer`/`WebGPURenderBackend` logic out of `Bielik2DWebDemo/main.swift` into `Bielik2DWeb` as a reusable renderer with a pipeline cache (basic+sprite × alpha+additive), text engine, canvas, and sprite upload. The old minimal demo still builds against it during this phase.

### Task 3.1: Promote WebRenderer into the library
**Files:** Create `Sources/Bielik2DWeb/WebRenderer.swift`; trim `Sources/Bielik2DWebDemo/main.swift`.
- [ ] **Step 1:** Move the WebGPU device/context/queue setup and the `RenderBackend.render(_:camera:clear:)` implementation from the demo `main.swift` into `WebRenderer` (a `final class WebRenderer: RenderBackend`). Keep the existing single-pipeline path working first.
- [ ] **Step 2:** `./scripts/build-web.sh` — builds; in-browser the minimal demo still renders, 0 warnings.
- [ ] **Step 3:** Commit: `"promote the web renderer into Bielik2DWeb"`.

### Task 3.2: Pipeline cache (basic+sprite × blend modes)
**Files:** `Sources/Bielik2DWeb/WebRenderer.swift`; new `Sources/Bielik2DWeb/WebPipelineCache.swift`.
- [ ] **Step 1 (test):** Add a pure unit test for the pipeline key in `Tests/Bielik2DTests` (compiles on native too if key type lives in a neutral spot, else a web-only sanity check). Key type:

```swift
struct WebPipelineKey: Hashable { let shader: ShaderID; let blend: BlendMode }
enum ShaderID: Hashable { case basic, sprite }
```
- [ ] **Step 2:** Implement a cache `[WebPipelineKey: JSObject]` building pipelines lazily from the matching `.wgsl` modules, with blend state per `BlendMode` (alpha = src-alpha/one-minus-src-alpha; additive = src-alpha/one). Drive selection from each `DrawCommand`'s shader+blend (mirror native `Renderer.resolvedGeometry`/`PipelineCache`).
- [ ] **Step 3:** `./scripts/build-web.sh`; in-browser verify a scene using additive blend (DrawStateScene later) — for now assert pipelines build with 0 warnings.
- [ ] **Step 4:** Commit: `"cache web pipelines per shader and blend mode"`.

### Task 3.3: Web TextEngine + canvas render-to-texture
**Files:** Create `Sources/Bielik2DWeb/WebFont.swift`; extend `WebRenderer` with `makeTextEngine()`, `makeCanvas()`, `render(_:to:clear:camera:)`.
- [ ] **Step 1:** Define web `TextEngine` conforming to the neutral seam (Phase 5 makes `Font`/`TextEngine` neutral; if ordering bites, do Phase 5 first). It rasterizes glyph runs via `WebTextRasterizer` (Canvas2D) into a texture and emits quads into the batcher, matching the native `TextEngine` contract.
- [ ] **Step 2:** Implement `makeCanvas()` returning a `Canvas` whose backing is an offscreen WebGPU texture, and `render(list, to: canvas)`.
- [ ] **Step 3:** `./scripts/build-web.sh`; defer in-browser text verification to Phase 5/6.
- [ ] **Step 4:** Commit: `"add web text engine and render-to-canvas"`.

### Task 3.4: Web sprite upload
**Files:** `WebRenderer.swift`
- [ ] **Step 1:** Implement sprite/texture creation from `LoadedImage` (via `device.createTexture` + `queue.writeTexture`, or `copyExternalImageToTexture` from an ImageBitmap) honoring the full `Vertex.bufferLayout` (the `uvBounds` location-11 fix folds in here).
- [ ] **Step 2:** `./scripts/build-web.sh`; verify sprite still draws in the minimal demo.
- [ ] **Step 3:** Commit: `"upload web sprites through the full vertex layout"`.

---

## Phase 4 — Web `App` (lifecycle parity)

Goal: a web `App` in `Bielik2DWeb` with the same API as native `App`, wiring `WebPlatform` + `WebRenderer` + `WebAudio` + clock + flow.

### Task 4.1: WebApp skeleton
**Files:** Create `Sources/Bielik2DWeb/WebApp.swift`
- [ ] **Step 1:** Implement `public final class App` under `#if os(WASI)` mirroring native: `init(title:width:height:)` (attaches `WebPlatform`, creates `WebRenderer`), `update()` (drain events, tick a JS-clock delta, advance `Flow`), `deltaTime`, `time`, `isRunning`, `input`, `renderer`, `audio`, `drawOntoScreen(_:clear:camera:)`, `makeTextEngine()`, `destroy()`, `size`, `sizeInPixels`, `pixelDensity`, `driverName` ("webgpu"). The blocking loop is NOT here — the demo's web main drives `runFrame()` from RAF; `App` exposes a way to schedule it (reuse `WebPlatform.run`).
- [ ] **Step 2:** `./scripts/build-web.sh` — compiles (not yet used by the demo).
- [ ] **Step 3:** Commit: `"add a web App mirroring the native lifecycle"`.

---

## Phase 5 — Neutralize `Font`/`TextEngine`

Goal: `Draw.text(_, font:, …)` compiles on web. `Font` and `TextEngine` get platform-neutral public surfaces; native = SDL_ttf, web = CSS/Canvas2D.

### Task 5.1: Make `Font`/`TextEngine` neutral
**Files:** `Sources/Bielik2D/Text/Font.swift`, `Sources/Bielik2D/Text/TextEngine.swift`, `Sources/Bielik2D/Draw/Text.swift`
- [ ] **Step 1:** Read the three files; capture `Draw.text` signature and what it needs from `Font`/`TextEngine`.
- [ ] **Step 2:** Introduce a neutral `Font` surface (twin-type like `App`: native `Font` under `#if canImport(CSDL3)`, web `Font` in `Bielik2DWeb` under `#if os(WASI)`, same init shape used by the demo). Provide a cross-platform constructor used by the demo: `Font.system(ptSize:)` resolving to a bundled/system TTF on native and a CSS family on web — replacing the hardcoded `/System/Library/Fonts/Geneva.ttf`.
- [ ] **Step 3:** Native `swift build && swift test` green; web `./scripts/build-web.sh` compiles.
- [ ] **Step 4:** Commit: `"give Font a cross-platform system() entry"`.

---

## Phase 6 — Web input parity

**Files:** `Sources/Bielik2DWeb/WebPlatform.swift`, new `Sources/Bielik2D/Input/KeyCodeMap.swift` (neutral map test), `WebApp` wiring.

### Task 6.1: KeyboardEvent.code → Key map (pure, tested)
- [ ] **Step 1 (test):** In `Tests/Bielik2DTests/KeyCodeMapTests.swift`:

```swift
import Testing
@testable import Bielik2D

@Test func mapsCommonCodes() {
    #expect(Key(browserCode: "ArrowLeft") == .left)
    #expect(Key(browserCode: "KeyQ") == .q)
    #expect(Key(browserCode: "Space") == .space)
    #expect(Key(browserCode: "Nonsense") == nil)
}
```
- [ ] **Step 2:** Run: `swift test --filter KeyCodeMapTests` → FAIL (no initializer).
- [ ] **Step 3:** Add `init?(browserCode:)` to `Key` (neutral, in `Bielik2D`) covering the codes the scenes use (arrows, Q/E, WASD, Space, digits as needed).
- [ ] **Step 4:** Run: `swift test --filter KeyCodeMapTests` → PASS.
- [ ] **Step 5:** Commit: `"map browser key codes to Key"`.

### Task 6.2: Feed keyboard/mouse/gamepad into `Input` on web
- [ ] **Step 1:** Expand `WebPlatform`: add `keyup` (release), `mousemove`/`mousedown`/`mouseup` (canvas-relative, density-scaled), and poll the Gamepad API each frame. Replace the `keyJustPressed(String)` shim by populating the shared `Input`/`Keyboard`/`Mouse`/`Gamepad` state (same objects native uses) inside `App.update()`.
- [ ] **Step 2:** `./scripts/build-web.sh`; in-browser verify (once the demo is unified, Phase 8) keyboard scene-switching and mouse in InputScene. For now assert it compiles + no console errors.
- [ ] **Step 3:** Commit: `"feed keyboard, mouse, and gamepad into web Input"`.

---

## Phase 7 — Web Audio backend

**Files:** Create `Sources/Bielik2DWeb/WebAudio.swift`

### Task 7.1: Pan/pitch mapping (pure, tested)
- [ ] **Step 1 (test):** In `Tests/Bielik2DTests/AudioParamTests.swift` test the clamp/mapping helper (kept neutral in `Bielik2D`):

```swift
@Test func clampsPanAndPitch() {
    #expect(AudioParams.clampPan(-2) == -1)
    #expect(AudioParams.clampPan(2) == 1)
    #expect(AudioParams.clampPitch(0) == 0.0001)   // never <= 0 (playbackRate)
}
```
- [ ] **Step 2:** Run → FAIL; add `AudioParams` helper; Run → PASS.
- [ ] **Step 3:** Commit: `"add audio pan/pitch clamping helper"`.

### Task 7.2: Web Audio `Audio`/`Sound`
- [ ] **Step 1:** Implement `#if os(WASI)` `Audio`/`Sound` in `Bielik2DWeb` with the neutral API: `Audio()` creates an `AudioContext`; `makeSound(bytes:)` calls `decodeAudioData` (await; cache the buffer); `Sound.play(pan:pitch:)` builds `AudioBufferSourceNode` → `StereoPannerNode(pan)` → destination with `playbackRate = pitch`; `update()`/`destroy()` no-ops/teardown.
- [ ] **Step 2:** Wire `WebApp.audio`. `./scripts/build-web.sh`.
- [ ] **Step 3:** Commit: `"implement a Web Audio backend"`.

---

## Phase 8 — Unify the demo target & main

**Files:** `Package.swift`, `Sources/Bielik2DDemo/main.swift`, remove `Sources/Bielik2DWebDemo/`, `scripts/build-web.sh`.

### Task 8.1: Package wiring
- [ ] **Step 1:** In `Package.swift`: add to `Bielik2DDemo` dependencies `Bielik2DWeb` + `JavaScriptKit` + `JavaScriptEventLoop` with `condition: .when(platforms: [.wasi])`. Remove the `Bielik2DWebDemo` executable target and (if unused elsewhere) leave `Bielik2DWeb` library product. Keep demo `resources: [.copy("assets")]`.
- [ ] **Step 2:** `swift build` (native) green.
- [ ] **Step 3:** Commit: `"point the demo target at the web stack on wasi"`.

### Task 8.2: Conditional main
- [ ] **Step 1:** Refactor `Sources/Bielik2DDemo/main.swift`: extract `runFrame()` containing the body of the current while-loop (scene switch, `scene.update`, `drawHUD`, `app.drawOntoScreen`). Replace font construction with `Font.system(ptSize:)`. Then:

```swift
#if os(WASI)
import JavaScriptEventLoop
JavaScriptEventLoop.installGlobalExecutor()
Task {
    try await assetLoader.prefetch(demoAssetManifest)   // sprites, sounds
    scenes[current].onEnter(makeContext(dt: 0, time: 0))
    app.startLoop(runFrame)            // schedules runFrame on requestAnimationFrame
}
#else
scenes[current].onEnter(makeContext(dt: 0, time: 0))
while app.isRunning { runFrame() }
app.destroy()
#endif
```
- [ ] **Step 2:** Ensure `App` (both) expose `startLoop(_:)` (web schedules RAF via `WebPlatform.run`; native can provide it too or stay while-loop). Keep `makeContext`/`drawHUD`/`scenes` shared.
- [ ] **Step 3:** `swift build && swift test` native green; `./scripts/build-web.sh` builds `Bielik2DDemo`.
- [ ] **Step 4:** Update `scripts/build-web.sh`: `--product Bielik2DDemo`; copy `Sources/Bielik2DDemo/assets/*` into `web/dist/assets/`. Remove references to `Bielik2DWebDemo`.
- [ ] **Step 5:** Commit: `"run the one demo from a conditional main"`.

---

## Phase 9 — Per-scene web verification & polish

For each scene, build web, serve, drive with Playwright: switch to the scene (keyboard), screenshot, assert 0 WebGPU validation warnings and expected content.

### Task 9.1: Pure-draw scenes
- [ ] Verify Primitives, Shapes, Flow, Collision, SweptTOI, DrawState (additive blend + scissor) render correctly in-browser. Fix renderer gaps found. Commit fixes individually.

### Task 9.2: Sprites & PixelArt
- [ ] Add the demo asset manifest; verify sprites and scale modes render (async prefetch path). Commit.

### Task 9.3: TextCanvas & HUD
- [ ] Verify HUD text and `TextCanvasScene` (render-to-canvas) render; tolerate minor Canvas2D metric differences. Commit.

### Task 9.4: Input & Audio scenes
- [ ] Verify InputScene (keyboard/mouse; gamepad best-effort) and AudioScene (audible playback / node graph created, pan & pitch). Commit.

### Task 9.5: Docs + FEATURES/TODO
- [ ] **Step 1:** Update `FEATURES.md` web row (the same `Bielik2DDemo` now runs on web with full renderer/input/audio/text parity; note remaining atlas gap) and `README.md` (web build runs the real demo; how to build). Tick the matching `TODO.md` items. (Use the `update-features` skill.)
- [ ] **Step 2:** Commit: `"document the unified web demo"`.

---

## Self-review notes (coverage vs spec)

- Platform seam → Phases 1,2,4,5 (Audio, AssetLoader, WebApp, Font/TextEngine). ✓
- Lifecycle conditional main → Phase 8. ✓
- Renderer parity (pipelines, text, canvas, sprites) → Phase 3. ✓
- Unified text/`Font` → Phase 5. ✓
- Web input → Phase 6. ✓
- Web Audio → Phase 7. ✓
- Async assets → Phase 2 + Phase 8 preload. ✓
- Shaders parity → Phase 0.2. ✓
- Targets/build → Phase 8. ✓
- Testing (native green each phase; web per-scene Playwright) → built into every phase + Phase 9. ✓

**Known plan-level uncertainty (resolve while executing by reading internals):** exact bodies of native `Renderer`/`PipelineCache`, `TextEngine`, `Audio`, and `WebGPURenderBackend` are not reproduced here; tasks specify the seam and transformation, and the executor must read those files before editing. Phase ordering note: Phase 5 (neutral `Font`/`TextEngine`) may need to precede Phase 3.3 — do 5 first if the web text engine can't compile against the seam yet.
