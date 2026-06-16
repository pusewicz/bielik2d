import Bielik2D
#if os(WASI)
import Bielik2DWeb  // web `App` lives here; native ships it in Bielik2D
#endif
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

/// Resolve a demo asset path that the active `Sprite(path:)` loader understands.
///
/// Native reads from disk, so this hands back the `Bundle.module` file path. Web
/// has no filesystem — the loader `fetch`es a URL — so this returns the relative
/// key `"assets/<name>.<ext>"`. That exact same string is what `build-web.sh`
/// copies into `web/dist/assets/` and what the web `main` prefetches, so the
/// prefetch key and the `Sprite(path:)` key are byte-identical.
func assetPath(_ name: String, _ ext: String) -> String {
    #if os(WASI)
    "assets/\(name).\(ext)"
    #else
    Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "assets")!.path
    #endif
}
