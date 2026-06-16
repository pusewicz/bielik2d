import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web `App` lives here; native ships it in Bielik2D
#endif

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
