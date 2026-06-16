# Scene-based Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `Sources/Bielik2DDemo` from one cluttered all-at-once screen into 10 navigable scenes (← / → or Q / E), each owning the screen and labeled with its name, summary, and controls.

**Architecture:** A small `Scene` protocol (`name`/`summary`/`controls` + `onEnter`/`onExit`/`update`) with one `final class` per scene under `Scenes/`. `main.swift` is the shell: it owns the `App`, shared `Draw`/`Font`/`Camera`, the `[Scene]` array, scene navigation, and a uniform HUD drawn on top of every scene. Scenes lift their slice out of today's `main.swift` and re-center it in a `stage` rect.

**Tech Stack:** Swift 6.3, Bielik2D engine, SDL3 (Metal). Demo executable only — no engine changes.

**Worktree:** `../bielik2d-demo-scenes` (branch `demo-scenes`, `vendor/.install` symlinked). Run all commands from there.

**Spec:** `docs/superpowers/specs/2026-06-16-demo-scenes-design.md`

**No automated tests** (demo target). The per-task gate is `swift build --target Bielik2DDemo` exiting 0; functional verification is launching and flipping through the scenes (milestones at Task 1 and Task 11).

**Commit note:** this repo signs commits via a 1Password agent that fails in headless shells while the whole history is unsigned. Commit with signing off to match: `git -c commit.gpgsign=false commit -m "<message>"`. Messages: lowercase imperative, no Conventional-Commits prefix, no AI signoff.

---

## File structure

- **Rewrite** `Sources/Bielik2DDemo/main.swift` — the shell (app/draw/fonts/camera, scene array, loop, nav, HUD).
- **Create** `Sources/Bielik2DDemo/Scene.swift` — `Scene` protocol, `SceneContext`, default hooks, and the `assetPath` helper.
- **Create** `Sources/Bielik2DDemo/Scenes/SpritesScene.swift`, `PixelArtScene.swift`, `InputScene.swift`, `AudioScene.swift`, `PrimitivesScene.swift`, `ShapesScene.swift`, `TextCanvasScene.swift`, `FlowScene.swift`, `CollisionScene.swift`, `SweptTOIScene.swift`.

Scenes are added to the `scenes` array in display order, one per task, so the array is always buildable and already ordered.

---

### Task 1: Scene foundation + shell + first scene (Sprites)

Establishes the protocol, the shell loop with navigation and HUD, and the first scene so the whole thing builds and runs with one scene.

**Files:**
- Create: `Sources/Bielik2DDemo/Scene.swift`
- Create: `Sources/Bielik2DDemo/Scenes/SpritesScene.swift`
- Rewrite: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scene.swift`**

```swift
import Bielik2D
import Foundation

/// Per-frame context handed to every scene so scenes never reach for globals.
struct SceneContext {
    let app: App
    let draw: Draw
    let font: Font
    let camera: Camera
    let dt: Float
    let time: Float
    let stage: Rect          // content area below the title band, above the footer
    let windowSize: SIMD2<Float>
}

/// One self-contained showcase. The shell draws the name/summary/controls HUD; the scene draws
/// only its content within `ctx.stage`.
protocol Scene: AnyObject {
    var name: String { get }
    var summary: String { get }
    var controls: String { get }
    func onEnter(_ ctx: SceneContext)
    func onExit()
    func update(_ ctx: SceneContext)
}

extension Scene {
    func onEnter(_ ctx: SceneContext) {}
    func onExit() {}
}

/// Resolve a bundled demo asset (the demo target ships `assets/` as a resource).
func assetPath(_ name: String, _ ext: String) -> String {
    Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "assets")!.path
}
```

- [ ] **Step 2: Create `Sources/Bielik2DDemo/Scenes/SpritesScene.swift`**

```swift
import Bielik2D
import Foundation

/// Sprite loading + dedup + a frame-stepped generated animation.
final class SpritesScene: Scene {
    let name = "Sprites & Animation"
    let summary = "Sprite(path:) ergonomic loading with dedup, plus a frame-stepped animated sheet"
    let controls = ""

    private let player: Sprite
    private var blinker: Sprite

