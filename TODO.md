# Bielik2D — TODO

Bielik2D is a 2D engine inspired by Cute Framework, written in pure Swift 6.3 on top of SDL3's modern GPU API. macOS / Apple Silicon first.

## Working style

- **Red-green-refactor TDD.** Write the failing test first.
- **KISS.** Smallest design that solves the named problem.
- **DRY by the rule of three.** Extract a helper only after the third duplicate.
- **Atomic commits per coherent working change.** Every commit builds and passes tests.
- **Human-voice commit messages.** Lowercase imperative, no Conventional-Commits prefixes, no AI signoffs.

## Stack decisions

- SDL3 + SDL3_image + SDL3_ttf as system libraries (`brew install sdl3 sdl3_image sdl3_ttf`).
- SDL_shadercross vendored as git submodule under `vendor/`, built via `scripts/build-vendor.sh`.
- HLSL → SPIR-V at build time → MSL/DXIL/SPIR-V at runtime via shadercross.
- CF-style unified SDF vertex (sprites + lines + circles + boxes share one vertex layout and one fragment shader).
- Text via SDL3_ttf's `TTF_GPUTextEngine`.

## Out of v0 scope

Audio, networking, deep input, coroutines, aseprite, atlas-based spritebatch, text markup effects.

## Status (current)

Phases 0–11 are substantially complete: the engine builds, `Bielik2DDemo` and `Bielik2DBenchmark` run on macOS/Metal, and `swift test` is green. The renderer was reworked into the CF-style hidden-flush API (Phase 13). Remaining work is in "Known gaps / next".

---

## Phase 0 — Repo bootstrap ✅

- [x] `BootstrapTests.swift` asserts `Bielik2D.version != ""`.
- [x] `.gitignore` (Swift + macOS + `.build/`, `.swiftpm/`, `vendor/.install/`).
- [x] `README.md` with install pre-reqs and getting-started.
- [x] `Package.swift` with library + test + demo + benchmark + web targets.
- [x] `Sources/Bielik2D/Bielik2D.swift` with `public let version`.
- [x] `swift test` green; `git init` + atomic commits.

## Phase 1 — System bindings & C shim ✅

- [x] `SDL3LinkageTests` smoke test (init/quit).
- [x] `Sources/CSDL3/module.modulemap` (SDL3 + image + ttf reachable).
- [x] `Sources/CSDL3Shadercross/module.modulemap` → vendored shadercross.

## Phase 2 — App + Window + GPU device ✅

- [x] App lifecycle (`App(title:width:height:)`, `isRunning`, `update`, `destroy`).
- [x] `SDL3Platform` window + event poll wired to `isRunning`.
- [x] `GPUDevice` (`SDL_CreateGPUDevice` + claim) and present-mode control.

## Phase 3 — GPU resource wrappers ✅ (now internal — see Phase 13)

- [x] `Texture`, `Buffer`, `Sampler`, `TransferBuffer` (with `withMappedMemory`).
- [x] `CommandBuffer`, `RenderPass`, `CopyPass` closure-based wrappers.
- [x] `GPUResourceTests` roundtrips.

## Phase 4 — Shader pipeline ✅

- [x] `vendor/SDL_shadercross` + `scripts/build-vendor.sh`.
- [x] `Shaders/src/*.hlsl` (sprite + basic) → SPIR-V via `Shaders/build.sh`; WGSL overrides for web.
- [x] `Shader` (shadercross load), `GraphicsPipeline`, `PipelineCache` (keyed on color format + blend).

## Phase 5 — Unified SDF vertex + Batcher ✅

- [x] `Vertex` with stride/offset asserts (`VertexTests`).
- [x] `Batcher` with state-change flush + layer sort (`BatcherTests`).
- [x] quad emit helpers.

## Phase 6 — High-level Draw API 🟡

- [x] Generic `StateStack<T>` (`StateStackTests`).
- [x] `pushTransform` / `pushColor` / `pushLayer` (+ `pushScaleMode`, `with { }` — see below).
- [ ] `pushScissor` / `pushViewport` / `pushShapeAA` / `pushBlendState` — not yet implemented.
- [x] `Camera` view/projection, applied as the per-flush view-projection.

