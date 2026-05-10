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

---

## Phase 0 — Repo bootstrap

- [ ] `BootstrapTests.swift` asserts `Bielik2D.version != ""`.
- [ ] `.gitignore` (Swift + macOS + `.build/`, `.swiftpm/`, `vendor/.install/`).
- [ ] `README.md` with install pre-reqs and getting-started.
- [ ] Minimal `Package.swift`: `Bielik2D` library + `Bielik2DTests` test target. Defer everything else.
- [ ] `Sources/Bielik2D/Bielik2D.swift` with `public let version`.
- [ ] `swift test` green.
- [ ] `git init` + atomic commits.

## Phase 1 — System bindings & C shim

- [ ] `SDL3LinkageTests.testInitQuit` — calls `SDL_Init(SDL_INIT_VIDEO)` then `SDL_Quit()`.
- [ ] `Sources/CSDL3/module.modulemap` → `SDL3/SDL.h`, link `SDL3`.
- [ ] `Sources/CSDL3Image/module.modulemap` → `SDL3_image/SDL_image.h`.
- [ ] `Sources/CSDL3TTF/module.modulemap` → `SDL3_ttf/SDL_ttf.h`.
- [ ] `Sources/CBielik2DSupport/{include/bielik2d_support.h, bielik2d_support.c}` (empty for now; add helpers as needed).
- [ ] Smoke test passes.

## Phase 2 — App + Window + GPU device

- [ ] `AppTests.testMakeAppHeadless` — uses offscreen video driver hint, lifecycle round-trips.
- [ ] `App.swift` — `Bielik2D.makeApp(title:, width:, height:, options:)`.
- [ ] `Window.swift`, `Time.swift`.
- [ ] `GPUDevice.swift` — `SDL_CreateGPUDevice` + `SDL_ClaimWindowForGPUDevice`.
- [ ] `Swapchain.swift` — present mode, composition.
- [ ] Event poll loop wired to `isRunning`.
- [ ] Demo opens a window, clears, closes.

## Phase 3 — GPU resource wrappers

- [ ] `GPUResourceTests` — roundtrip per resource (no-error asserts).
- [ ] `Texture` (upload via TransferBuffer + CopyPass).
- [ ] `Buffer` (vertex / index / storage).
- [ ] `Sampler`.
- [ ] `TransferBuffer.withMappedMemory { ptr in … }`.
- [ ] `CommandBuffer`, `RenderPass`, `CopyPass` — closure-based.

## Phase 4 — Shader pipeline

- [ ] `vendor/SDL_shadercross` + `vendor/SPIRV-Cross` submodules.
- [ ] `scripts/build-vendor.sh` — CMake build → `vendor/.install/`.
- [ ] `Sources/CSDL3Shadercross/module.modulemap` → `vendor/.install/include/SDL3_shadercross/SDL_shadercross.h`.
- [ ] `PipelineCacheTests.testSameDescriptorReturnsSamePipeline` (pure dictionary).
- [ ] `Shaders/src/builtin_draw.hlsl` (VS + FS, sprite/SDF branch in FS).
- [ ] `Shaders/build.sh` — `dxc -spirv` → `Sources/Bielik2D/Shaders/*.spv`.
- [ ] `Shader.swift` — loads SPIR-V via `SDL_ShaderCross_CompileGraphicsShaderFromSPIRV`.
- [ ] `GraphicsPipeline.swift`, `PipelineCache.swift`.
- [ ] Demo prints `SDL_GetGPUDeviceDriver()` and creates a no-op pipeline.

## Phase 5 — Unified SDF vertex + Batcher

- [ ] `VertexLayoutTests.testStrideMatchesAttributeOffsets`.
- [ ] `Vertex.swift` — mirrors CF `CF_Vertex` (pos, uv, n, shape[8], color, radius, stroke, aa, type, alpha, fill, posH, attributes, uvBounds).
- [ ] `BatcherTests.testStateChangeFlushesCommand`.
- [ ] `BatcherTests.testNoStateChangeMergesIntoOneCommand`.
- [ ] `BatcherTests.testLayerOrderingInCommandList`.
- [ ] `Batcher.swift`, `CommandList.swift`.
- [ ] `emitQuad(p0, p1, p2, p3, uv0, uv1, color)` helper.
- [ ] Hardcoded quad with 1×1 white texture shows on screen.

## Phase 6 — High-level Draw API

- [ ] `StateStackTests.testPushPopPeek`.
- [ ] `DrawAPITests.testTransformStackComposition`.
- [ ] `DrawAPITests.testColorTintMultipliesIntoVertex`.
- [ ] Generic `StateStack<T>`.
- [ ] `Draw.pushTransform/popTransform`, `pushColor/popColor`, `pushScissor`, `pushViewport`, `pushLayer`, `pushShapeAA`, `pushBlendState`.
- [ ] `Camera` — view, projection, uploaded as `viewProjection` uniform per frame.

## Phase 7 — Sprite loading

- [ ] `Tests/Bielik2DTests/fixtures/4x4.png` committed.
- [ ] `SpriteTests.testLoadPNGFromFixture` (RGBA pixel asserts).
- [ ] `SpriteTests.testDrawEmitsOneTexturedQuad`.
- [ ] `Sprite` struct + `Sprite(png:)` via `IMG_Load`.
- [ ] `Draw.sprite(_:)`.

## Phase 8 — SDF primitives

- [ ] `PrimitivesTests` — one assertion per shape (circle, box, line, capsule, polyline, tri) on the unified SDF vertex.
- [ ] `emitSDFQuad(type:, params:)` shared helper.
- [ ] `Draw.circle`, `circleFill`, `box`, `boxFill`, `line`, `capsule`, `polyline`, `tri`.
- [ ] Demo shows a circle outline + rounded box + line.

## Phase 9 — Canvases (render-to-texture)

- [ ] `CanvasTests.testRenderToSwapsActiveTarget`.
- [ ] `Canvas(width:, height:, format:, msaaSamples:)`.
- [ ] `Canvas.renderTo { … }` swaps the active render target.
- [ ] `Draw.canvas(_:)` samples canvas as sprite.
- [ ] Demo renders sprite into a canvas and composites it back.

## Phase 10 — Text rendering (SDL3_ttf + TTF_GPUTextEngine)

- [ ] `Tests/Bielik2DTests/fixtures/<font>.ttf` committed.
- [ ] `FontTests.testOpenFontFromFixture`.
- [ ] `TextTests.testDrawTextEmitsQuadsForEachGlyph`.
- [ ] `TTF_Init()` in app init.
- [ ] `Font(path:, ptSize:)`.
- [ ] One `TTF_GPUTextEngine` bound to our device.
- [ ] `Draw.text(_:, at:, font:)` → `TTF_CreateText` → `TTF_GetGPUTextDrawData` → batched quads.
- [ ] Cache `TTF_Text` keyed by (font, content).

## Phase 11 — Demo polish

- [ ] `Bielik2DDemo/main.swift` — spinning sprite + circle outline + bouncing text + canvas effect.
- [ ] Fill in missing math edge cases as discovered (`Mat3x2.invert` near-singular, etc.).
- [ ] `swift test` fully green, `swift run Bielik2DDemo` at 60 fps with vsync.

## Phase 12 — Hygiene

- [ ] `.swift-format` config.
- [ ] GitHub Actions `swift build && swift test` on macOS.
- [ ] README screenshots and getting-started.