    init(app: App) throws {
        player = try Sprite(path: assetPath("p1_stand", "png"))
        let again = try Sprite(path: assetPath("p1_stand", "png"))
        print("sprite dedup: same asset on second load = \(player == again)")
        blinker = app.renderer.makeSprite(
            sheet: SpritesScene.colorSheet(cell: 32,
                colors: [[230, 70, 70], [70, 200, 90], [80, 120, 240], [240, 200, 60]]),
            frameWidth: 32, frameHeight: 32, fps: 6)
        blinker.scale = SIMD2(4, 4)
        blinker.scaleMode = .nearest
    }

    func update(_ ctx: SceneContext) {
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2

        var p = player
        p.scale = SIMD2(4, 4)
        p.scaleMode = .nearest
        p.draw(at: SIMD2(cx - 240, cy - Float(player.height) * 2))
        ctx.draw.text("Sprite(path:)", font: ctx.font, at: SIMD2(cx - 260, cy + 90), color: .white)

        blinker.update(Double(ctx.dt))   // Sprite.update takes Double; ctx.dt is Float
        blinker.draw(at: SIMD2(cx + 120, cy - 64))
        ctx.draw.text("animated sheet", font: ctx.font, at: SIMD2(cx + 90, cy + 90), color: .white)
    }

    /// A `cell × (cell·colors.count)` strip, one solid colour per frame.
    static func colorSheet(cell: Int, colors: [[UInt8]]) -> ImageBytes {
        let w = cell * colors.count
        var px = [UInt8](repeating: 0, count: w * cell * 4)
        for (c, color) in colors.enumerated() {
            for y in 0..<cell {
                for x in 0..<cell {
                    let o = (y * w + c * cell + x) * 4
                    px[o] = color[0]; px[o + 1] = color[1]; px[o + 2] = color[2]; px[o + 3] = 255
                }
            }
        }
        return ImageBytes(width: w, height: cell, pixels: Data(px))
    }
}
```

- [ ] **Step 3: Rewrite `Sources/Bielik2DDemo/main.swift`**

```swift
import Bielik2D

let windowSize = SIMD2<Float>(1280, 720)
let app = try App(title: "Bielik2D Demo", width: Int(windowSize.x), height: Int(windowSize.y))
print("GPU driver: \(app.driverName)")

let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 28)
let smallFont = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 18)
let draw = Draw(textEngine: try app.renderer.makeTextEngine())
let camera = Camera(viewportSize: windowSize)

let titleBandHeight: Float = 116
let footerHeight: Float = 52
let stage = Rect(x: 40, y: titleBandHeight,
                 width: windowSize.x - 80,
                 height: windowSize.y - titleBandHeight - footerHeight)

// Scenes are appended in display order; the array stays buildable as each is added.
let scenes: [Scene] = [
    try SpritesScene(app: app),
]
var current = 0

// `@MainActor`: top-level globals in main.swift are main-actor-isolated under Swift 6, and these
// free functions touch them, so they must be isolated too.
@MainActor
func makeContext(dt: Float, time: Float) -> SceneContext {
    SceneContext(app: app, draw: draw, font: font, camera: camera,
                 dt: dt, time: time, stage: stage, windowSize: windowSize)
}

@MainActor
func drawHUD(_ scene: Scene, index: Int, count: Int) {
    draw.text("Scene \(index + 1)/\(count)", font: smallFont, at: SIMD2(40, 18),
              color: Color(r: 0.55, g: 0.7, b: 0.85))
    draw.text(scene.name, font: font, at: SIMD2(40, 42), color: .white)
    draw.text(scene.summary, font: smallFont, at: SIMD2(40, 84),
              color: Color(r: 0.75, g: 0.82, b: 0.9))
    let y = windowSize.y - 32
    if !scene.controls.isEmpty {
        draw.text(scene.controls, font: smallFont, at: SIMD2(40, y),
                  color: Color(r: 0.7, g: 1.0, b: 0.8))
    }
    draw.text("<-  ->   or   Q / E :  switch scene", font: smallFont,
              at: SIMD2(windowSize.x - 470, y), color: Color(r: 0.55, g: 0.7, b: 0.85))
}

scenes[current].onEnter(makeContext(dt: 0, time: 0))

