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
    public let texture: Texture
    public let width: Int
    public let height: Int
    public var pivot: SIMD2<Float>
    public var scale: SIMD2<Float>
    public var opacity: Float

    public init(png path: String, on device: GPUDevice) throws {
        let image = try SDL3AssetLoader.loadImage(path: path)
        try self.init(image: image, on: device)
    }

    public init(image: ImageBytes, on device: GPUDevice) throws {
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
    /// transform, color tint, and the sprite's own scale and opacity.
    public func sprite(_ s: Sprite, at: SIMD2<Float> = .zero) {
        batcher.setTexture(s.texture.handle)
        let w = Float(s.width) * s.scale.x
        let h = Float(s.height) * s.scale.y
        let rect = Rect(x: at.x - s.pivot.x, y: at.y - s.pivot.y, width: w, height: h)
        let uv = Rect(x: 0, y: 0, width: 1, height: 1)
        let color = SIMD4<Float>(1, 1, 1, s.opacity)
        quad(rect: rect, uv: uv, color: color)
    }
}
#endif
