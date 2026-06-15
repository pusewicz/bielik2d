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

Audio, networking, deep input, coroutines, aseprite, text markup effects. Most of these
return as the prioritized post-v0 roadmap below (Phases 16–21), ranked by what unblocks
shipping real games soonest; only networking stays deferred.

## Status (current)

Phases 0–11 are substantially complete: the engine builds, `Bielik2DDemo` and `Bielik2DBenchmark` run on macOS/Metal, and `swift test` is green. The renderer was reworked into the CF-style hidden-flush API (Phase 13), then gained the runtime auto-atlaser (Phase 14) — sprites are packed into shared atlas pages so draw calls collapse to ~one per page. The next
direction is the prioritized CF-parity roadmap in Phases 16–21 below.

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

## Phase 14 — Auto-atlaser (CF-style spritebatch) ✅

CF's online sprite compiler (`cute_spritebatch.h`): push sprites each frame, inject them into rolling
texture atlases at runtime so draw calls collapse to ~one per page. Textures stay hidden; CPU pixels
live in RAM so images are packed lazily on first use. Deferred (push → defrag → resolve at flush),
**no LRU decay yet**. Native-only for now (the web backend keeps its own sprite path).

- [x] `SkylinePacker` — pure skyline bottom-left rectangle packer (no GPU).
- [x] Sub-region texture upload on `CopyPass` (place a small image at x,y within a big atlas page).
- [x] `SpriteBatch` + `AtlasPage` — RAM pixel registry, rolling 2048² pages, `defrag` (pack new +
      upload sub-regions, 1px gutter, dedicated page for oversized images), resolve instances → quads.
- [x] Hide textures: `Sprite` becomes an opaque handle (id + dims); `Renderer` owns the `SpriteBatch`;
      `Draw.sprite` defers; `Renderer` resolves at flush (concat + stable-sort by layer).
- [x] `uvBounds` clamp + local-space pixel-art/nearest snapping in the sprite shaders (HLSL + WGSL).
- [x] `Renderer.lastDrawCallCount` diagnostic; benchmark HUD shows the collapse.

## Phase 15 — Sprite registry & animation API ✅

CF-style ergonomic loading: `Sprite(path:)` (and `Sprite(sheet:...)`) load through a shared,
deduplicating `SpriteRegistry` reached via an ambient `Renderer.current` that `App` installs —
explicit `on:`/`in:` forms remain for tests and multi-context. A `Sprite` is a small POD: a
`SpriteAssetID` plus its current frame's cached id/size, playback cursor, and draw state. A sprite is
fundamentally animated (a PNG is a one-frame animation), so the existing atlas pipeline is untouched —
the new layer sits above it and feeds `SpriteInstance` the cached frame id. PNG-decode only; `.ase`
slots in later behind the same registry.

- [x] Animation model (`PlayMode`, `Frame`, `Animation`, `SpriteAsset`) + pure frame-stepping
      (`Animation.advanced`: loop / once / pingPong, single-frame & zero-duration hold).
- [x] `SpriteRegistry` — path→asset dedup over an injectable `ImageRegistrar` (GPU-free to test);
      `SpriteBatch` conforms.
- [x] `ImageBytes.subImage` + grid sprite-sheet slicing (`sprite(sheet:frameWidth:frameHeight:fps:)`),
      from a file or in-memory pixels.
- [x] `Sprite` rewired to the asset model; `update`/`play`/`pause`/`resume` (static sprites skip the
      registry entirely, so 200k of them cost nothing); `Draw.sprite` reads the cached frame id.
- [x] Ambient `Renderer.current` (App-installed) + `Draw.current`; `Sprite.draw(at:)` sugar.
- [x] Demo showcases `Sprite(path:)` dedup, `sprite.draw(at:)`, and a looping generated sheet.

---

## Post-v0 roadmap — top 5 for gamedev (CF parity)