while app.isRunning {
    app.update()
    let dt = Float(app.deltaTime)
    let time = Float(app.time)
    let ctx = makeContext(dt: dt, time: time)

    let kb = app.input.keyboard
    var next = current
    if kb.pressed(.left) || kb.pressed(.q) { next = (current - 1 + scenes.count) % scenes.count }
    if kb.pressed(.right) || kb.pressed(.e) { next = (current + 1) % scenes.count }
    if next != current {
        scenes[current].onExit()
        current = next
        scenes[current].onEnter(ctx)
    }

    scenes[current].update(ctx)
    drawHUD(scenes[current], index: current, count: scenes.count)

    app.drawOntoScreen(draw, clear: Color(r: 0.10, g: 0.12, b: 0.18), camera: camera)
}
app.destroy()
```

- [ ] **Step 4: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0). Ignore the `linking with dylib ... newer version` / `duplicate -rpath` linker warnings — they are pre-existing.

- [ ] **Step 5: Launch and verify (milestone)**

Run: `swift run Bielik2DDemo` (close the window to exit).
Expected: one scene ("Scene 1/1 · Sprites & Animation") with the player sprite + animated colour-cycling sheet, the name + summary at top-left, and the switch hint bottom-right. Q/E and ←/→ wrap to the same scene (only one exists).

- [ ] **Step 6: Commit**

```bash
git add Sources/Bielik2DDemo/Scene.swift Sources/Bielik2DDemo/Scenes/SpritesScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "restructure demo into navigable scenes with a shell + sprites scene"
```

---

### Task 2: PixelArtScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/PixelArtScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift` (append to `scenes`)

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/PixelArtScene.swift`**

```swift
import Bielik2D
import Foundation

/// One sprite upscaled three ways with a sweeping non-integer factor: nearest shimmers, linear
/// softens, pixelArt stays crisp and stable.
final class PixelArtScene: Scene {
    let name = "Pixel-art Scaling"
    let summary = "nearest / linear / pixelArt — SDL_SCALEMODE_PIXELART stays crisp and stable"
    let controls = ""

    private let player: Sprite

    init(app: App) throws { player = try Sprite(path: assetPath("p1_stand", "png")) }

