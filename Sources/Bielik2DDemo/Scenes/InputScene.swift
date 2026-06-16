import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web twin of Sprite lives here; native ships it in Bielik2D
#endif
import Foundation

/// Keyboard / mouse / gamepad: a sprite you drive, a mouse-aim dot, and a live stick readout.
final class InputScene: Scene {
    let name = "Input"
    let summary = "Keyboard, mouse, and gamepad — drive a sprite and read live device state"
    let controls = "WASD / arrows / left-stick: move   ·   left mouse: grow aim dot"

    private let player: Sprite
    private var pos: SIMD2<Float> = .zero
    private let speed: Float = 320

    init(app: App) throws { player = try Sprite(path: assetPath("p1_stand", "png")) }

    func onEnter(_ ctx: SceneContext) {
        pos = SIMD2(ctx.stage.x + ctx.stage.width / 2, ctx.stage.y + ctx.stage.height / 2)
    }

    func update(_ ctx: SceneContext) {
        let kb = ctx.app.input.keyboard
        let gp = ctx.app.input.gamepad(0)
        var move = SIMD2<Float>(0, 0)
        if kb.down(.a) || kb.down(.left) { move.x -= 1 }
        if kb.down(.d) || kb.down(.right) { move.x += 1 }
        if kb.down(.w) || kb.down(.up) { move.y -= 1 }
        if kb.down(.s) || kb.down(.down) { move.y += 1 }
        move += gp.leftStick
        pos += move * speed * ctx.dt
        pos.x = min(max(pos.x, ctx.stage.minX), ctx.stage.maxX)
        pos.y = min(max(pos.y, ctx.stage.minY), ctx.stage.maxY)

        var p = player
        p.scale = SIMD2(2.5, 2.5)
        p.scaleMode = .nearest
        p.draw(at: pos)

        let aim = ctx.camera.screenToWorld(ctx.app.input.mouse.position)
        let aiming = ctx.app.input.mouse.down(.left)
        ctx.draw.circleFill(center: aim, radius: aiming ? 18 : 10, color: Color(r: 1.0, g: 0.5, b: 0.2))

        let stick = gp.leftStick
        ctx.draw.text(String(format: "left-stick: %.2f, %.2f", stick.x, stick.y),
                      font: ctx.font, at: SIMD2(ctx.stage.x, ctx.stage.y), color: Color(r: 0.7, g: 0.9, b: 1.0))
    }
}
