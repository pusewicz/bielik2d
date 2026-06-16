#if os(WASI)
import JavaScriptKit
import Bielik2D

/// An offscreen WebGPU render target — the web counterpart of the native
/// `Canvas`. Create one with `WebRenderer.makeCanvas(width:height:)`, render a
/// `Draw` into it with `WebRenderer.render(_:to:)`, then sample it back into a
/// later pass with `Draw.canvas(_:at:)`.
///
/// The backing texture is colour-target + sampler usable; the renderer registers
/// `token` against its bind-group table at creation, so `Draw.canvas` only needs
/// to bind the token (the same texture-token mechanism glyph textures use).
public struct WebCanvas {
    public let texture: JSObject
    /// The opaque key the batcher carries; the renderer maps it to the texture's
    /// bind group when it encounters the canvas command.
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
    /// Samples a `WebCanvas` as a textured quad, applying the current transform
    /// and colour tint. `scaleMode: .pixelArt` upscales a low-res canvas crisply
    /// (`nil` inherits the ambient `pushScaleMode` state). Mirrors the native
    /// `Draw.canvas(_:at:)`.
    public func canvas(_ c: WebCanvas, at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        setBatcherTexture(c.token)
        let rect = Rect(x: at.x, y: at.y, width: Float(c.width), height: Float(c.height))
        let mode = scaleMode ?? currentScaleMode
        quad(rect: rect, uv: Rect(x: 0, y: 0, width: 1, height: 1),
             color: SIMD4<Float>(1, 1, 1, 1),
             scaleMode: mode, textureSize: SIMD2(Float(c.width), Float(c.height)))
        setBatcherTexture(nil)
    }
}
#endif
