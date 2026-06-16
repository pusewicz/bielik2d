/// Pure audio math shared by the mixer-bound types, kept device-free so it can
/// be unit-tested without opening an audio device.
enum AudioMath {
    /// Linear stereo pan gains: -1 is hard left, 0 is centered (both full), +1 is
    /// hard right. The near channel stays at full; the far channel attenuates.
    static func panGains(_ pan: Float) -> (left: Float, right: Float) {
        let p = max(-1, min(1, pan))
        let left = p <= 0 ? 1 : 1 - p
        let right = p >= 0 ? 1 : 1 + p
        return (left, right)
    }

    /// A track's effective gain: its own volume scaled by the master volume, with
    /// both floored at zero so a negative value never inverts the signal.
    static func effectiveGain(volume: Float, master: Float) -> Float {
        max(0, volume) * max(0, master)
    }

    /// Smallest pitch we ever apply: web `AudioBufferSourceNode.playbackRate`
    /// must be > 0, so we floor here rather than allow zero (a stalled source).
    static let minPitch: Float = 0.0001

    /// Clamp a pan value into the neutral -1...1 range (-1 hard left, +1 hard
    /// right). Shared by both audio backends.
    static func clampPan(_ pan: Float) -> Float {
        max(-1, min(1, pan))
    }

    /// Clamp a pitch (playback-rate) value to a strictly-positive floor so it is
    /// never <= 0. Shared by both audio backends.
    static func clampPitch(_ pitch: Float) -> Float {
        max(minPitch, pitch)
    }
}
