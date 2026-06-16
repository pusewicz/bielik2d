import Bielik2D
import Foundation

/// pushScissor clips drawing to a rect; pushBlendState(.additive) makes overlaps brighten.
final class DrawStateScene: Scene {
    let name = "Draw State: Scissor & Blend"
    let summary = "pushScissor clips to a rect (drifting circles stay inside); pushBlendState .additive glows"
    let controls = ""

    init(app: App) {}

    func update(_ ctx: SceneContext) {
        let d = ctx.draw
        let panel = Rect(x: ctx.stage.x + 40, y: ctx.stage.y + 60, width: 320, height: 200)
        d.boxFill(panel, cornerRadius: 0, color: Color(r: 0.14, g: 0.15, b: 0.22))
        d.with(scissor: panel) {
            let drift = (sin(ctx.time) * 0.5 + 0.5) * 280
            for i in 0..<8 {
                let cx = panel.x - 40 + drift + Float(i) * 70
                d.circleFill(center: SIMD2(cx, panel.y + 100), radius: 48,
                             color: Color(r: 0.4, g: 0.8, b: 1.0))
            }
        }
        d.box(panel, stroke: 2, color: Color(r: 0.5, g: 0.9, b: 1.0))
        d.text("pushScissor", font: ctx.font, at: SIMD2(panel.x, panel.maxY + 8), color: .white)

        let bx = ctx.stage.x + 460
        let by = ctx.stage.y + 150
        d.with(blendState: .additive) {
            d.circleFill(center: SIMD2(bx, by), radius: 60, color: Color(r: 0.8, g: 0.15, b: 0.15))
            d.circleFill(center: SIMD2(bx + 72, by), radius: 60, color: Color(r: 0.15, g: 0.8, b: 0.15))
            d.circleFill(center: SIMD2(bx + 36, by + 64), radius: 60, color: Color(r: 0.15, g: 0.2, b: 0.9))
        }
        d.text("pushBlendState(.additive)", font: ctx.font, at: SIMD2(bx - 30, by + 150), color: .white)
    }
}
