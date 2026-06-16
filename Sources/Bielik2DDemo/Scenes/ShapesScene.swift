import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web `App` lives here; native ships it in Bielik2D
#endif

/// Phase-19 shape primitives: outline circle, rounded boxFill, filled + stroked tri, polyline,
/// poly outline, a shapeAA-smoothed polygon, and a translucent filled convex polygon.
final class ShapesScene: Scene {
    let name = "Shapes (Phase 19)"
    let summary = "Outline circle, rounded boxFill, filled + stroked tri, polyline, poly, polyFill, shapeAA"
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
        // Translucent filled convex hexagon — AA edges with no double-blended seams.
        let hx = cx + 360
        d.polyFill([SIMD2(hx + 32, y), SIMD2(hx + 16, y - 30), SIMD2(hx - 16, y - 30),
                    SIMD2(hx - 32, y), SIMD2(hx - 16, y + 30), SIMD2(hx + 16, y + 30)],
                   color: Color(r: 0.4, g: 0.85, b: 1.0, a: 0.8))
    }
}
