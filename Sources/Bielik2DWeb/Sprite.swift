#if os(WASI)
import JavaScriptKit
import Bielik2D
import Foundation

public struct SpriteError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { "sprite load failed: \(message)" }
}

/// Where playback sits within a web sprite's frames: which frame and how much time
/// has accrued toward the next. A faithful copy of the native `AnimationCursor`
/// (`SpriteAsset.swift`) stepping for the `.loop` mode the demo sheets use — the
/// native types are module-internal (and `Frame` is tied to the atlas `SpriteID`),
/// so they can't cross the `Bielik2DWeb` boundary; this is the small unavoidable
/// re-statement of that pure logic.
struct WebSpriteAnimation {
    let frameDuration: Double  // seconds; 0 means "never advance"
    let count: Int

    /// Spends whole frames out of the accumulated time and wraps (loop) — a fat
    /// `dt` walks several frames, matching native `Animation.advanced`.
    func advance(frame: Int, elapsed: Double, by dt: Double) -> (frame: Int, elapsed: Double) {
        guard count > 1, frameDuration > 0 else { return (frame, elapsed) }
        var f = frame
        var e = elapsed + dt
        while e >= frameDuration {
            e -= frameDuration
            f = (f + 1) % count
        }
        return (f, e)
    }
}

/// Web twin of the native `Sprite` value. Same public surface the demo scenes
/// consume — `init(path:)`, `init(sheet:...)`, `.scale`, `.scaleMode`, `.width`,
/// `.height`, `.draw(at:)` / `.draw(at:scaleMode:)`, `.update(_:)` — but backed by
/// the web renderer's texture-token model instead of the native atlas.
///
/// A static PNG is a one-frame sprite; an animated sheet caches one web texture per
/// cell (`frames`) and advances through `WebSpriteAnimation` (the pure native
/// stepping, restated). Only one `Sprite` compiles per build (native vs web), so
/// scene source never branches.
public struct Sprite: Equatable {
    /// One web texture per animation cell.
    private let frames: [WebSprite]
    private let animation: WebSpriteAnimation
    private var frameIndex: Int
    private var elapsed: Double

    /// Whether `update` advances playback.
    public var paused: Bool

    // The current frame's size, cached so drawing never re-derives it.
    public private(set) var width: Int
    public private(set) var height: Int

    public var pivot: SIMD2<Float>
    public var scale: SIMD2<Float>
    public var opacity: Float
    /// How this sprite is filtered when drawn off its native size. `nil` inherits
    /// the ambient mode set via `Draw.pushScaleMode`. Mirrors native semantics.
    public var scaleMode: ScaleMode?

    /// Builds a sprite from already-uploaded per-frame web textures, looping at
    /// `frameDuration` seconds per frame (0 = static). Sits at the first frame.
    init(frames: [WebSprite], frameDuration: Double) {
        precondition(!frames.isEmpty, "Sprite needs at least one frame")
        self.frames = frames
        self.animation = WebSpriteAnimation(frameDuration: frameDuration, count: frames.count)
        self.frameIndex = 0
        self.elapsed = 0
        self.paused = false
        self.pivot = .zero
        self.scale = SIMD2(1, 1)
        self.opacity = 1
        self.scaleMode = nil
        self.width = frames[0].width
        self.height = frames[0].height
    }

    /// Loads a sprite by path through the active web renderer (`App` installs it
    /// as `Renderer.current`). The image MUST have been prefetched into the
    /// renderer's `AssetLoader` cache — the demo's web bootstrap prefetches every
    /// sprite path before constructing scenes. Throws if no renderer is active or
    /// the path isn't yet resident.
    public init(path: String) throws {
        self = try Sprite.activeRenderer().sprite(path: path)
    }

    /// Loads an animated sprite by slicing a grid sheet at `path` into
    /// `frameWidth`×`frameHeight` cells, played as one looping animation at `fps`.
    /// The sheet image must have been prefetched (see `init(path:)`).
    public init(sheet path: String, frameWidth: Int, frameHeight: Int, fps: Double = 10) throws {
        self = try Sprite.activeRenderer().sprite(sheet: path, frameWidth: frameWidth, frameHeight: frameHeight, fps: fps)
    }

