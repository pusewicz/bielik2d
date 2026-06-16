import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web twins of Sprite/ImageBytes live here; native ships them in Bielik2D
#endif
import Foundation

/// Sprite loading + dedup + a frame-stepped generated animation.
final class SpritesScene: Scene {
    let name = "Sprites & Animation"
    let summary = "Sprite(path:) ergonomic loading with dedup, plus a frame-stepped animated sheet"
    let controls = ""

    private let player: Sprite
    private var blinker: Sprite

    init(app: App) throws {
        player = try Sprite(path: assetPath("p1_stand", "png"))
        let again = try Sprite(path: assetPath("p1_stand", "png"))
        print("sprite dedup: same asset on second load = \(player == again)")
        blinker = app.renderer.makeSprite(
            sheet: SpritesScene.colorSheet(cell: 32,
                colors: [[230, 70, 70], [70, 200, 90], [80, 120, 240], [240, 200, 60]]),
            frameWidth: 32, frameHeight: 32, fps: 6)
        blinker.scale = SIMD2(4, 4)
        blinker.scaleMode = .nearest
    }

    func update(_ ctx: SceneContext) {
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2

        var p = player
        p.scale = SIMD2(4, 4)
        p.scaleMode = .nearest
        p.draw(at: SIMD2(cx - 240, cy - Float(player.height) * 2))
        ctx.draw.text("Sprite(path:)", font: ctx.font, at: SIMD2(cx - 260, cy + 90), color: .white)

        blinker.update(Double(ctx.dt))
        blinker.draw(at: SIMD2(cx + 120, cy - 64))
        ctx.draw.text("animated sheet", font: ctx.font, at: SIMD2(cx + 90, cy + 90), color: .white)
    }

    /// A `cell × (cell·colors.count)` strip, one solid colour per frame.
    static func colorSheet(cell: Int, colors: [[UInt8]]) -> ImageBytes {
        let w = cell * colors.count
        var px = [UInt8](repeating: 0, count: w * cell * 4)
        for (c, color) in colors.enumerated() {
            for y in 0..<cell {
                for x in 0..<cell {
                    let o = (y * w + c * cell + x) * 4
                    px[o] = color[0]; px[o + 1] = color[1]; px[o + 2] = color[2]; px[o + 3] = 255
                }
            }
        }
        return ImageBytes(width: w, height: cell, pixels: Data(px))
    }
}
