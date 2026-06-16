#if canImport(CSDL3)
import CSDL3
import Foundation

/// The audio mixer: opens an output device, loads sounds, and plays them on
/// tracks. Reached via `app.audio`. Built on SDL3_mixer's track API, so volume,
/// pan, pitch, and fades are native.
///
/// Tracks are created per `play` and reclaimed by `update()` once they finish, so
/// the app loop must call `update()` each frame (`App.update()` does this).
///
/// ## Platform-neutral surface
/// This SDL3_mixer implementation is the native (`#if canImport(CSDL3)`) half of a
/// twin type; a web (`#if os(WASI)`) twin must mirror the same public API so scene
/// code stays identical across platforms. The neutral contract is, exactly:
/// - `init() throws` — open the default playback device.
/// - `static var current: Audio?` — ambient mixer `App` installs.
/// - `var masterVolume: Float` — global volume folded into every track.
/// - `func makeSound(path: String) throws -> Sound`
/// - `func makeSound(bytes: Data) throws -> Sound`
/// - `func makeMusic(path: String) throws -> Music`
/// - `func makeMusic(bytes: Data) throws -> Music`
/// - `@discardableResult func play(_ sound: Sound, volume: Float = 1, pan: Float = 0,
///   pitch: Float = 1, loops: Int = 0) -> Voice`
/// - `@discardableResult func playMusic(_ music: Music, volume: Float = 1,
///   loops: Int = -1, fadeIn: Double = 0) -> Voice`
/// - `@discardableResult func crossfade(to music: Music, over seconds: Double,
///   volume: Float = 1, loops: Int = -1) -> Voice`
/// - `func update()` — reclaim finished tracks; call once per frame.
/// - `func destroy()`
///
/// Plus the companion neutral types `Sound`, `Music`, `Voice`, and `AudioError`,
/// and the ambient overloads `Sound(path:)` / `sound.play(...)` and
/// `Music(path:)`. Backing storage (the `MIX_*` opaque pointers, `mixer`,
/// `Sound.handle`) is `internal` and is not part of the neutral surface — the web
/// twin substitutes its own.
public final class Audio {
    /// The ambient mixer `App` installs so `Sound(path:)` and `sound.play()`
    /// resolve without an explicit handle. Last app created wins.
    nonisolated(unsafe) public static var current: Audio?

    let mixer: OpaquePointer  // MIX_Mixer*
    private var destroyed = false

    /// Global volume folded into every track's gain (SDL_mixer has no master).
    public var masterVolume: Float = 1 {
        didSet { for id in boxes.keys { applyGain(id) } }
    }

    private final class TrackBox {
        let track: OpaquePointer  // MIX_Track*
        let owner: AnyObject  // the Sound/Music, retained so its data outlives playback
        var volume: Float
        var pan: Float
        var pitch: Float
        init(track: OpaquePointer, owner: AnyObject, volume: Float, pan: Float, pitch: Float) {
            self.track = track
            self.owner = owner
            self.volume = volume
            self.pan = pan
            self.pitch = pitch
        }
    }
    private var boxes: [UInt64: TrackBox] = [:]
    private var nextID: UInt64 = 1
    private var currentMusicID: UInt64?

    // MARK: - Lifecycle

    private init(mixer: OpaquePointer) { self.mixer = mixer }

    /// Open the default playback device.
    public convenience init() throws {
        guard MIX_Init() else { throw AudioError.initFailed(lastSDLError()) }
        guard let mixer = MIX_CreateMixerDevice(SDL_AudioDeviceID(0xFFFF_FFFF), nil) else {
            MIX_Quit()
            throw AudioError.initFailed(lastSDLError())
        }
        self.init(mixer: mixer)
    }

    /// A mixer that renders to memory instead of a device — for tests and offline
    /// rendering. Pull samples with `render(frameCount:)`.
    static func memory() throws -> Audio {
        guard MIX_Init() else { throw AudioError.initFailed(lastSDLError()) }
        var spec = SDL_AudioSpec(format: SDL_AUDIO_F32, channels: 2, freq: 48000)
        guard let mixer = MIX_CreateMixer(&spec) else {
            MIX_Quit()
            throw AudioError.initFailed(lastSDLError())
        }
        return Audio(mixer: mixer)
    }

