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

/// A textured rectangle. The image's pixels live in the renderer's `SpriteBatch`
/// and are packed into a shared atlas on first draw — the GPU texture stays hidden,
/// CF-style. A `Sprite` is a lightweight handle plus per-instance draw state
/// (pivot/scale/opacity/scaleMode); copy it freely and tweak those before drawing.
public struct Sprite: Equatable {
    let id: SpriteID
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
        self.init(image: image, on: renderer)
    }

    public init(image: ImageBytes, on renderer: Renderer) {
        self.id = renderer.register(image)
        self.width = image.width
        self.height = image.height
        self.pivot = .zero
        self.scale = SIMD2(1, 1)
        self.opacity = 1
        self.scaleMode = nil
    }

    public static func == (lhs: Sprite, rhs: Sprite) -> Bool {
        lhs.id == rhs.id
    }
}

extension Draw {
    /// Queues a sprite drawn at `at` (top-left) in world space, applying the current
    /// transform, color tint, and the sprite's own scale and opacity. The draw is
    /// deferred: the renderer resolves it against the atlas at flush. The scale mode
    /// resolves most-specific-first: the `scaleMode:` argument, then the sprite's own
    /// `scaleMode`, then the ambient `pushScaleMode` state.
    public func sprite(_ s: Sprite, at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        let w = Float(s.width) * s.scale.x
        let h = Float(s.height) * s.scale.y
        let rect = Rect(x: at.x - s.pivot.x, y: at.y - s.pivot.y, width: w, height: h)
        let t = currentTransform
        let tint = currentColor
        let mode = scaleMode ?? s.scaleMode ?? currentScaleMode
        spriteInstances.append(SpriteInstance(
            id: s.id,
            p0: t.transform(SIMD2(rect.minX, rect.minY)),
            p1: t.transform(SIMD2(rect.maxX, rect.minY)),
            p2: t.transform(SIMD2(rect.maxX, rect.maxY)),
            p3: t.transform(SIMD2(rect.minX, rect.maxY)),
            color: SIMD4(tint.r, tint.g, tint.b, tint.a * s.opacity),
            scaleData: SIMD4(Float(s.width), Float(s.height), mode.shaderValue, 0),
            layer: currentLayer))
    }
}
#endif
