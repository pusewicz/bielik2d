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