    private static func activeRenderer() throws -> WebRenderer {
        guard let r = WebRenderer.current else {
            throw SpriteError(message: "no active renderer — create an App first")
        }
        return r
    }

    // MARK: - Playback

    /// The current frame index within the animation.
    public var frame: Int { frameIndex }

    /// Advances the animation by `dt` seconds, re-caching the current frame's size.
    /// A static (single-frame) sprite returns immediately, so a screen full of them
    /// costs nothing — same fast path as native.
    public mutating func update(_ dt: Double) {
        guard !paused, frames.count > 1 else { return }
        (frameIndex, elapsed) = animation.advance(frame: frameIndex, elapsed: elapsed, by: dt)
        let f = frames[frameIndex]
        width = f.width
        height = f.height
    }

    public mutating func pause() { paused = true }
    public mutating func resume() { paused = false }

    /// Queues this sprite into the ambient `Draw`, mirroring native's sugar for
    /// `draw.sprite(self, at:)`.
    public func draw(at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        guard let d = Draw.current else {
            preconditionFailure("Sprite.draw needs an active Draw; use draw.sprite(_:at:)")
        }
        d.sprite(self, at: at, scaleMode: scaleMode)
    }

    /// The web texture token for the current frame — what `Draw.sprite` binds.
    var currentSprite: WebSprite { frames[frameIndex] }

    /// Two sprites are equal when they reference the same frame textures and sit at
    /// the same playback/draw state. Path-deduped loads (`Sprite(path:)` for one
    /// path) reuse one `WebSprite` token per frame, so they compare equal — the web
    /// twin of native's POD equality that `SpritesScene`'s dedup `print` relies on.
    public static func == (lhs: Sprite, rhs: Sprite) -> Bool {
        lhs.frames.map(\.token) == rhs.frames.map(\.token)
            && lhs.frameIndex == rhs.frameIndex
            && lhs.scale == rhs.scale
            && lhs.scaleMode == rhs.scaleMode
            && lhs.pivot == rhs.pivot
            && lhs.opacity == rhs.opacity
            && lhs.paused == rhs.paused
    }
}

/// Web twin of the native `ImageBytes` (which is `#if canImport(CSDL3)`-only):
/// tightly-packed, top-left-origin RGBA8 pixels with their size. Mirrors the
/// native init `ImageBytes(width:height:pixels:)` so procedural-pixel scene code
/// (e.g. `SpritesScene.colorSheet`) compiles unchanged. Only one `ImageBytes`
/// exists per build (native vs web), so scene source never branches.
public struct ImageBytes {
    public let width: Int
    public let height: Int
    /// Tightly-packed RGBA8 pixels (no row padding), top-left origin.
    public let rgba: [UInt8]

    /// Wraps tightly-packed RGBA8 pixels from a `Data` blob — matches the native
    /// signature so generated-image scene code is identical across platforms.
    public init(width: Int, height: Int, pixels: Data) {
        self.width = width
        self.height = height
        self.rgba = [UInt8](pixels)
    }

    /// Wraps tightly-packed RGBA8 pixels already in array form.
    public init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = width
        self.height = height
        self.rgba = rgba
    }

    /// The `width`×`height` sub-rectangle whose top-left is (`x`, `y`) — slices a
    /// sheet into its cells, mirroring the native `ImageBytes.subImage`.
    func subImage(x: Int, y: Int, width w: Int, height h: Int) -> ImageBytes {
        let dstStride = w * 4
        var out = [UInt8](repeating: 0, count: dstStride * h)
        out.withUnsafeMutableBufferPointer { dst in
            rgba.withUnsafeBufferPointer { src in
                for row in 0..<h {
                    let srcOff = ((y + row) * width + x) * 4
                    let dstOff = row * dstStride
                    for i in 0..<dstStride { dst[dstOff + i] = src[srcOff + i] }
                }
            }
        }
        return ImageBytes(width: w, height: h, rgba: out)
    }

    var loadedImage: LoadedImage { LoadedImage(width: width, height: height, rgba: rgba) }
}

