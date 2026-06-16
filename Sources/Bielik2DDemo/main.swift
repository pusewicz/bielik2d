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
    try PixelArtScene(app: app),
    try InputScene(app: app),
    try AudioScene(app: app),
    PrimitivesScene(app: app),
    ShapesScene(app: app),
    try TextCanvasScene(app: app),
]
var current = 0

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