v0 is a rendering core; these are the next areas that make Bielik2D something you can ship a
game in, ranked by impact (lens: ship games soonest, measured against Cute Framework's API
surface — https://randygaul.github.io/cute_framework/api_reference/). CF's data-structure and
utility modules (array/list/map/string/json/atomic/allocator/path/file/…) are *not* gaps:
Swift's stdlib + Foundation cover them. Sequencing: 16 → 20, interleaving 19 into 18 (both need
capsule/poly shapes). Each phase is independently shippable and demo-able. Big features go on a
worktree, TDD red-green.

## Phase 16 — Input: keyboard (full) + mouse + gamepad 🟡

The #1 blocker: the old surface was `App.keyJustPressed(scancode)` only — no held/released, no
mouse, no gamepad. Now reached via `app.input` (keyboard/mouse/gamepad). CF parity: `down`/
`pressed`/`released` + modifiers; mouse position/buttons/wheel; joypad buttons + analog sticks +
triggers. The action-binding layer and haptic/rumble are the deferred follow-up.

- [x] `Sources/Bielik2D/Input/` — pure-Swift `Key`/`KeyModifiers` + `Keyboard`, `MouseButton` +
      `Mouse`, `GamepadButton`/`GamepadAxis` + `Gamepad` (hot-plug, raw analog axes), aggregated
      by `Input` and exposed as `app.input`. SDL↔enum mappings live in `*+SDL.swift`.
- [x] Per-frame state from the SDL event pump in `Backend/SDL3Platform.swift`; `pollEvents()`
      does begin-frame edge tracking (held / pressed / released) from a current/previous diff.
- [x] Mouse position resolves through the active `Camera` (`Camera.screenToWorld`, via `Mat3x2.inverse`).
- [x] Pure device tests feed synthetic transitions; SDL-bound tests push events through the pump.
- [ ] `InputBinding`/`Action` map ("jump" → key OR button) + haptic/rumble — follow-up worktree.

## Phase 17 — Audio: sound effects + music 🟡

No game ships silent. Built on SDL3_mixer's modern `MIX_*` track API, reached via `app.audio`.
Pitch, gain, stereo pan, and fades are native to the track API — no custom DSP needed after all.

- [x] `Sources/Bielik2D/Audio/` — `Sound` (SFX), `Music` (streamed), `Voice` (volume/pan/pitch/
      stop-with-fade/isPlaying), and the `Audio` mixer façade. `play(loops:)`, `playMusic(fadeIn:)`,
      `crossfade(to:over:)` (true overlap), master volume; ambient `Audio.current` so `Sound(path:)`
      and `sound.play()` mirror `Sprite(path:)`. SFX pitch is dynamic (`MIX_SetTrackFrequencyRatio`).
- [x] `SDL3_mixer` linked through the C shim (`shim.h` + `module.modulemap`); `SDL_INIT_AUDIO`.
- [x] Headless behavioral tests via a **memory mixer** (`MIX_CreateMixer` + `MIX_Generate`): plays →
      signal, gain 0 → silence, pan → channel bias, pitch 2× → half duration, crossfade → overlap.
      In-memory WAV fixture (no committed binary). Demo: space fires a pitched, mouse-panned blip.
- [ ] Deferred (minor): `Voice` pause/resume, per-category buses (`MIX_Group`), 3D positional audio.

## Phase 18 — Collision: 2D shapes + queries 🟡

The gameplay enabler and a signature CF feature; pure math, zero GPU — ideal TDD, reuses
`Sources/Bielik2D/Math/` (`Mat3x2`, `SIMD2`, `Rect`). Core + GJK/EPA shipped; only swept TOI remains.

- [x] `Sources/Bielik2D/Collision/` — `Circle`, `AABB` (min/max + `Rect` bridge), `Capsule`, `Ray`,
      `Polygon` (+ convex-hull builder), `Halfspace`.