    func update(_ ctx: SceneContext) {
        let upscale: Float = 3.0 + sin(ctx.time) * 0.9
        var s = player
        s.scale = SIMD2(upscale, upscale)
        let spriteW = Float(player.width) * upscale
        let spriteH = Float(player.height) * upscale
        let gap: Float = 80
        let cy = ctx.stage.y + ctx.stage.height / 2
        let baseline = cy + spriteH / 2
        let startX = ctx.stage.x + ctx.stage.width / 2 - (spriteW * 3 + gap * 2) / 2
        let modes: [(ScaleMode, String)] = [(.nearest, "nearest"), (.linear, "linear"), (.pixelArt, "pixelArt")]
        for (i, m) in modes.enumerated() {
            let x = startX + Float(i) * (spriteW + gap)
            s.draw(at: SIMD2(x, baseline - spriteH), scaleMode: m.0)
            ctx.draw.text(m.1, font: ctx.font, at: SIMD2(x, baseline + 6), color: .white)
        }
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — change the array to:

```swift
let scenes: [Scene] = [
    try SpritesScene(app: app),
    try PixelArtScene(app: app),
]
```

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/PixelArtScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add pixel-art scaling scene"
```

---

### Task 3: InputScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/InputScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/InputScene.swift`**

```swift
import Bielik2D
import Foundation

/// Keyboard / mouse / gamepad: a sprite you drive, a mouse-aim dot, and a live stick readout.
final class InputScene: Scene {
    let name = "Input"
    let summary = "Keyboard, mouse, and gamepad — drive a sprite and read live device state"
    let controls = "WASD / arrows / left-stick: move   ·   left mouse: grow aim dot"

    private let player: Sprite
    private var pos: SIMD2<Float> = .zero
    private let speed: Float = 320

    init(app: App) throws { player = try Sprite(path: assetPath("p1_stand", "png")) }

    func onEnter(_ ctx: SceneContext) {
        pos = SIMD2(ctx.stage.x + ctx.stage.width / 2, ctx.stage.y + ctx.stage.height / 2)
    }

    func update(_ ctx: SceneContext) {
        let kb = ctx.app.input.keyboard
        let gp = ctx.app.input.gamepad(0)
        var move = SIMD2<Float>(0, 0)
        if kb.down(.a) || kb.down(.left) { move.x -= 1 }
        if kb.down(.d) || kb.down(.right) { move.x += 1 }
        if kb.down(.w) || kb.down(.up) { move.y -= 1 }
        if kb.down(.s) || kb.down(.down) { move.y += 1 }
        move += gp.leftStick
        pos += move * speed * ctx.dt
        pos.x = min(max(pos.x, ctx.stage.minX), ctx.stage.maxX)
        pos.y = min(max(pos.y, ctx.stage.minY), ctx.stage.maxY)

        var p = player
        p.scale = SIMD2(2.5, 2.5)
        p.scaleMode = .nearest
        p.draw(at: pos)

        let aim = ctx.camera.screenToWorld(ctx.app.input.mouse.position)
        let aiming = ctx.app.input.mouse.down(.left)
        ctx.draw.circleFill(center: aim, radius: aiming ? 18 : 10, color: Color(r: 1.0, g: 0.5, b: 0.2))

        let stick = gp.leftStick
        ctx.draw.text(String(format: "left-stick: %.2f, %.2f", stick.x, stick.y),
                      font: ctx.font, at: SIMD2(ctx.stage.x, ctx.stage.y), color: Color(r: 0.7, g: 0.9, b: 1.0))
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `try InputScene(app: app),` after `PixelArtScene`.

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/InputScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add input scene"
```

---

### Task 4: AudioScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/AudioScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/AudioScene.swift`**

```swift
import Bielik2D
import Foundation

/// A procedurally-generated decaying blip with dynamic pitch and stereo pan — no asset file.
final class AudioScene: Scene {
    let name = "Audio"
    let summary = "A procedural blip with dynamic pitch and stereo pan over SDL3_mixer"
    let controls = "space: fire blip   ·   mouse x: pan   ·   pitch: random"

    private let blip: Sound?

    init(app: App) throws { blip = try app.audio?.makeSound(bytes: AudioScene.blipWav()) }

    func update(_ ctx: SceneContext) {
        if ctx.app.input.keyboard.pressed(.space), let blip {
            let pan = ctx.app.input.mouse.position.x / ctx.windowSize.x * 2 - 1
            blip.play(pan: pan, pitch: Float.random(in: 0.8...1.4))
        }
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2
        ctx.draw.circle(center: SIMD2(cx, cy), radius: 64, thickness: 6, color: Color(r: 0.6, g: 0.9, b: 1.0))
        ctx.draw.text("press space to fire", font: ctx.font, at: SIMD2(cx - 110, cy + 96), color: .white)
    }

    /// A 0.12s 660Hz sine that decays exponentially, as a mono 16-bit WAV in memory.
    static func blipWav() -> Data {
        let sampleRate = 48_000
        let frames = sampleRate * 12 / 100
        var bytes = [UInt8]()
        func u32(_ v: Int) { let x = UInt32(v); bytes += [UInt8(x & 0xff), UInt8((x >> 8) & 0xff), UInt8((x >> 16) & 0xff), UInt8((x >> 24) & 0xff)] }
        func u16(_ v: Int) { let x = UInt16(v); bytes += [UInt8(x & 0xff), UInt8((x >> 8) & 0xff)] }
        func ascii(_ s: String) { bytes += Array(s.utf8) }
        let dataSize = frames * 2
        ascii("RIFF"); u32(36 + dataSize); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        ascii("data"); u32(dataSize)
        for i in 0..<frames {
            let tt = Double(i) / Double(sampleRate)
            let s = sin(2 * .pi * 660 * tt) * exp(-tt * 18) * 0.6
            let v = UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32767))
            bytes.append(UInt8(v & 0xff)); bytes.append(UInt8((v >> 8) & 0xff))
        }
        return Data(bytes)
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `try AudioScene(app: app),` after `InputScene`.

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/AudioScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add audio scene"
```

---

### Task 5: PrimitivesScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/PrimitivesScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/PrimitivesScene.swift`**

```swift
import Bielik2D

/// The base SDF primitives: filled circle, thick line, filled box.
final class PrimitivesScene: Scene {
    let name = "Primitives"
    let summary = "The base SDF primitives — filled circle, thick line, and box"
    let controls = ""

    init(app: App) {}

    func update(_ ctx: SceneContext) {
        let d = ctx.draw
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2
        d.circleFill(center: SIMD2(cx - 220, cy), radius: 60, color: Color(r: 0.4, g: 0.8, b: 1.0))
        d.line(from: SIMD2(cx - 60, cy + 60), to: SIMD2(cx + 110, cy - 60),
               thickness: 10, color: Color(r: 1.0, g: 0.9, b: 0.3))
        d.box(Rect(x: cx + 160, y: cy - 60, width: 120, height: 120), color: Color(r: 1.0, g: 0.5, b: 0.6))
        d.text("circleFill", font: ctx.font, at: SIMD2(cx - 280, cy + 90), color: .white)
        d.text("line", font: ctx.font, at: SIMD2(cx - 30, cy + 90), color: .white)
        d.text("box", font: ctx.font, at: SIMD2(cx + 190, cy + 90), color: .white)
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `PrimitivesScene(app: app),` after `AudioScene` (no `try` — its init does not throw).

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/PrimitivesScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add primitives scene"
```

---

### Task 6: ShapesScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/ShapesScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/ShapesScene.swift`**

```swift
import Bielik2D

/// Phase-19 shape primitives: outline circle, rounded boxFill, filled + stroked tri, polyline,
/// poly outline, and a shapeAA-smoothed polygon.
final class ShapesScene: Scene {
    let name = "Shapes (Phase 19)"
    let summary = "Outline circle, rounded boxFill, filled + stroked tri, polyline, poly, shapeAA"
    let controls = ""

    init(app: App) {}

    func update(_ ctx: SceneContext) {
        let d = ctx.draw
        let cx = ctx.stage.x + ctx.stage.width / 2
        let y = ctx.stage.y + ctx.stage.height / 2
        d.circle(center: SIMD2(cx - 360, y), radius: 40, thickness: 5, color: Color(r: 0.5, g: 0.9, b: 1.0))
        d.boxFill(Rect(x: cx - 290, y: y - 40, width: 80, height: 80), cornerRadius: 16,
                  color: Color(r: 1.0, g: 0.7, b: 0.3))
        d.tri(SIMD2(cx - 160, y + 40), SIMD2(cx - 80, y + 40), SIMD2(cx - 120, y - 40),
              color: Color(r: 0.7, g: 1.0, b: 0.6))
        d.tri(SIMD2(cx - 30, y + 40), SIMD2(cx + 50, y + 40), SIMD2(cx + 10, y - 40),
              stroke: 4, color: Color(r: 1.0, g: 0.5, b: 0.8))
        d.polyline([SIMD2(cx + 90, y + 36), SIMD2(cx + 120, y - 36),
                    SIMD2(cx + 150, y + 36), SIMD2(cx + 180, y - 36)],
                   thickness: 5, color: Color(r: 0.9, g: 0.9, b: 0.4))
        d.with(shapeAA: 4.0) {
            d.poly([SIMD2(cx + 240, y - 36), SIMD2(cx + 290, y - 12),
                    SIMD2(cx + 270, y + 36), SIMD2(cx + 220, y + 24)],
                   stroke: 3, color: Color(r: 0.8, g: 0.7, b: 1.0))
        }
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `ShapesScene(app: app),` after `PrimitivesScene`.

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/ShapesScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add shapes scene"
```

---

### Task 7: TextCanvasScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/TextCanvasScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/TextCanvasScene.swift`**

The offscreen canvas pass must run FIRST, while only the spinning quad is queued, because
`renderer.render(_:to:)` flushes the entire pending draw queue into the canvas. Queue the quad,
flush to the canvas, then draw the main-pass text and composite.

```swift
import Bielik2D

/// TTF text plus an offscreen Canvas (render-to-texture): a spinning quad rendered to a 256² canvas
/// and composited back with pixel-art sampling.
final class TextCanvasScene: Scene {
    let name = "Text & Canvas"
    let summary = "TTF text rendering plus an offscreen canvas (render-to-texture) composite"
    let controls = ""

    private let canvas: Canvas
    private let canvasSize = SIMD2<Float>(256, 256)
    private let cameraCanvas: Camera

    init(app: App) throws {
        canvas = try app.renderer.makeCanvas(width: 256, height: 256, format: .bgra8Unorm)
        cameraCanvas = Camera(viewportSize: canvasSize)
    }

    func update(_ ctx: SceneContext) {
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2

        // Offscreen pass first: only the spinning quad is queued when we flush to the canvas.
        ctx.draw.with(transform: .translation(x: canvasSize.x / 2, y: canvasSize.y / 2)
                        * .rotation(angleRadians: ctx.time),
                      color: Color(r: 1.0, g: 0.4, b: 0.6)) {
            ctx.draw.box(Rect(x: -90, y: -90, width: 180, height: 180))
        }
        ctx.app.renderer.render(ctx.draw, to: canvas,
                                clear: Color(r: 0.05, g: 0.10, b: 0.30), camera: cameraCanvas)

        // Main pass: text + composite the canvas.
        ctx.draw.text("Hello, Bielik!", font: ctx.font, at: SIMD2(cx - 380, cy - 16), color: .white)
        ctx.draw.with(scaleMode: .pixelArt) {
            ctx.draw.canvas(canvas, at: SIMD2(cx + 60, cy - canvasSize.y / 2))
        }
        ctx.draw.text("offscreen canvas", font: ctx.font,
                      at: SIMD2(cx + 60, cy + canvasSize.y / 2 + 8), color: .white)
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `try TextCanvasScene(app: app),` after `ShapesScene`.

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/TextCanvasScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add text and canvas scene"
```

---

### Task 8: FlowScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/FlowScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/FlowScene.swift`**

The heartbeat coroutine is started in `onEnter` and its handle cancelled in `onExit` so re-entering
the scene doesn't stack tweens. Tweens write through a reference target, so the animated state lives
on a small class.

```swift
import Bielik2D

/// Tween keypath target for the flow scene.
final class Pulser {
    var scale: Float = 1
    var tint = Color(r: 1.0, g: 0.85, b: 0.2)
    var pos: SIMD2<Float> = .zero
}

/// Tweens + a coroutine DSL: a forever heartbeat plus a one-shot dash, driven by `app.flow`.
final class FlowScene: Scene {
    let name = "Flow: Tweens & Coroutines"
    let summary = "Frame-stepped tweens and a Routine/Parallel/Repeat DSL driving game feel"
    let controls = "F: launch a one-shot dash coroutine"

    private let pulser = Pulser()
    private var home: SIMD2<Float> = .zero
    private var heartbeat: RoutineHandle?

    init(app: App) {}

    func onEnter(_ ctx: SceneContext) {
        home = SIMD2(ctx.stage.x + ctx.stage.width / 2, ctx.stage.y + ctx.stage.height / 2)
        pulser.pos = home
        pulser.scale = 1
        pulser.tint = Color(r: 1.0, g: 0.85, b: 0.2)
        heartbeat = ctx.app.flow.run {
            Repeat {
                Tween(pulser, \.scale, to: 1.6, over: 0.5, ease: .outBack)
                Tween(pulser, \.scale, to: 1.0, over: 0.5, ease: .inOutQuad)
            }
        }
    }

    func onExit() { heartbeat?.cancel(); heartbeat = nil }

    func update(_ ctx: SceneContext) {
        if ctx.app.input.keyboard.pressed(.f) {
            _ = ctx.app.flow.run {
                Parallel {
                    Tween(pulser, \.pos, to: home + SIMD2(220, 0), over: 0.4, ease: .outCubic)
                    Tween(pulser, \.tint, to: Color(r: 0.3, g: 0.9, b: 1.0), over: 0.3)
                }
                Wait(0.2)
                Tween(pulser, \.pos, to: home, over: 0.6, ease: .inOutBack)
                Tween(pulser, \.tint, to: Color(r: 1.0, g: 0.85, b: 0.2), over: 0.4)
            }
        }
        ctx.draw.with(transform: .translation(x: pulser.pos.x, y: pulser.pos.y)
                        * .scale(pulser.scale, pulser.scale),
                      color: pulser.tint) {
            ctx.draw.box(Rect(x: -28, y: -28, width: 56, height: 56))
        }
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `FlowScene(app: app),` after `TextCanvasScene`.

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/FlowScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add flow scene with enter/exit coroutine lifecycle"
```

---

### Task 9: CollisionScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/CollisionScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/CollisionScene.swift`**

```swift
import Bielik2D

/// overlaps + manifold: the mouse cursor is a circle probe against an AABB (turns red on overlap)
/// and a capsule; a ghost ring shows the manifold push-out (minimum-translation vector).
final class CollisionScene: Scene {
    let name = "Collision Queries"
    let summary = "overlaps + manifold — a cursor probe vs an AABB and capsule, with push-out"
    let controls = "move the mouse over the green box"

    init(app: App) {}

    func update(_ ctx: SceneContext) {
        let d = ctx.draw
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2

        let obstacle = AABB(min: SIMD2(cx - 170, cy - 40), max: SIMD2(cx - 50, cy + 40))
        let cursor = Circle(center: ctx.camera.screenToWorld(ctx.app.input.mouse.position), radius: 18)
        let touching = obstacle.overlaps(cursor)
        d.debug(obstacle, color: touching ? Color(r: 1.0, g: 0.3, b: 0.3) : Color(r: 0.4, g: 1.0, b: 0.5),
                stroke: 2)
        d.capsule(from: SIMD2(cx + 60, cy - 40), to: SIMD2(cx + 170, cy + 40), radius: 18,
                  color: Color(r: 0.7, g: 0.5, b: 1.0))
        if let m = obstacle.manifold(with: cursor) {
            let resolved = cursor.center + m.normal * m.depth
            d.debug(Circle(center: resolved, radius: cursor.radius),
                    color: Color(r: 1.0, g: 0.85, b: 0.2), stroke: 2)
        }
        d.debug(cursor, color: Color(r: 0.9, g: 0.9, b: 0.9), stroke: 2)
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `CollisionScene(app: app),` after `FlowScene`.

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/CollisionScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add collision queries scene"
```

---

### Task 10: SweptTOIScene

**Files:**
- Create: `Sources/Bielik2DDemo/Scenes/SweptTOIScene.swift`
- Modify: `Sources/Bielik2DDemo/main.swift`

- [ ] **Step 1: Create `Sources/Bielik2DDemo/Scenes/SweptTOIScene.swift`**

```swift
import Bielik2D

/// Continuous (tunnel-proof) collision + sliding: a gravity ball slides down a Polygon ramp, along
/// an AABB floor, into a wall via `move(by:against:)`, then respawns once it comes to rest. The
/// static world is rebuilt relative to the stage on entry.
final class SweptTOIScene: Scene {
    let name = "Swept TOI & Move-and-Slide"
    let summary = "Continuous collision + slide response via move(by:against:) over a static world"
    let controls = "watch the ball slide down the ramp and along the floor"

    private var ramp = Polygon(vertices: [])
    private var floor = AABB(min: .zero, max: .zero)
    private var wall = AABB(min: .zero, max: .zero)
    private var world: [CollisionShape] = []
    private var spawn: SIMD2<Float> = .zero
    private var pos: SIMD2<Float> = .zero
    private var vel: SIMD2<Float> = .zero
    private var settle: Float = 0
    private let gravity: Float = 1100

    init(app: App) {}

    func onEnter(_ ctx: SceneContext) {
        let x0 = ctx.stage.x + 160
        let baseY = ctx.stage.y + ctx.stage.height - 120
        ramp = Polygon(vertices: [SIMD2(x0, baseY - 90), SIMD2(x0 + 150, baseY), SIMD2(x0, baseY)])
        floor = AABB(min: SIMD2(x0, baseY), max: SIMD2(x0 + 380, baseY + 20))
        wall = AABB(min: SIMD2(x0 + 380, baseY - 90), max: SIMD2(x0 + 400, baseY + 20))
        world = [ramp, floor, wall]
        spawn = SIMD2(x0 + 28, baseY - 150)
        pos = spawn; vel = .zero; settle = 0
    }

    func update(_ ctx: SceneContext) {
        vel.y += gravity * ctx.dt
        let ball = Circle(center: pos, radius: 11)
        let slid = ball.move(by: vel * ctx.dt, against: world)
        pos += slid.motion
        for n in slid.normals {
            let into = vel.x * n.x + vel.y * n.y
            if into < 0 { vel -= n * into }
        }
        let speed = (vel.x * vel.x + vel.y * vel.y).squareRoot()
        if !slid.normals.isEmpty && speed < 25 { settle += ctx.dt } else { settle = 0 }
        if settle > 0.6 || pos.y > ctx.stage.maxY + 60 { pos = spawn; vel = .zero; settle = 0 }

        let tint = Color(r: 0.4, g: 0.95, b: 0.85)
        ctx.draw.debug(ramp, color: tint, stroke: 2)
        ctx.draw.debug(floor, color: tint, stroke: 2)
        ctx.draw.debug(wall, color: tint, stroke: 2)
        ctx.draw.circleFill(center: pos, radius: 11, color: Color(r: 1.0, g: 0.55, b: 0.2))
    }
}
```

- [ ] **Step 2: Append to `scenes` in `main.swift`** — add `SweptTOIScene(app: app),` after `CollisionScene`. The final array is:

```swift
let scenes: [Scene] = [
    try SpritesScene(app: app),
    try PixelArtScene(app: app),
    try InputScene(app: app),
    try AudioScene(app: app),
    PrimitivesScene(app: app),
    ShapesScene(app: app),
    try TextCanvasScene(app: app),
    FlowScene(app: app),
    CollisionScene(app: app),
    SweptTOIScene(app: app),
]
```

- [ ] **Step 3: Build**

Run: `swift build --target Bielik2DDemo`
Expected: `Build complete!` (exit 0).

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/Scenes/SweptTOIScene.swift Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "add swept toi scene"
```

---

### Task 11: Full flip-through verification

**Files:** none (verification only; commit a nudge only if something needs it).

- [ ] **Step 1: Build the whole package** (catches anything beyond the demo target)

Run: `swift build`
Expected: `Build complete!` (exit 0).

- [ ] **Step 2: Launch and flip through all 10 scenes**

Run: `swift run Bielik2DDemo` (close the window to exit).

Verify:
- "Scene 1/10" … "Scene 10/10" — `→`/`E` advances, `←`/`Q` goes back, both wrap (scene 10 → 1 and 1 → 10).
- Every scene shows its **name** + **summary** top-left and the **switch hint** bottom-right; scenes with controls show them bottom-left.
- Each scene's content sits in the stage area without overlapping the HUD bands.
- Interactive scenes respond: Input (move sprite / aim dot), Audio (space fires the blip), Flow (F triggers the dash; leaving and returning does not speed up or stack the heartbeat), Collision (box reddens under the cursor; ghost ring shows push-out), SweptTOI (ball slides ramp→floor→wall and respawns).

- [ ] **Step 3: Adjust only if needed**

If any HUD text overlaps a band edge or scene content, nudge the constants in `drawHUD` / `stage`
(`titleBandHeight`, `footerHeight`, the `at:` y-coordinates) and rebuild. If nothing needs changing,
skip to done — no commit required.

- [ ] **Step 4: Commit (only if Step 3 changed anything)**

```bash
git add Sources/Bielik2DDemo/main.swift
git -c commit.gpgsign=false commit -m "tune demo HUD layout"
```

---

## Notes for the implementer

- **Run from the worktree** `../bielik2d-demo-scenes` (branch `demo-scenes`). The `vendor/.install` symlink is in place; if a build fails on `SDL_shadercross.h`, recreate it: `ln -s /Users/piotr/Work/GitHub/pusewicz/bielik2d/vendor/.install vendor/.install`.
- **Engine is frozen** — touch only `Sources/Bielik2DDemo`. No `Sources/Bielik2D` edits, no `FEATURES.md`/`TODO.md` changes (this is demo polish, not a module capability change).
- **`Sprite` is a value type** — copy it (`var p = player`) before setting `scale`/`scaleMode` per draw, as the scenes above do.
- **`Foundation`** is imported only in the scenes that need it (`Data`/`Bundle`/`sin`/`String(format:)`): Scene.swift, SpritesScene, PixelArtScene, InputScene, AudioScene.
- The original monolithic `main.swift` (pre-refactor) is preserved in git history at the branch point if you need to cross-check a value.

## Self-review notes (author)

- **Spec coverage:** Scene protocol + SceneContext + default hooks (T1); shell loop, nav (←/→/Q/E, wrapping, edge-triggered), shell-owned HUD (T1); all 10 scenes mapped to T1–T10 in the spec's display order; Flow enter/exit lifecycle (T8); SweptTOI reset-on-enter (T10); verification flip-through (T11). No spec item unmapped.
- **Type consistency:** `Scene`/`SceneContext`/`assetPath`/`drawHUD`/`makeContext` signatures are identical across tasks; every scene uses `init(app: App)`, throwing for the five that load resources (Sprites, PixelArt, Input, Audio, TextCanvas — all marked `try` in the array) and non-throwing for the other five; the `scenes` array grows in display order so its final form (T10) matches the spec ordering.
- **Canvas ordering** (T7) explicitly flushes the offscreen pass before main-pass draws, matching the original's behavior (the queue is empty at scene-update start since the previous frame's `drawOntoScreen` cleared it).
- **No placeholders:** every step has concrete code or an exact command + expected output.
