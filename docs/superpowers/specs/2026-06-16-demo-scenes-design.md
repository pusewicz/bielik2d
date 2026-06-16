# Demo scenes — design

**Date:** 2026-06-16
**Branch/worktree:** `demo-scenes` (`../bielik2d-demo-scenes`)
**Target:** `Sources/Bielik2DDemo` (the demo executable only — no engine changes)

## Problem

`Sources/Bielik2DDemo/main.swift` is one ~260-line loop that draws every engine showcase at once
(sprites, pixel-art, input, audio, primitives, Phase-19 shapes, text, canvas, flow, collision,
swept-TOI). Everything is bunched onto a single 1280×720 screen, overlapping and unreadable, and a
single file mixing eleven unrelated demos is hard to maintain. There is no way to focus on one
capability at a time.

## Goal

Restructure the demo into discrete **scenes**, one per engine capability, navigable with the
keyboard (← / → or Q / E). Each scene owns the whole screen and shows its **name** and a one-line
**summary** of the functionality, plus its **controls**. Each scene lives in its own file behind a
small `Scene` protocol; a shell in `main.swift` owns the loop, navigation, shared resources, and a
uniform on-screen HUD.

## Non-goals

- No engine (`Sources/Bielik2D`) changes — this is demo-target-only.
- No new engine capabilities demoed beyond what already ships; this is a reorganization of existing
  showcases (each scene lifts its slice out of today's `main.swift`).
- No unit tests for the demo (it has none today); verification is build + manual flip-through.

## Architecture

### `Scene` protocol — `Sources/Bielik2DDemo/Scene.swift`

```swift
protocol Scene: AnyObject {
    var name: String { get }        // e.g. "Swept TOI & Move-and-Slide"
    var summary: String { get }     // one line describing the functionality shown
    var controls: String { get }    // per-scene input hints ("" if none)
    func onEnter(_ ctx: SceneContext)   // reset/start per-scene state
    func onExit()                        // cancel coroutines, etc.
    func update(_ ctx: SceneContext)     // advance state + queue this frame's draws
}

extension Scene {                        // both lifecycle hooks are optional
    func onEnter(_ ctx: SceneContext) {}
    func onExit() {}
}
```

Scenes are `final class` (reference types): they hold mutable per-frame state (ball/player
positions, settle timers) and serve as tween keypath targets, which require a class.

`onEnter`/`onExit` exist for the Flow scene (start its heartbeat coroutine on entry; cancel the
`RoutineHandle` on exit so revisiting doesn't stack tweens) and the swept-TOI scene (reset the ball
on entry). All other scenes use the defaults.

### `SceneContext` — `Sources/Bielik2DDemo/Scene.swift`

Passed into `onEnter`/`update` so scenes never reach for globals:

```swift
struct SceneContext {
    let app: App
    let draw: Draw
    let font: Font
    let camera: Camera
    let dt: Float
    let time: Float
    let stage: Rect                 // content area below the title band, above the footer
    let windowSize: SIMD2<Float>
}
```

Scenes lay out their content within `stage` (so every scene gets the full, uncluttered screen).
Live input is read each frame via `ctx.app.input`. Mouse→world goes through `ctx.camera`.

### The shell — `main.swift`

Owns the `App`, a shared `Draw` (with a text engine), `Font`, and main `Camera`; builds the `[Scene]`
array once at startup; tracks the current index; runs the loop.

Per frame:
1. `app.update()` (produces `dt`/`time`, steps `app.flow`).
2. Navigation: `keyboard.pressed(.left) || keyboard.pressed(.q)` → previous; `.right || .e` → next.
   Wrap around. Edge-triggered (`pressed`), so one keypress = one switch. On a switch, call the old
   scene's `onExit()` then the new scene's `onEnter(ctx)`.
3. Build `SceneContext`, call `current.update(ctx)`.
4. Draw the HUD on top.
5. `app.drawOntoScreen(draw, clear:, camera:)`.

### HUD (shell-owned, uniform for every scene)

Rendered by the shell after the scene's own draws, so it sits on top and looks identical across
scenes:

- **Top band:** `Scene i/N` (small) and the scene `name` (large) on the first line; the scene
  `summary` (smaller) on the line below.
- **Bottom footer:** the scene's `controls`, then the persistent hint
  `←  →   or   Q / E :  switch scene`.

`stage` is sized to leave room for both: roughly `Rect(x: 40, y: 120, width: windowSize.x - 80,
height: windowSize.y - 120 - 56)`.

## Scenes (one file each, under `Sources/Bielik2DDemo/Scenes/`)

Each `final class` takes `init(app: App)` (used for `makeCanvas`/`makeSound`/sprite loading; ignored
where unneeded) and lifts its slice out of today's `main.swift`, re-centered within `stage`:

1. **SpritesScene** — `Sprite(path:)` dedup + the looping generated color sheet (`blinker`).
   summary: ergonomic loading, dedup, and frame-stepped animation.
2. **PixelArtScene** — one sprite upscaled three ways (nearest / linear / pixelArt) with a sweeping
   non-integer scale. summary: `SDL_SCALEMODE_PIXELART` crisp-and-stable upscaling.
3. **InputScene** — a sprite driven by WASD / arrows / left-stick, a mouse-aim dot, and a live
   readout of held keys / mouse buttons / gamepad. controls: movement + aim.
4. **AudioScene** — space fires a pitched, mouse-panned blip (procedural WAV). controls: space; mouse
   x = pan, random pitch.
5. **PrimitivesScene** — `circleFill`, `line`, `box`. summary: the base SDF primitives.
6. **ShapesScene** — outline `circle`, `boxFill` (rounded), `tri` (filled + stroked), `polyline`,
   `poly` outline, and a `shapeAA` contrast. summary: Phase-19 shape primitives.
7. **TextCanvasScene** — text rendering + an offscreen `Canvas` (spinning quad) composited with
   pixel-art sampling. summary: TTF text + render-to-texture.
8. **FlowScene** — a heartbeat tween (`Repeat` swell/settle) plus an F-key dash coroutine
   (`Parallel`/`Wait`). Starts in `onEnter`, cancels in `onExit`. controls: F = dash.
9. **CollisionScene** — the mouse cursor as a circle probe vs an AABB (turns red on `overlaps`) and a
   capsule; a ghost ring shows the `manifold` push-out. controls: move mouse.
10. **SweptTOIScene** — the gravity ball sliding down a `Polygon` ramp, along an `AABB` floor, into a
    wall via `move(by:against:)`; resets on entry. summary: continuous collision + slide response.

## File structure

- **Modify** `Sources/Bielik2DDemo/main.swift` — reduce to the shell (app/draw/font/camera, scene
  array, loop, nav, HUD).
- **Create** `Sources/Bielik2DDemo/Scene.swift` — `Scene` protocol + `SceneContext` + default hooks.
- **Create** `Sources/Bielik2DDemo/Scenes/{Sprites,PixelArt,Input,Audio,Primitives,Shapes,TextCanvas,Flow,Collision,SweptTOI}Scene.swift`.

Shared helpers used across scenes (e.g. the `assetPath(_:_:)` Bundle lookup, the `blipWav()` and
`colorSheet()` generators) move to where they belong: asset path stays a small free function
(reachable target-wide); `blipWav` lives in `AudioScene`; `colorSheet` lives in `SpritesScene`.

## Edge cases / details

- **Navigation wrap:** previous from scene 0 → scene N-1; next from N-1 → 0.
- **Flow lifecycle:** the heartbeat is started in `onEnter` and its `RoutineHandle` cancelled in
  `onExit`; the F-dash routine is started on keypress and is naturally one-shot. Leaving the scene
  must cancel any live handles so `app.flow` is clean for other scenes.
- **First-frame:** call the first scene's `onEnter` once before the loop.
- **Mouse coordinates:** scenes that use the mouse resolve through `ctx.camera.screenToWorld`.
- **Resource creation may throw** (`Sprite(path:)`, `makeSound`, `makeCanvas`): scene initializers
  are `throws`; the shell builds the array with `try`.

## Verification

No automated tests (demo target). Done = `swift build` clean, then launch and:
- flip forward and backward through all 10 scenes with both ← / → and Q / E (wrap works),
- each scene renders its content centered in the stage with no overlap,
- each scene shows its name + summary (top) and controls + switch hint (bottom),
- the interactive scenes still respond (move the player, fire the blip, F-dash, mouse probe).

## Build sequence (incremental, each step builds)

1. `Scene.swift` (protocol + context + default hooks) and the shell skeleton in `main.swift` with a
   single placeholder scene + nav + HUD — builds and runs.
2. Port scenes one at a time out of the old `main.swift` into `Scenes/*`, adding each to the array;
   build after each.
3. Delete the leftover monolithic loop once all 10 are ported.
4. Build clean, launch, flip through all 10, confirm the verification checklist.