- [x] `overlaps`/`manifold(with:)` (contact pt + depth + normal) / `cast(against:)` raycast
      (direction normalized at `Ray` init), protocol-oriented across all shape pairs.
- [x] `gjk` distance/closest-points + EPA penetration for `Polygon` pairs; `distance(to:)` query;
      convex-hull builder; `Polygon`/`Halfspace` shapes.
- [ ] swept `toi` for continuous collision (deferred follow-up).
- [x] Debug-draw shapes via `Draw.debug(_:)` (capsule SDF pulled forward from Phase 19).
- [x] Predicates tested against hand-computed expected results.

## Phase 19 — Draw completeness: shapes, state stacks, text effects ⏳

Half-built already (Phases 6/8), high return per effort, supports collision debug-draw + HUD.

- [ ] SDF primitives: outline `circle`, `boxFill`, `capsule`, `polyline`, `tri`, rounded box —
      extend `Draw/Primitives.swift` + the unified SDF shader (`Shaders/src/*.hlsl` + WGSL
      overrides; capsule/poly add `ShapeType` branches).
- [ ] Draw-state stacks `pushScissor` / `pushViewport` / `pushBlendState` / `pushShapeAA`
      (reuse the generic `StateStack<T>` in `Draw.swift`).
- [ ] Text effects (color markup, outline, shadow) in `Sources/Bielik2D/Text/`.
- [ ] Align `ScaleMode` naming with CF's `cf_draw_push_filter` (NEAREST/LINEAR/SMOOTH).

## Phase 20 — Coroutines & tweening: game-logic flow ✅

The ergonomics multiplier: cutscenes, AI scripts, timed sequences, UI animation — where game
feel comes from. Built as frame-stepped `FlowStep`s with overflow forwarding (mirrors
`Animation.advanced`); the `Routine { … }` / `Parallel { … }` / `Repeat { … }` result-builder DSL
is the ergonomic surface. Tweens write through a `ReferenceWritableKeyPath` onto a reference
target (start value captured lazily, target held weakly). `App` owns a `Clock`, exposes
`deltaTime` / `time`, and auto-drives `Flow.current` each `update()`.

- [x] `Sources/Bielik2D/Flow/` — frame-stepped `Tween` (keypath/to/duration/easing) + a
      coroutine/sequence runner (`Flow`, `Routine`/`Parallel`/`Repeat`/`Wait`/`Run`, cancellable
      `RoutineHandle`). Explicit frame-stepping over Swift `async`; reuses `App/Time.swift`'s `Clock`.
- [x] Easing-function set (`Easing.swift`) — the full Penner set (in/out/inOut across
      quad/cubic/quart/quint/sine/expo/circ/back/elastic/bounce + linear).
- [x] `Lerpable` (Float/Double/SIMD2/Color/Rect); tween interpolation + coroutine stepping tested
      deterministically with a fixed `dt`.

## Phase 21 — Aseprite + sprite polish (honorable mention) ⏳

Narrower than 16–20 (PNG sheets already ship), so it trails the top 5.

- [ ] `.ase` decoder feeding the existing `SpriteRegistry`/animation model — the registry,
      playback, and named-animation lookup already exist; this is a decoder producing multiple
      animations instead of one `"default"`.
- [ ] Phase-14 atlas follow-ups: LRU decay/eviction (`tick()` + space reclaim / page compaction);
      unified ordered draw buffer so sprites interleave with shapes/text within a layer by call
      order; put the white pixel in the atlas so SDF shapes batch with sprites; web-backend
      atlas parity.

## Deferred

- Networking (`net`), web/browser (`web`) — single-player, native-first for now; verify the
  WASI/WebGPU `WebRenderer` port (Phase 13, untested) before any web push.
- `random` / `noise` / broader `math` beyond easing — useful for procedural gen, not on the
  critical path to a first game.
- Hygiene tail: `.swift-format` config + README screenshots (Phase 12).
