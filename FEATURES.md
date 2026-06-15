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
| **draw** | 🟡 | `quad`/`sprite`/`canvas`; SDF `circleFill`, outline `circle`, `line`, `box`/`boxFill` (rounded + stroked), `capsule`, filled + outlined `tri`, `polyline`, polygon outline `poly`. Scoped state via `with{}` + `pushTransform`/`pushColor`/`pushLayer`/`pushScaleMode`/`pushShapeAA`. **Missing:** filled convex `poly`; `pushScissor`/`pushViewport`/`pushBlendState`. (Phase 19 remaining slices) |
| **sprite** | ✅ | `Sprite(path:)` with dedup via shared registry; animation model (loop/once/pingPong), `update`/`play`/`pause`/`resume`, runtime auto-atlaser packing into rolling 2048² pages (~one draw call per page). |
| **custom_sprite** | ✅ | In-memory sheets via `makeSprite(sheet:frameWidth:frameHeight:fps:)` and grid slicing; no Aseprite yet (Phase 21). |
| **audio** | ✅ | `Sound`/`Music`/`Voice` over SDL3_mixer; gain, stereo pan, dynamic pitch, fades, `crossfade(to:over:)`, master volume, ambient `Audio.current`. **Deferred:** voice pause/resume, category buses, 3D positional. |
| **input** | 🟡 | Keyboard (`down`/`pressed`/`released` + modifiers), mouse (position via camera, buttons, wheel), gamepad (buttons, analog sticks, triggers, hot-plug), via `app.input`. **Missing:** `binding` action map. |
| **binding** | ⏳ | Action map ("jump" → key OR button). Follow-up to Phase 16. |
| **collision** | 🟡 | `Circle`/`AABB`/`Capsule`/`Polygon`/`Halfspace`/`Ray` with protocol-oriented `overlaps`/`manifold(with:)`/`distance(to:)`/`cast(against:)` across all pairs; closed-form primitives + GJK/EPA for polygon pairs; convex-hull builder; continuous swept TOI (`sweep`) + `move`-and-slide resolve via GJK conservative advancement; `Draw.debug(_:)` shapes (Phase 18). |
| **math** | 🟡 | `Mat3x2`, `Rect`, SIMD2 via simd/kvSIMD; easing functions now ship in the `coroutine`/Flow module (Phase 20). **Missing:** geometry helpers that land with collision (Phase 18). |
| **time** | ✅ | `Clock` (perf-counter delta) + `FrameTimer` (windowed avg/fps/max). |
| **text** | 🟡 | `Font`, `TextEngine`, `Draw.text`, cached `Label` over SDL3_ttf + `TTF_GPUTextEngine`; HiDPI-crisp (native-density rasterization). **Missing:** color markup, outline, shadow (Phase 19). |
| **coroutine** | ✅ | `Flow` runner auto-driven by `App` (`app.deltaTime`/`time`); frame-stepped `Tween` (keypath target, lazy start capture, full Penner easing) and a `Routine`/`Parallel`/`Repeat`/`Wait`/`Run` result-builder DSL with same-frame overflow forwarding; cancellable `RoutineHandle`. (Phase 20) |
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
| ✅ shipped | 7 | app, graphics, sprite, custom_sprite, audio, time, coroutine |
| 🟡 partial | 7 | draw, input, math, text, image, web, collision |
| ⏳ planned | 1 | binding |
| ⛔ deferred | 4 | haptic, noise, random, net |
| ➖ stdlib | 13 | allocator, array, atomic, base64, CPU, file, json, list, map, multithreading, path, string, utility |

**Where we stand:** the rendering core is solid and the two biggest post-v0 enablers (input, audio)
have landed. The engine can already put an animated, batched, HiDPI-crisp sprite scene on screen
with sound and full input, and now drive game-logic flow with tweens and coroutines. What's still
missing for shipping an actual game is **gameplay**: collision and richer draw primitives.

## What to build next

Collision (Phase 18, now including continuous swept TOI + move-and-slide), coroutines/tweening
(Phase 20), and Phase 19's shape primitives have shipped; the remaining top gap:

1. **Draw completeness (Phase 19, remaining slices)** — the shape primitives landed (outline
   `circle`, `tri`, `polyline`, `poly` outline, `boxFill`, `pushShapeAA`); still to do are the
   draw-state stacks (`pushScissor`/`pushViewport`/`pushBlendState`) and text effects (color
   markup, outline, shadow), plus filled convex `poly`.
