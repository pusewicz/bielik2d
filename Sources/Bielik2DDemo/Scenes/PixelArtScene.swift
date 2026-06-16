import Bielik2D
import Foundation

/// One sprite upscaled three ways with a sweeping non-integer factor: nearest shimmers, linear
/// softens, pixelArt stays crisp and stable.
final class PixelArtScene: Scene {
    let name = "Pixel-art Scaling"
    let summary = "nearest / linear / pixelArt — SDL_SCALEMODE_PIXELART stays crisp and stable"
    let controls = ""

    private let player: Sprite

    init(app: App) throws { player = try Sprite(path: assetPath("p1_stand", "png")) }

    func update(_ ctx: SceneContext) {
        let upscale: Float = 3.0 + sin(ctx.time) * 0.9
        var s = player
        s.scale = SIMD2(upscale, upscale)
        let spriteW = Float(player.width) * upscale
        let spriteH = Float(player.height) * upscale
        let gap: Float = 80
        let cy = ctx.stage.y + ctx.stage.height / 2
        let baseline = cy + spriteH / 2
        let startX = ctx.stage.x + ctx.stage.width / 2 - (spriteW * 3 + gap * 2) / 2
        let modes: [(ScaleMode, String)] = [(.nearest, "nearest"), (.linear, "linear"), (.pixelArt, "pixelArt")]
        for (i, m) in modes.enumerated() {
            let x = startX + Float(i) * (spriteW + gap)
            s.draw(at: SIMD2(x, baseline - spriteH), scaleMode: m.0)
            ctx.draw.text(m.1, font: ctx.font, at: SIMD2(x, baseline + 6), color: .white)
        }
    }
}
