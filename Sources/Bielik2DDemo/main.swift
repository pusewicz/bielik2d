import Bielik2D
import Foundation

let windowSize = SIMD2<Float>(1280, 720)
let unit = Rect(x: 0, y: 0, width: 1, height: 1)

let app = try App(title: "Bielik2D Demo", width: Int(windowSize.x), height: Int(windowSize.y))
print("GPU driver: \(app.gpu.driverName)")

// All GPU resources come from the renderer — no pipelines, buffers, or samplers
// in user code anymore.
let player = try app.renderer.makeSprite(png:
    Bundle.module.url(forResource: "p1_stand", withExtension: "png", subdirectory: "assets")!.path)
let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 28)
let canvas = try app.renderer.makeCanvas(width: 256, height: 256, format: .bgra8Unorm)
let canvasSize = SIMD2<Float>(256, 256)

let draw = Draw(textEngine: try app.renderer.makeTextEngine())
let cameraCanvas = Camera(viewportSize: canvasSize)
let startTime = Date()

while app.isRunning {
    app.update()

    let t = Float(Date().timeIntervalSince(startTime))

    // Canvas pass: a spinning pink quad, in canvas-local coords. `with` scopes
    // the transform + tint and pops them automatically.
    draw.with(transform: .translation(x: canvasSize.x / 2, y: canvasSize.y / 2) * .rotation(angleRadians: t),
              color: Color(r: 1.0, g: 0.4, b: 0.6)) {
        draw.quad(rect: Rect(x: -90, y: -90, width: 180, height: 180), uv: unit, color: .one)
    }
    app.renderer.render(draw, to: canvas, clear: Color(r: 0.05, g: 0.10, b: 0.30), camera: cameraCanvas)

    // Main pass.
    draw.text("Hello, Bielik!", font: font, at: SIMD2<Float>(40, 40), color: .white)
    draw.circleFill(center: SIMD2(120, 150), radius: 50, color: Color(r: 0.4, g: 0.8, b: 1.0))
    draw.line(from: SIMD2(210, 110), to: SIMD2(360, 190),
              thickness: 8, color: Color(r: 1.0, g: 0.9, b: 0.3))

    // Pixel-art showcase: one sprite upscaled three ways. The scale sweeps
    // through non-integer factors, so nearest visibly shimmers, linear stays
    // soft, and pixelArt stays crisp *and* stable — the whole point of
    // SDL_SCALEMODE_PIXELART.
    let upscale: Float = 2.75 + sin(t) * 0.75
    var demoSprite = player
    demoSprite.scale = SIMD2(upscale, upscale)
    let spriteW = Float(player.width) * upscale
    let spriteH = Float(player.height) * upscale
    let gap: Float = 70
    let baseline = windowSize.y - 70
    let startX = (windowSize.x - (spriteW * 3 + gap * 2)) / 2
    let modes: [(ScaleMode, String)] = [(.nearest, "nearest"), (.linear, "linear"), (.pixelArt, "pixelArt")]
    for (i, entry) in modes.enumerated() {
        let x = startX + Float(i) * (spriteW + gap)
        draw.sprite(demoSprite, at: SIMD2(x, baseline - spriteH), scaleMode: entry.0)
        draw.text(entry.1, font: font, at: SIMD2(x, baseline + 6), color: .white)
    }

    // Composite the offscreen canvas top-right, upscaled with pixel-art sampling.
    draw.with(scaleMode: .pixelArt) {
        draw.canvas(canvas, at: SIMD2(windowSize.x - canvasSize.x - 40, 40))
    }

    app.drawOntoScreen(draw, clear: Color(r: 0.10, g: 0.12, b: 0.18))
}
app.destroy()
