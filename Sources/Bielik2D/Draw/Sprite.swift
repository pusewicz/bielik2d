#if canImport(CSDL3)
import CSDL3
import Foundation

public enum SpriteError: Error, CustomStringConvertible {
    case loadFailed(String)

    public var description: String {
        switch self {
        case .loadFailed(let m): "sprite load failed: \(m)"
        }
    }
}

/// A textured rectangle. Each Sprite owns its own GPU texture in v0 — a shared
/// atlas (cute_spritebatch-equivalent) is deferred. Equality identifies which
/// sprites share a texture so the batcher can merge their draws.
public struct Sprite: Equatable {
    let texture: Texture
    public let width: Int
    public let height: Int
    public var pivot: SIMD2<Float>
    public var scale: SIMD2<Float>
    public var opacity: Float
    /// How this sprite is filtered when drawn off its native size. Set once and
    /// forget, like `SDL_SetTextureScaleMode`. `nil` (the default) inherits the
    /// ambient mode set via `Draw.pushScaleMode`.
    public var scaleMode: ScaleMode?

    public init(png path: String, on renderer: Renderer) throws {
        let image = try SDL3AssetLoader.loadImage(path: path)
        try self.init(image: image, on: renderer)
    }

    public init(image: ImageBytes, on renderer: Renderer) throws {
        let device = renderer.device
        let w = image.width
        let h = image.height
        let byteCount = image.pixels.count
        let tex = try device.makeTexture(width: w, height: h, format: .rgba8Unorm, usage: .sampler)
        let xfer = try device.makeTransferBuffer(size: byteCount, usage: .upload)
        defer { xfer.destroy() }
        xfer.withMappedMemory { dst in
            image.pixels.withUnsafeBytes { src in
                dst.copyMemory(from: src.baseAddress!, byteCount: byteCount)
            }
        }
        let cmd = try device.acquireCommandBuffer()
        cmd.withCopyPass { copy in
            copy.upload(from: xfer, to: tex)
        }
        cmd.submit()

        self.texture = tex
        self.width = w
        self.height = h
        self.pivot = .zero
        self.scale = SIMD2(1, 1)
        self.opacity = 1
        self.scaleMode = nil
    }

    public func destroy() {
        texture.destroy()
    }

    public static func == (lhs: Sprite, rhs: Sprite) -> Bool {
        lhs.texture.handle == rhs.texture.handle
    }
}

extension Draw {
    /// Draws a sprite at `at` (top-left) in world space, applying the current
    /// transform, color tint, and the sprite's own scale and opacity. The scale
    /// mode resolves most-specific-first: the `scaleMode:` argument, then the
    /// sprite's own `scaleMode`, then the ambient `pushScaleMode` state.
    public func sprite(_ s: Sprite, at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        batcher.setTexture(s.texture.handle)
        let w = Float(s.width) * s.scale.x
        let h = Float(s.height) * s.scale.y
        let rect = Rect(x: at.x - s.pivot.x, y: at.y - s.pivot.y, width: w, height: h)
        let uv = Rect(x: 0, y: 0, width: 1, height: 1)
        let color = SIMD4<Float>(1, 1, 1, s.opacity)
        let mode = scaleMode ?? s.scaleMode ?? currentScaleMode
        quad(rect: rect, uv: uv, color: color,
             scaleMode: mode, textureSize: SIMD2(Float(s.width), Float(s.height)))
    }
}
#endif
