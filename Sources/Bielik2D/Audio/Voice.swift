#if canImport(CSDL3)

/// A handle to a playing sound. Ignore it for fire-and-forget effects, or keep it
/// to adjust or stop a sound while it plays (e.g. a looping engine hum). Once the
/// sound finishes and `Audio.update()` reaps its track, queries report stopped.
public struct Voice {
    let id: UInt64
    weak var audio: Audio?

    /// True while the sound is still playing (and its track hasn't been reaped).
    public var isPlaying: Bool { audio?.isVoicePlaying(id) ?? false }

    /// Linear volume (0 = silent, 1 = unity). Scaled by `Audio.masterVolume`.
    public var volume: Float {
        get { audio?.voiceVolume(id) ?? 0 }
        nonmutating set { audio?.setVoiceVolume(id, newValue) }
    }

    /// Stereo pan: -1 hard left, 0 centered, +1 hard right.
    public var pan: Float {
        get { audio?.voicePan(id) ?? 0 }
        nonmutating set { audio?.setVoicePan(id, newValue) }
    }

    /// Playback-rate pitch (varispeed): 1 = normal, 2 = an octave up, 0.5 = down.
    public var pitch: Float {
        get { audio?.voicePitch(id) ?? 1 }
        nonmutating set { audio?.setVoicePitch(id, newValue) }
    }

    /// Stop the sound, optionally fading out over `fadeOut` seconds.
    public func stop(fadeOut: Double = 0) { audio?.stopVoice(id, fadeOut: fadeOut) }
}
#endif