    public func destroy() {
        guard !destroyed else { return }
        destroyed = true
        for box in boxes.values { MIX_DestroyTrack(box.track) }
        boxes.removeAll()
        MIX_DestroyMixer(mixer)
        MIX_Quit()
    }

    deinit { destroy() }

    // MARK: - Loading

    public func makeSound(path: String) throws -> Sound {
        Sound(handle: try Audio.loadHandle(mixer: mixer, path: path, predecode: true))
    }

    /// Shared path loader for `makeSound`/`makeMusic` and the ambient `Sound(path:)`.
    static func loadHandle(mixer: OpaquePointer, path: String, predecode: Bool) throws -> OpaquePointer {
        guard let handle = MIX_LoadAudio(mixer, path, predecode) else {
            throw AudioError.loadFailed(lastSDLError())
        }
        return handle
    }

    public func makeSound(bytes: Data) throws -> Sound {
        // predecode reads the whole stream during this call, so the borrowed
        // pointer only needs to be valid for the duration of withUnsafeBytes.
        let handle: OpaquePointer? = bytes.withUnsafeBytes { raw in
            guard let io = SDL_IOFromConstMem(raw.baseAddress, raw.count) else { return nil }
            return MIX_LoadAudio_IO(mixer, io, true, true)
        }
        guard let handle else { throw AudioError.loadFailed(lastSDLError()) }
        return Sound(handle: handle)
    }

    // MARK: - Playback

    /// Play a sound effect, returning a `Voice` to control it. `loops`: 0 plays
    /// once, -1 loops forever, n repeats n extra times.
    @discardableResult
    public func play(_ sound: Sound, volume: Float = 1, pan: Float = 0, pitch: Float = 1, loops: Int = 0) -> Voice {
        playClip(handle: sound.handle, owner: sound, volume: volume, pan: pan, pitch: pitch, loops: loops, fadeIn: 0)
    }

    /// Start a music track (looping forever by default), optionally fading in over
    /// `fadeIn` seconds. Becomes the current track for `crossfade(to:over:)`.
    @discardableResult
    public func playMusic(_ music: Music, volume: Float = 1, loops: Int = -1, fadeIn: Double = 0) -> Voice {
        let voice = playClip(handle: music.handle, owner: music, volume: volume, pan: 0, pitch: 1, loops: loops, fadeIn: fadeIn)
        currentMusicID = voice.id
        return voice
    }

    /// Crossfade from the current music to `music` over `seconds`: the outgoing
    /// track fades out while the incoming one fades in, overlapping for a true
    /// crossfade. Returns the incoming `Voice`.
    @discardableResult
    public func crossfade(to music: Music, over seconds: Double, volume: Float = 1, loops: Int = -1) -> Voice {
        if let current = currentMusicID { stopVoice(current, fadeOut: seconds) }
        return playMusic(music, volume: volume, loops: loops, fadeIn: seconds)
    }

    private func playClip(handle: OpaquePointer, owner: AnyObject, volume: Float, pan: Float, pitch: Float, loops: Int, fadeIn: Double) -> Voice {
        let id = nextID
        nextID += 1
        guard let track = MIX_CreateTrack(mixer) else { return Voice(id: id, audio: self) }
        MIX_SetTrackAudio(track, handle)
        boxes[id] = TrackBox(track: track, owner: owner, volume: volume, pan: pan, pitch: pitch)
        applyGain(id)
        applyPan(id)
        applyPitch(id)

        var options: SDL_PropertiesID = 0
        if loops != 0 || fadeIn > 0 {
            options = SDL_CreateProperties()
            if loops != 0 {
                SDL_SetNumberProperty(options, MIX_PROP_PLAY_LOOPS_NUMBER, Sint64(loops))
            }
            if fadeIn > 0 {
                let frames = MIX_TrackMSToFrames(track, Sint64(fadeIn * 1000))
                SDL_SetNumberProperty(options, MIX_PROP_PLAY_FADE_IN_FRAMES_NUMBER, frames)
            }
        }
        MIX_PlayTrack(track, options)
        if options != 0 { SDL_DestroyProperties(options) }
        return Voice(id: id, audio: self)
    }

