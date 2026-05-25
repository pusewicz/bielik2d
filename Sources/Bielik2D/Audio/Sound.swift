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

    deinit { MIX_DestroyAudio(handle) }
}
#endif
