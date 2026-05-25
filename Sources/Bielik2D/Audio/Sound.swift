#if canImport(CSDL3)
import CSDL3

public enum AudioError: Error, CustomStringConvertible {
    case initFailed(String)
    case loadFailed(String)

    public var description: String {
        switch self {
        case .initFailed(let m): "audio init failed: \(m)"
        case .loadFailed(let m): "audio load failed: \(m)"
        }
    }
}

/// A loaded sound effect — a fully decoded `MIX_Audio` held in memory, cheap to
/// play many times over. Create with `Audio.makeSound(path:)`/`(bytes:)`.
public final class Sound {
    let handle: OpaquePointer  // MIX_Audio*

    init(handle: OpaquePointer) { self.handle = handle }

    /// Load through the ambient `Audio.current` (installed by `App`), mirroring
    /// `Sprite(path:)`. Throws if no app has installed an audio mixer.
    public convenience init(path: String) throws {
        guard let audio = Audio.current else {
            throw AudioError.loadFailed("no ambient Audio installed")
        }
        self.init(handle: try Audio.loadHandle(mixer: audio.mixer, path: path, predecode: true))
    }

    deinit { MIX_DestroyAudio(handle) }
}

extension Sound {
    /// Play through the ambient `Audio.current`. Returns nil if no app installed one.
    @discardableResult
    public func play(volume: Float = 1, pan: Float = 0, pitch: Float = 1, loops: Int = 0) -> Voice? {
        Audio.current?.play(self, volume: volume, pan: pan, pitch: pitch, loops: loops)
    }
}
#endif
