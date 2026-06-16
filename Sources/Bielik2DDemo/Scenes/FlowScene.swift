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
