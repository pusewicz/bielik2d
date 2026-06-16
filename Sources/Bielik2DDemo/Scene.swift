import Bielik2D
import Foundation

/// Per-frame context handed to every scene so scenes never reach for globals.
struct SceneContext {
    let app: App
    let draw: Draw
    let font: Font
    let camera: Camera
    let dt: Float
    let time: Float
    let stage: Rect          // content area below the title band, above the footer
    let windowSize: SIMD2<Float>
}

/// One self-contained showcase. The shell draws the name/summary/controls HUD; the scene draws
/// only its content within `ctx.stage`.
protocol Scene: AnyObject {
    var name: String { get }
    var summary: String { get }
    var controls: String { get }
    func onEnter(_ ctx: SceneContext)
    func onExit()
    func update(_ ctx: SceneContext)
}

extension Scene {
    func onEnter(_ ctx: SceneContext) {}
    func onExit() {}
}

/// Resolve a bundled demo asset (the demo target ships `assets/` as a resource).
func assetPath(_ name: String, _ ext: String) -> String {
    Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "assets")!.path
}