extension WebRenderer {
    /// The active web renderer, installed by `App.create` as the ambient through
    /// which `Sprite(path:)` resolves images — the web analogue of the native
    /// `Renderer.current`. (Native keeps this static in `Renderer`; web keeps it
    /// here since `WebRenderer` is a distinct type.)
    public static var current: WebRenderer? {
        get { _current }
        set { _current = newValue }
    }

    /// Loads (and path-caches via `makeSprite(path:from:)`) a one-frame sprite from
    /// a *prefetched* image. The image must already be resident in the renderer's
    /// `AssetLoader` cache; the web bootstrap prefetches every sprite path before
    /// scenes are built. Throws if it isn't resident.
    public func sprite(path: String) throws -> Sprite {
        guard let loaded = assetLoader?.image(path) else {
            throw SpriteError(message: "image not prefetched: \(path)")
        }
        let web = makeSprite(path: path, from: loaded)
        return Sprite(frames: [web], frameDuration: 0)
    }

    /// Loads (and slices) an animated sheet from a *prefetched* image into
    /// `frameWidth`×`frameHeight` cells, played as one looping animation at `fps`.
    public func sprite(sheet path: String, frameWidth: Int, frameHeight: Int, fps: Double = 10) throws -> Sprite {
        guard let loaded = assetLoader?.image(path) else {
            throw SpriteError(message: "sheet image not prefetched: \(path)")
        }
        return makeSprite(sheet: ImageBytes(width: loaded.width, height: loaded.height, rgba: loaded.rgba),
                          frameWidth: frameWidth, frameHeight: frameHeight, fps: fps)
    }

    /// Builds a one-frame sprite straight from in-memory pixels (no path dedup) —
    /// the web twin of native `Renderer.makeSprite(image:)`.
    public func makeSprite(image: ImageBytes) -> Sprite {
        let web = makeSprite(from: image.loadedImage)
        return Sprite(frames: [web], frameDuration: 0)
    }

    /// Builds an animated sprite by slicing an in-memory sheet row-major into
    /// `frameWidth`×`frameHeight` cells, each uploaded as its own web texture and
    /// played as one looping animation at `fps`. The web twin of native
    /// `Renderer.makeSprite(sheet:frameWidth:frameHeight:fps:)`; supports
    /// `SpritesScene`'s procedural colour-sheet path.
    public func makeSprite(sheet image: ImageBytes, frameWidth: Int, frameHeight: Int, fps: Double = 10) -> Sprite {
        let cols = image.width / frameWidth
        let rows = image.height / frameHeight
        let duration = fps > 0 ? 1.0 / fps : 0
        var webFrames: [WebSprite] = []
        webFrames.reserveCapacity(cols * rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let cell = image.subImage(x: col * frameWidth, y: row * frameHeight,
                                          width: frameWidth, height: frameHeight)
                webFrames.append(makeSprite(from: cell.loadedImage))
            }
        }
        return Sprite(frames: webFrames, frameDuration: duration)
    }
}

extension Draw {
    /// Queues a web `Sprite` drawn at `at` (top-left) in world space, applying the
    /// sprite's own `scale`/`opacity` and the current transform + colour tint. The
    /// scale mode resolves most-specific-first: the `scaleMode:` argument, then the
    /// sprite's own `scaleMode`, then the ambient `pushScaleMode` state — matching
    /// the native `Draw.sprite(_:at:scaleMode:)`.
    public func sprite(_ s: Sprite, at: SIMD2<Float> = .zero, scaleMode: ScaleMode? = nil) {
        let mode = scaleMode ?? s.scaleMode
        let cur = s.currentSprite
        // Fold the sprite's pivot into the top-left, then defer scale to the
        // texture-token quad helper (which multiplies native pixel size by scale).
        sprite(cur, at: SIMD2(at.x - s.pivot.x, at.y - s.pivot.y),
               scale: s.scale, scaleMode: mode)
    }
}
#endif
