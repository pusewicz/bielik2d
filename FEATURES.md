# Bielik2D — Features vs. Cute Framework

Bielik2D is a 2D engine inspired by [Cute Framework](https://randygaul.github.io/cute_framework/)
(CF), written in pure Swift 6.3 on SDL3's modern GPU API. This file tracks how the engine's
feature set stacks up against CF's [API reference](https://randygaul.github.io/cute_framework/api_reference/),
so it's clear what ships today and what's next. Phase numbers refer to [TODO.md](TODO.md).

**Legend:** ✅ shipped · 🟡 partial · ⏳ planned · ⛔ deferred · ➖ N/A (Swift stdlib/Foundation covers it)

---

## Engine modules

These are the modules where Bielik2D and CF actually compete — the engine surface a game is built on.

| CF module | Bielik2D | Notes |
|---|---|---|
| **app** | ✅ | `App(title:width:height:)`, `isRunning`/`update`/`destroy`, window + GPU device, present-mode control, drawable pixel size + density. |
| **graphics** | ✅ | Low-level GPU (pipelines, buffers, textures, samplers, passes) wrapped and hidden behind `Renderer`; HLSL→SPIR-V→MSL via shadercross. Public surface stays CF-style high-level. |
| **draw** | 🟡 | `quad`/`sprite`/`canvas`, SDF `circleFill`/`line`/`box`. Scoped state via `with{}` + `pushTransform`/`pushColor`/`pushLayer`/`pushScaleMode`. **Missing:** outline `circle`, `boxFill`, `capsule`, `polyline`, `tri`, rounded box; `pushScissor`/`pushViewport`/`pushBlendState`/`pushShapeAA`. (Phase 19) |
| **sprite** | ✅ | `Sprite(path:)` with dedup via shared registry; animation model (loop/once/pingPong), `update`/`play`/`pause`/`resume`, runtime auto-atlaser packing into rolling 2048² pages (~one draw call per page). |
| **custom_sprite** | ✅ | In-memory sheets via `makeSprite(sheet:frameWidth:frameHeight:fps:)` and grid slicing; no Aseprite yet (Phase 21). |
| **audio** | ✅ | `Sound`/`Music`/`Voice` over SDL3_mixer; gain, stereo pan, dynamic pitch, fades, `crossfade(to:over:)`, master volume, ambient `Audio.current`. **Deferred:** voice pause/resume, category buses, 3D positional. |
| **input** | 🟡 | Keyboard (`down`/`pressed`/`released` + modifiers), mouse (position via camera, buttons, wheel), gamepad (buttons, analog sticks, triggers, hot-plug), via `app.input`. **Missing:** `binding` action map. |
| **binding** | ⏳ | Action map ("jump" → key OR button). Follow-up to Phase 16. |
| **collision** | ⏳ | **The next big gameplay enabler (Phase 18).** `Circle`/`AABB`/`Capsule`/`Poly`/`Ray`, overlap → manifold → raycast → GJK → swept TOI → hull builder. Pure math, zero GPU. |
| **math** | 🟡 | `Mat3x2`, `Rect`, SIMD2 via simd/kvSIMD. **Missing:** easing functions (Phase 20), geometry helpers that land with collision (Phase 18). |
| **time** | ✅ | `Clock` (perf-counter delta) + `FrameTimer` (windowed avg/fps/max). |
| **text** | 🟡 | `Font`, `TextEngine`, `Draw.text`, cached `Label` over SDL3_ttf + `TTF_GPUTextEngine`; HiDPI-crisp (native-density rasterization). **Missing:** color markup, outline, shadow (Phase 19). |
| **coroutine** | ⏳ | Frame-stepped coroutine/sequence runner + tweening (Phase 20). |
| **image** | 🟡 | `ImageBytes`, `subImage`, padding/gutter, PNG decode. No general pixel-manipulation API (not on critical path). |
| **haptic** | ⛔ | Rumble/force feedback. Follow-up to input. |
| **noise** | ⛔ | Perlin/fBm. Useful for procgen, off critical path. |
| **random** | ⛔ | Swift stdlib covers basics; CF-style seeded/noise variants deferred. |
| **net** | ⛔ | Client-server + encryption. Single-player, native-first for now. |
| **web** | 🟡 | `WebRenderer: RenderBackend` (WASI/WebGPU) port exists but is **unverified** — no wasm toolchain validated locally. |

## Utility modules — ➖ covered by Swift stdlib + Foundation

CF ships these because it's a C framework. In Swift they're not gaps and won't be reimplemented:

`allocator` · `array` · `atomic` · `base64` · `CPU` · `file` · `json` · `list` · `map` ·
`multithreading` · `path` · `string` · `utility`

---

## Summary

| Status | Count | Modules |
|---|---|---|
| ✅ shipped | 6 | app, graphics, sprite, custom_sprite, audio, time |
| 🟡 partial | 6 | draw, input, math, text, image, web |
| ⏳ planned | 3 | collision, binding, coroutine |
| ⛔ deferred | 4 | haptic, noise, random, net |
| ➖ stdlib | 13 | allocator, array, atomic, base64, CPU, file, json, list, map, multithreading, path, string, utility |

**Where we stand:** the rendering core is solid and the two biggest post-v0 enablers (input, audio)
have landed. The engine can already put an animated, batched, HiDPI-crisp sprite scene on screen
with sound and full input. What's missing for shipping an actual game is **gameplay**: collision,
richer draw primitives, and game-logic flow (tweens/coroutines).

## What to build next

Following TODO.md's sequencing (16 → 20, interleaving 19 into 18):

1. **Collision (Phase 18)** — the highest-impact gap and a signature CF feature. Pure math, zero
   GPU, ideal for TDD. Unblocks every gameplay interaction. Start with `Circle`/`AABB` overlaps,
   build up to manifolds and raycasts.
2. **Draw completeness (Phase 19)** — dovetails with collision: `capsule`/`poly`/`tri` primitives
   give collision debug-draw, and the state stacks (`pushScissor`/`pushBlendState`) plus text
   effects round out the HUD/UI surface.
3. **Coroutines & tweening (Phase 20)** — the game-feel multiplier for cutscenes, timed sequences,
   and UI animation.

**Recommendation: start Phase 18 (collision)** on a feature worktree, red-green TDD.
