#if canImport(CSDL3)
/// An offscreen render target. Wraps a sampler+color-target texture so you
/// can draw into it via `cmd.renderTo(canvas) { pass in … }` and then sample
/// it back into another render pass with `Draw.canvas(_:at:)`.
public struct Canvas {
    public let texture: Texture
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int, format: TextureFormat = .rgba8Unorm, on device: GPUDevice) throws {
        let tex = try device.makeTexture(
            width: width, height: height, format: format,
            usage: [.sampler, .colorTarget]
        )
        self.texture = tex
        self.width = width
        self.height = height
    }

    public func destroy() {
        texture.destroy()
    }
}

extension CommandBuffer {
    public func renderTo(_ canvas: Canvas, clear: Color? = nil, _ body: (RenderPass) -> Void) {
        withRenderPass(colorTarget: canvas.texture, clear: clear, body)
    }
}

extension Draw {
    /// Samples a canvas as a textured quad. Apply the current transform/color.
    /// Pass `scaleMode: .pixelArt` to upscale a low-res canvas crisply — the
    /// classic "render to a small target, blow it up to the window" pattern.
    /// `nil` inherits the ambient `Draw.pushScaleMode` state.
    public func canvas(_ c: Canvas, at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        batcher.setTexture(c.texture.handle)
        let rect = Rect(x: at.x, y: at.y, width: Float(c.width), height: Float(c.height))
        let mode = scaleMode ?? currentScaleMode
        quad(rect: rect, uv: Rect(x: 0, y: 0, width: 1, height: 1), color: SIMD4<Float>(1, 1, 1, 1),
             scaleMode: mode, textureSize: SIMD2(Float(c.width), Float(c.height)))
    }
}
#endif
