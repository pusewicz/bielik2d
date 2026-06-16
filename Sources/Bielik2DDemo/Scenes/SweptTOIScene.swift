import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web `App` lives here; native ships it in Bielik2D
#endif

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
