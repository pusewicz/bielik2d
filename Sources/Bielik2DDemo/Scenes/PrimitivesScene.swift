import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web `App` lives here; native ships it in Bielik2D
#endif

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