## Phase 7 — Sprite loading ✅

- [x] `4x4.png` fixture + `SpriteTests`.
- [x] `Sprite(png:)` (now `renderer.makeSprite(png:)`), `Draw.sprite(_:)`.

## Phase 8 — SDF primitives 🟡

- [x] `circleFill`, `line`, `box` (`PrimitivesTests`).
- [ ] outline `circle`, `boxFill`, `capsule`, `polyline`, `tri`, rounded box — not yet implemented.

## Phase 9 — Canvases (render-to-texture) ✅

- [x] `Canvas(width:height:format:)` (now `renderer.makeCanvas`).
- [x] `renderer.render(_:to: canvas)` flush + `Draw.canvas(_:)` composite (`CanvasTests`).

## Phase 10 — Text rendering (SDL3_ttf + TTF_GPUTextEngine) ✅

- [x] `Geneva.ttf` fixture + `FontTests` / `TextTests`.
- [x] `Font`, `TextEngine` (now `renderer.makeTextEngine`), `Draw.text(_:font:at:)`, cached `Label`.

## Phase 11 — Demo polish ✅

- [x] `Bielik2DDemo`: spinning canvas effect + circle + line + text + pixel-art sprite row.
- [x] `swift test` green; demo runs on Metal.

## Phase 12 — Hygiene 🟡

- [x] GitHub Actions `swift build && swift test` (`.github/workflows/ci.yml`).
- [x] README getting-started.
- [ ] `.swift-format` config.
- [ ] README screenshots.

---

## Done since the v0 plan

- [x] **Pixel-art scale mode** — `ScaleMode { nearest, linear, pixelArt }`, a port of SDL_SCALEMODE_PIXELART's `GetPixelArtUV` into the sprite shaders (HLSL + hand-written WGSL). Carried per-vertex; nearest emulated in-shader (no extra sampler).
- [x] **Scale-mode cascade** — `pushScaleMode`/`popScaleMode` ambient stack + per-call `scaleMode:` override on `Draw.sprite`/`Draw.canvas`; `Sprite.scaleMode` optional. Precedence: call arg → sprite → ambient → linear.
- [x] **`Draw.with { }`** — scoped, auto-popping state (transform/color/layer/scaleMode in one call).

## Phase 13 — CF-style renderer (hide the Batcher) ✅

- [x] `Renderer` owns the GPU flush (pipeline cache, white texture, sampler, pooled vertex buffer).
- [x] `RenderBackend` protocol + `Draw.flush(through:)` + `DrawList` snapshot — the seam that lets two backends (SDL, WebGPU) render without seeing the Batcher.
- [x] `App.drawOntoScreen(_:)` (swapchain) + `Renderer.render(_:to: canvas)` (offscreen); one queue consumed per flush.
- [x] Untextured geometry binds a default white texture at flush (no more demo-side white-texture dance).
- [x] `Sprite`/`Canvas`/`TextEngine` created via `Renderer`; demo + benchmark drop all hand-rolled GPU plumbing.
- [x] `Batcher` + SDL GPU wrappers made internal; public surface = App/Renderer/Draw/Canvas/Camera/Sprite/text + geometry types.
- [~] WebGPU demo ported to `WebRenderer: RenderBackend` — **unverified** (no wasm toolchain locally).

## Known gaps / next

- Remaining CF draw-state stacks: `pushScissor`, `pushViewport`, `pushShapeAA`, `pushBlendState`.
- Remaining SDF primitives: outline `circle`, `boxFill`, `capsule`, `polyline`, `tri`, rounded box.
- Naming: our `ScaleMode` vs CF's `cf_draw_push_filter` (NEAREST/LINEAR/SMOOTH) — consider aligning.
- Verify the WASI/WebGPU build end-to-end (the `WebRenderer` port is untested).
- `.swift-format` config + README screenshots (Phase 12 tail).
