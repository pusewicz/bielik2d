#if canImport(CSDL3)
import CSDL3

/// A music track — a `MIX_Audio` loaded for streaming rather than predecoded, so
/// long tracks don't sit fully decoded in memory. Create with
/// `Audio.makeMusic(path:)`/`(bytes:)`; play with `Audio.playMusic`/`crossfade`.
public final class Music {
    let handle: OpaquePointer  // MIX_Audio*

    init(handle: OpaquePointer) { self.handle = handle }

    /// Load through the ambient `Audio.current` (installed by `App`). Throws if no
    /// app has installed an audio mixer.
    public convenience init(path: String) throws {
        guard let audio = Audio.current else {
            throw AudioError.loadFailed("no ambient Audio installed")
        }
        self.init(handle: try Audio.loadHandle(mixer: audio.mixer, path: path, predecode: false))
    }

    deinit { MIX_DestroyAudio(handle) }
}
#endif
