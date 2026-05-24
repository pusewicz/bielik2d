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

/// A drawable sprite: a reference to a shared asset (one or more named animations,
/// owned by the renderer's `SpriteRegistry`) plus this instance's own playback cursor
/// and draw state. The value is a small POD — an asset id, the current frame's cached
/// id/size, where playback sits, and pivot/scale/opacity/scaleMode — so copy it freely
/// and tweak the draw state before drawing. A plain PNG is a one-frame animation, so
/// `update` simply does nothing for it.
public struct Sprite: Equatable {
    let asset: SpriteAssetID
    var animationIndex: Int
    var cursor: AnimationCursor
    var frameCount: Int            // of the current animation; > 1 means it animates

    /// Whether `update` advances playback.
    public var paused: Bool

    // The current frame, cached so drawing never has to touch the registry.
    var imageID: SpriteID
    public private(set) var width: Int
    public private(set) var height: Int

    public var pivot: SIMD2<Float>
    public var scale: SIMD2<Float>
    public var opacity: Float
    /// How this sprite is filtered when drawn off its native size. Set once and
    /// forget, like `SDL_SetTextureScaleMode`. `nil` (the default) inherits the
    /// ambient mode set via `Draw.pushScaleMode`.
    public var scaleMode: ScaleMode?

    /// Builds a sprite sitting at the start of its default animation. The registry is
    /// read once here to cache the first frame; the value keeps no reference to it.
    init(asset: SpriteAssetID, in registry: SpriteRegistry) {
        self.asset = asset
        self.animationIndex = 0
        self.cursor = AnimationCursor()
        self.paused = false
        self.pivot = .zero
        self.scale = SIMD2(1, 1)
        self.opacity = 1
        self.scaleMode = nil

        let anim = registry.asset(asset).animations[0]
        self.frameCount = anim.frames.count
        let frame = anim.frames[0]
        self.imageID = frame.imageID
        self.width = frame.width
        self.height = frame.height
    }

    /// Loads (and path-caches) a sprite through the active renderer (`App` installs it).
    public init(path: String) throws {
        self = try Sprite.activeRenderer().sprite(path: path)
    }

    /// Loads (and path-caches) an animated sprite by slicing a grid sprite sheet into
    /// `frameWidth`×`frameHeight` cells, played as one looping animation at `fps`.
    public init(sheet path: String, frameWidth: Int, frameHeight: Int, fps: Double = 10) throws {
        self = try Sprite.activeRenderer().sprite(sheet: path, frameWidth: frameWidth, frameHeight: frameHeight, fps: fps)
    }

    /// Loads (and path-caches) a sprite on a specific renderer.
    public init(path: String, on renderer: Renderer) throws {
        self = try renderer.sprite(path: path)
    }

    /// Registers in-memory pixels as a one-frame sprite on a specific renderer.
    public init(image: ImageBytes, on renderer: Renderer) {
        self = renderer.makeSprite(image: image)
    }

    private static func activeRenderer() throws -> Renderer {
        guard let r = Renderer.current else {
            throw SpriteError.loadFailed("no active renderer — create an App first, or use the on:/in: forms")
        }
        return r
    }

    // MARK: - Playback

    /// Advances the current animation by `dt` seconds against `registry`, re-caching
    /// the current frame. A static (single-frame) sprite returns immediately without
    /// touching the registry, so a screen full of them costs nothing.
    mutating func update(_ dt: Double, in registry: SpriteRegistry) {
        guard !paused, frameCount > 1 else { return }
        let anim = registry.asset(asset).animations[animationIndex]
        cursor = anim.advanced(cursor, by: dt)
        cache(anim.frames[cursor.frame])
    }

    /// Switches to the animation named `name` (a no-op if there's no such animation),
    /// restarting from the first frame unless `restart` is false.
    mutating func play(_ name: String, in registry: SpriteRegistry, restart: Bool = true) {
        let asset = registry.asset(self.asset)
        guard let idx = asset.animationIndex(name) else { return }
        guard idx != animationIndex || restart else { return }
        animationIndex = idx
        cursor = AnimationCursor()
        let anim = asset.animations[idx]
        frameCount = anim.frames.count
        cache(anim.frames[0])
    }

    /// Advances playback against the active renderer. See `update(_:in:)`.
    public mutating func update(_ dt: Double) {
        guard let r = Renderer.current else {
            preconditionFailure("Sprite.update needs an active App/Renderer")
        }
        update(dt, in: r.spriteRegistry)
    }

    /// Switches animation against the active renderer. See `play(_:in:restart:)`.
    public mutating func play(_ name: String, restart: Bool = true) {
        guard let r = Renderer.current else {
            preconditionFailure("Sprite.play needs an active App/Renderer")
        }
        play(name, in: r.spriteRegistry, restart: restart)
    }

    public mutating func pause() { paused = true }
    public mutating func resume() { paused = false }

    /// Queues this sprite into the ambient `Draw` (the most recently created one) —
    /// sugar for `draw.sprite(self, at:)`. Use that explicit form with multiple Draws.
    public func draw(at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        guard let d = Draw.current else {
            preconditionFailure("Sprite.draw needs an active Draw; use draw.sprite(_:at:)")
        }
        d.sprite(self, at: at, scaleMode: scaleMode)
    }

    private mutating func cache(_ frame: Frame) {
        imageID = frame.imageID
        width = frame.width
        height = frame.height
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
            id: s.imageID,
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
