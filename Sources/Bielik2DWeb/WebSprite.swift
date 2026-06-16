#if os(WASI)
import JavaScriptKit
import Bielik2D

/// A drawable web sprite — the web counterpart of a one-frame native `Sprite`.
/// Create one with `WebRenderer.makeSprite(from:)` (or the path-deduped
/// `makeSprite(path:from:)`) from a `LoadedImage` the async `WebAssetLoader`
/// prefetched, then draw it with `Draw.sprite(_:at:)`.
///
/// The backing texture is sampler-usable; the renderer registers `token` against
/// its bind-group table at creation, so `Draw.sprite` only needs to bind the
/// token — the same texture-token mechanism glyph and canvas textures use.
public struct WebSprite {
    public let texture: JSObject
    /// The opaque key the batcher carries; the renderer maps it to the texture's
    /// bind group when it encounters the sprite command.
    public let token: OpaquePointer
    public let width: Int
    public let height: Int

    public init(texture: JSObject, token: OpaquePointer, width: Int, height: Int) {
        self.texture = texture
        self.token = token
        self.width = width
        self.height = height
    }
}

extension Draw {
    /// Draws a `WebSprite` as a textured quad at `at` (top-left, world space),
    /// applying the current transform and colour tint. `scale` multiplies the
    /// sprite's native pixel size; `scaleMode: .pixelArt`/`.nearest` upscales
    /// crisply (`nil` inherits the ambient `pushScaleMode` state). Mirrors the
    /// native `Draw.sprite(_:at:)`, but takes a `WebSprite` value.
    public func sprite(_ s: WebSprite, at: SIMD2<Float> = .zero,
                       scale: SIMD2<Float> = SIMD2(1, 1),
                       scaleMode: ScaleMode? = nil) {
        setBatcherTexture(s.token)
        let w = Float(s.width) * scale.x
        let h = Float(s.height) * scale.y
        let rect = Rect(x: at.x, y: at.y, width: w, height: h)
        let mode = scaleMode ?? currentScaleMode
        quad(rect: rect, uv: Rect(x: 0, y: 0, width: 1, height: 1),
             color: SIMD4<Float>(1, 1, 1, 1),
             scaleMode: mode, textureSize: SIMD2(Float(s.width), Float(s.height)))
        setBatcherTexture(nil)
    }
}
#endif
