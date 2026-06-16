import Bielik2D

#if os(WASI)
import Bielik2DWeb
import JavaScriptKit
import JavaScriptEventLoop
#endif

// MARK: - Shared demo state
//
// The scene list, per-frame body, HUD, and scene-switch keys are identical on
// every platform. Only app construction and the loop driver differ (native is a
// synchronous `App(...)` + `while` loop; web is an async `await App.create(...)`
// + requestAnimationFrame), so those two seams live in the `#if os(WASI)` /
// `#else` branches below; everything in between is built once.

let windowSize = SIMD2<Float>(1280, 720)

let titleBandHeight: Float = 116
let footerHeight: Float = 52
let stage = Rect(x: 40, y: titleBandHeight,
                 width: windowSize.x - 80,
                 height: windowSize.y - titleBandHeight - footerHeight)

// These are populated exactly once by whichever platform branch runs, then read
// by the shared `runFrame`. They're implicitly-unwrapped so the file type-checks
// before the branch assigns them; the branch always sets them before the loop.
var app: App!
var draw: Draw!
var font: Font!
var smallFont: Font!
var camera: Camera!
var scenes: [Scene] = []
var current = 0

/// Every sprite asset the scenes load. On web these are prefetched (fetched +
/// decoded) before any scene is built, because the web `Sprite(path:)` reads from
/// the prefetched cache synchronously. The strings here MUST match the keys the
/// scenes pass to `Sprite(path:)` (via `assetPath`) and the files `build-web.sh`
/// copies into `web/dist/assets/`.
let spriteAssetPaths = [assetPath("p1_stand", "png")]

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

/// One frame, shared across platforms. Advances the app first (the web `App`
/// steps input here, matching native), handles scene-switch keys, updates the
/// active scene, draws the HUD, and presents.
@MainActor
func runFrame() {
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

/// Builds the scene list. Runs after `app`, `draw`, `font`, and `camera` are set
/// (and, on web, after assets are prefetched), so `Sprite(path:)` resolves.
@MainActor
func buildScenes() throws {
    scenes = [
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
        DrawStateScene(app: app),
    ]
    current = 0
    scenes[current].onEnter(makeContext(dt: 0, time: 0))
}

#if os(WASI)
// MARK: - Web entry point
//
// WebGPU device acquisition and asset fetches are async, so the whole bootstrap
// runs inside a `Task` after installing the JS event-loop executor. Errors are
// printed (the host `index.html` surfaces console output / status text).

JavaScriptEventLoop.installGlobalExecutor()

Task { @MainActor in
    do {
        app = try await App.create(title: "Bielik2D Demo",
                                   width: Int(windowSize.x), height: Int(windowSize.y))
        print("GPU driver: \(app.driverName)")

        // Fetch + decode every sprite asset before any scene is constructed; the
        // web `Sprite(path:)` reads from this prefetched cache synchronously.
        try await app.assetLoader?.prefetch(spriteAssetPaths)

        font = Font.system(ptSize: 28)
        smallFont = Font.system(ptSize: 18)
        draw = Draw(textEngine: app.makeTextEngine())
        camera = Camera(viewportSize: SIMD2(Float(app.size.x), Float(app.size.y)))

        try buildScenes()
        app.startLoop(runFrame)
    } catch {
        print("bielik2d: error \(error)")
    }
}
#else
// MARK: - Native entry point

app = try App(title: "Bielik2D Demo", width: Int(windowSize.x), height: Int(windowSize.y))
print("GPU driver: \(app.driverName)")

font = try Font.system(ptSize: 28)
smallFont = try Font.system(ptSize: 18)
draw = Draw(textEngine: try app.renderer.makeTextEngine())
camera = Camera(viewportSize: windowSize)

try buildScenes()

while app.isRunning {
    runFrame()
}
app.destroy()
#endif
