#if canImport(CSDL3)
import CSDL3

/// A music track — a `MIX_Audio` loaded for streaming rather than predecoded, so
/// long tracks don't sit fully decoded in memory. Create with
/// `Audio.makeMusic(path:)`/`(bytes:)`; play with `Audio.playMusic`/`crossfade`.
public final class Music {
    let handle: OpaquePointer  // MIX_Audio*

    init(handle: OpaquePointer) { self.handle = handle }

    deinit { MIX_DestroyAudio(handle) }
}
#endif