    public func makeMusic(path: String) throws -> Music {
        Music(handle: try Audio.loadHandle(mixer: mixer, path: path, predecode: false))
    }

    public func makeMusic(bytes: Data) throws -> Music {
        // Predecode here: the borrowed pointer can't outlive this call, so we
        // can't let the stream read it lazily later (unlike the path variant).
        let handle: OpaquePointer? = bytes.withUnsafeBytes { raw in
            guard let io = SDL_IOFromConstMem(raw.baseAddress, raw.count) else { return nil }
            return MIX_LoadAudio_IO(mixer, io, true, true)
        }
        guard let handle else { throw AudioError.loadFailed(lastSDLError()) }
        return Music(handle: handle)
    }

    /// Reclaim tracks whose sounds have finished. Call once per frame.
    public func update() {
        for (id, box) in boxes where !MIX_TrackPlaying(box.track) {
            MIX_DestroyTrack(box.track)
            boxes[id] = nil
            if id == currentMusicID { currentMusicID = nil }
        }
    }

    /// Number of live tracks — diagnostics/tests.
    var activeCount: Int { boxes.count }

    // MARK: - Voice backing

    func isVoicePlaying(_ id: UInt64) -> Bool {
        guard let box = boxes[id] else { return false }
        return MIX_TrackPlaying(box.track)
    }

    func voiceVolume(_ id: UInt64) -> Float { boxes[id]?.volume ?? 0 }
    func voicePan(_ id: UInt64) -> Float { boxes[id]?.pan ?? 0 }
    func voicePitch(_ id: UInt64) -> Float { boxes[id]?.pitch ?? 1 }

    func setVoiceVolume(_ id: UInt64, _ value: Float) {
        boxes[id]?.volume = value
        applyGain(id)
    }
    func setVoicePan(_ id: UInt64, _ value: Float) {
        boxes[id]?.pan = value
        applyPan(id)
    }
    func setVoicePitch(_ id: UInt64, _ value: Float) {
        boxes[id]?.pitch = value
        applyPitch(id)
    }

    func stopVoice(_ id: UInt64, fadeOut: Double) {
        guard let box = boxes[id] else { return }
        let frames = fadeOut > 0 ? MIX_TrackMSToFrames(box.track, Sint64(fadeOut * 1000)) : 0
        MIX_StopTrack(box.track, frames)
    }

    // MARK: - Applying state to a track

    private func applyGain(_ id: UInt64) {
        guard let box = boxes[id] else { return }
        MIX_SetTrackGain(box.track, AudioMath.effectiveGain(volume: box.volume, master: masterVolume))
    }

    private func applyPan(_ id: UInt64) {
        guard let box = boxes[id] else { return }
        let g = AudioMath.panGains(box.pan)
        var gains = MIX_StereoGains(left: g.left, right: g.right)
        MIX_SetTrackStereo(box.track, &gains)
    }

    private func applyPitch(_ id: UInt64) {
        guard let box = boxes[id] else { return }
        MIX_SetTrackFrequencyRatio(box.track, max(0.01, box.pitch))
    }

    // MARK: - Offline rendering (memory mixer only)

    /// Render `frameCount` stereo frames of mixed audio (memory mixer only).
    func render(frameCount: Int) -> [Float] {
        let sampleCount = frameCount * 2  // interleaved stereo
        var buffer = [Float](repeating: 0, count: sampleCount)
        let byteLength = Int32(sampleCount * MemoryLayout<Float>.size)
        buffer.withUnsafeMutableBytes { raw in
            _ = MIX_Generate(mixer, raw.baseAddress, byteLength)
        }
        return buffer
    }
}
#endif
