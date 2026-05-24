/// Identifies a shared sprite asset (one or more named animations of frames) inside
/// a `SpriteRegistry`. A `Sprite` is a small value that carries one of these plus its
/// own playback and draw state; the registry owns the heavy, shared data.
typealias SpriteAssetID = Int

/// How an animation walks its frames once time runs past the last one.
enum PlayMode: Sendable {
    case loop      // wrap back to the first frame
    case once      // hold on the last frame
    case pingPong  // bounce back and forth
}

/// One frame of an animation: the atlas image to draw, its pixel size, and how long
/// it stays on screen. A `duration` of 0 means "never advance" (a static frame).
struct Frame: Equatable, Sendable {
    let imageID: SpriteID
    let width: Int
    let height: Int
    let duration: Double  // seconds
}

/// Where playback currently sits within an animation: which frame, how much time has
/// accrued toward the next one, and (for ping-pong) which way it's walking.
struct AnimationCursor: Equatable, Sendable {
    var frame: Int
    var elapsed: Double
    var forward: Bool

    init(frame: Int = 0, elapsed: Double = 0, forward: Bool = true) {
        self.frame = frame
        self.elapsed = elapsed
        self.forward = forward
    }
}

/// A named sequence of frames with a play mode. Immutable and shared: many `Sprite`
/// values reference the same `Animation` and each carries its own `AnimationCursor`.
struct Animation: Equatable, Sendable {
    let name: String
    let frames: [Frame]
    let mode: PlayMode

    /// Advances `cursor` by `dt` seconds, returning the new cursor. Pure: it never
    /// mutates the animation. A single frame, or a frame with zero duration, holds.
    func advanced(_ cursor: AnimationCursor, by dt: Double) -> AnimationCursor {
        let count = frames.count
        guard count > 1 else { return cursor }

        var c = cursor
        c.elapsed += dt
        // Spend whole frames out of the accumulated time; a fat `dt` walks several.
        while frames[c.frame].duration > 0, c.elapsed >= frames[c.frame].duration {
            c.elapsed -= frames[c.frame].duration
            switch mode {
            case .loop:
                c.frame = (c.frame + 1) % count
            case .once:
                guard c.frame < count - 1 else { c.elapsed = 0; return c }  // hold on the end
                c.frame += 1
            case .pingPong:
                if c.forward, c.frame >= count - 1 { c.forward = false }
                else if !c.forward, c.frame <= 0 { c.forward = true }
                c.frame += c.forward ? 1 : -1
            }
        }
        return c
    }
}
