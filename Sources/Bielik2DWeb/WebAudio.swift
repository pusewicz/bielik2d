#if os(WASI)
import Foundation
import JavaScriptKit
import Bielik2D

/// Web twin of the native `AudioError`, matching the neutral surface so scene
/// code (`AudioScene`) compiles unchanged across platforms.
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

/// Web twin of the native `Audio` mixer, backed by the Web Audio API via
/// JavaScriptKit. Mirrors the neutral surface documented in
/// `Sources/Bielik2D/Audio/Audio.swift` so `AudioScene` runs unchanged.
///
/// ## Async decode behind a sync API
/// `makeSound(bytes:)` is synchronous, but `AudioContext.decodeAudioData` is
/// async. A `Sound` therefore keeps its raw bytes and kicks off a background
/// decode; the resulting `AudioBuffer` is stored on the `Sound` once ready. A
/// `play()` before decode finishes is a safe no-op (returns a dead `Voice`).
///
/// ## Autoplay policy
/// Browsers start an `AudioContext` "suspended" until a user gesture. We call
/// `context.resume()` at the start of every `play`, so the first blip after a
/// keypress/click unblocks the context (the controller should drive playback
/// from a user-input handler — e.g. `AudioScene` fires on the space key).
public final class Audio {
    /// Ambient mixer `App` installs so `Sound(path:)` / `sound.play()` resolve
    /// without an explicit handle. Last app created wins.
    nonisolated(unsafe) public static var current: Audio?

    /// The Web Audio `AudioContext`.
    let context: JSObject
    /// Master `GainNode` → destination; every voice routes through it.
    let masterGain: JSObject
    private var destroyed = false

    /// Global volume folded into every voice via the master gain node.
    public var masterVolume: Float = 1 {
        didSet { setGainValue(masterGain, masterVolume) }
    }

    /// Live voices keyed by id, so a `Voice` struct can reach its source/nodes.
    private final class VoiceBox {
        let source: JSObject
        let panner: JSObject
        let gain: JSObject
        var volume: Float
        var pan: Float
        var pitch: Float
        var stopped = false
        init(source: JSObject, panner: JSObject, gain: JSObject, volume: Float, pan: Float, pitch: Float) {
            self.source = source
            self.panner = panner
            self.gain = gain
            self.volume = volume
            self.pan = pan
            self.pitch = pitch
        }
    }
    private var boxes: [UInt64: VoiceBox] = [:]
    private var nextID: UInt64 = 1
    private var currentMusicID: UInt64?

    // MARK: - Lifecycle

    /// Create a Web Audio context and wire a master gain node to its output.
    public init() throws {
        let ctorValue = JSObject.global.AudioContext.function != nil
            ? JSObject.global.AudioContext
            : JSObject.global.webkitAudioContext
        guard let ctor = ctorValue.function else {
            throw AudioError.initFailed("Web Audio API unavailable (no AudioContext)")
        }
        self.context = ctor.new()
        guard let gain = context.createGain?().object else {
            throw AudioError.initFailed("createGain failed")
        }
        self.masterGain = gain
        setGainValue(masterGain, 1)
        if let destination = context.destination.object {
            _ = masterGain.connect?(destination)
        }
    }

    public func destroy() {
        guard !destroyed else { return }
        destroyed = true
        for box in boxes.values { _ = box.source.stop?() }
        boxes.removeAll()
        _ = context.close?()
    }

    deinit { destroy() }

    // MARK: - Loading

    /// Fetch `path` and decode it. The neutral API is synchronous, so we hand the
    /// `Sound` an empty byte buffer and kick off the async fetch+decode; until it
    /// lands, `play()` is a no-op.
    public func makeSound(path: String) throws -> Sound {
        let sound = Sound(audio: self)
        sound.fetchAndDecode(path: path, context: context)
        return sound
    }

    public func makeSound(bytes: Data) throws -> Sound {
        let sound = Sound(audio: self)
        sound.beginDecode(bytes: bytes, context: context)
        return sound
    }

    public func makeMusic(path: String) throws -> Music {
        let music = Music(audio: self)
        music.sound.fetchAndDecode(path: path, context: context)
        return music
    }

    public func makeMusic(bytes: Data) throws -> Music {
        let music = Music(audio: self)
        music.sound.beginDecode(bytes: bytes, context: context)
        return music
    }

    // MARK: - Playback

    /// Play a sound effect. `loops`: 0 plays once, anything else loops forever
    /// (Web Audio `loop` is a boolean — there's no finite-repeat count).
    @discardableResult
    public func play(_ sound: Sound, volume: Float = 1, pan: Float = 0, pitch: Float = 1, loops: Int = 0) -> Voice {
        playBuffer(buffer: sound.buffer, owner: sound, volume: volume, pan: pan, pitch: pitch, loops: loops, fadeIn: 0)
    }

    /// Start a music track (looping by default), optionally fading in.
    @discardableResult
    public func playMusic(_ music: Music, volume: Float = 1, loops: Int = -1, fadeIn: Double = 0) -> Voice {
        let voice = playBuffer(buffer: music.sound.buffer, owner: music, volume: volume, pan: 0, pitch: 1, loops: loops, fadeIn: fadeIn)
        currentMusicID = voice.id
        return voice
    }

    /// Crossfade from the current music to `music`: the outgoing voice fades out
    /// while the incoming one fades in, overlapping for a true crossfade.
    @discardableResult
    public func crossfade(to music: Music, over seconds: Double, volume: Float = 1, loops: Int = -1) -> Voice {
        if let current = currentMusicID { stopVoice(current, fadeOut: seconds) }
        return playMusic(music, volume: volume, loops: loops, fadeIn: seconds)
    }

    private func playBuffer(buffer: JSObject?, owner: AnyObject, volume: Float, pan: Float, pitch: Float, loops: Int, fadeIn: Double) -> Voice {
        let id = nextID
        nextID += 1

        // Unblock the context on first user gesture (browser autoplay policy).
        _ = context.resume?()

        // Decode not finished (or failed) yet — hand back a dead voice; the
        // caller's blip is a fire-and-forget effect, so dropping it is fine.
        guard let buffer else { return Voice(id: id, audio: self) }

        guard let source = context.createBufferSource?().object,
              let panner = context.createStereoPanner?().object,
              let gain = context.createGain?().object else {
            return Voice(id: id, audio: self)
        }

        source.buffer = .object(buffer)
        source.loop = .boolean(loops != 0)
        setAudioParam(source.playbackRate.object, AudioMath.clampPitch(pitch))
        setAudioParam(panner.pan.object, AudioMath.clampPan(pan))

        let target = AudioMath.effectiveGain(volume: volume, master: 1)
        if fadeIn > 0, let g = gain.gain.object {
            // Ramp from silence up to the target over `fadeIn` seconds.
            let now = context.currentTime.number ?? 0
            _ = g.setValueAtTime?(0, now)
            _ = g.linearRampToValueAtTime?(Double(target), now + fadeIn)
        } else {
            setGainValue(gain, target)
        }

        _ = source.connect?(panner)
        _ = panner.connect?(gain)
        _ = gain.connect?(masterGain)
        _ = source.start?()

        boxes[id] = VoiceBox(source: source, panner: panner, gain: gain, volume: volume, pan: pan, pitch: pitch)
        if id == currentMusicID { currentMusicID = id }
        return Voice(id: id, audio: self)
    }

    /// No-op on web — voices are reclaimed lazily as they're touched. Kept to
    /// match the neutral surface (`App.update()` calls it each frame).
    public func update() {}

    /// Number of live voices — diagnostics.
    var activeCount: Int { boxes.count }

    // MARK: - Voice backing

    func isVoicePlaying(_ id: UInt64) -> Bool {
        guard let box = boxes[id] else { return false }
        return !box.stopped
    }

    func voiceVolume(_ id: UInt64) -> Float { boxes[id]?.volume ?? 0 }
    func voicePan(_ id: UInt64) -> Float { boxes[id]?.pan ?? 0 }
    func voicePitch(_ id: UInt64) -> Float { boxes[id]?.pitch ?? 1 }

    func setVoiceVolume(_ id: UInt64, _ value: Float) {
        guard let box = boxes[id] else { return }
        box.volume = value
        setGainValue(box.gain, AudioMath.effectiveGain(volume: value, master: 1))
    }

    func setVoicePan(_ id: UInt64, _ value: Float) {
        guard let box = boxes[id] else { return }
        box.pan = value
        setAudioParam(box.panner.pan.object, AudioMath.clampPan(value))
    }

    func setVoicePitch(_ id: UInt64, _ value: Float) {
        guard let box = boxes[id] else { return }
        box.pitch = value
        setAudioParam(box.source.playbackRate.object, AudioMath.clampPitch(value))
    }

    func stopVoice(_ id: UInt64, fadeOut: Double) {
        guard let box = boxes[id], !box.stopped else { return }
        if fadeOut > 0, let g = box.gain.gain.object {
            let now = context.currentTime.number ?? 0
            _ = g.linearRampToValueAtTime?(0, now + fadeOut)
            _ = box.source.stop?(now + fadeOut)
        } else {
            _ = box.source.stop?()
        }
        box.stopped = true
        boxes[id] = nil
        if id == currentMusicID { currentMusicID = nil }
    }

    // MARK: - Helpers

    /// Set an `AudioParam.value` directly (panner pan, source playbackRate).
    private func setAudioParam(_ param: JSObject?, _ value: Float) {
        guard let param else { return }
        param.value = .number(Double(value))
    }

    /// Set a `GainNode`'s gain value.
    private func setGainValue(_ node: JSObject, _ value: Float) {
        guard let gainParam = node.gain.object else { return }
        gainParam.value = .number(Double(value))
    }
}

/// Web twin of `Sound`: holds an async-decoded `AudioBuffer`. `buffer` is nil
/// until `decodeAudioData` resolves; a `play()` before then is a safe no-op.
///
/// Decode runs through promise callbacks (`JSPromise.then`) rather than Swift
/// `async`/`await`, matching the rest of the web module's single-threaded RAF
/// style and sidestepping `Sendable`/`sending` checks on non-`Sendable` JS
/// objects. `JSPromise.then` retains its own `JSClosure` until the promise
/// settles, so nothing extra needs to be held alive here.
public final class Sound {
    weak var audio: Audio?
    /// Set once `decodeAudioData` resolves. Read by `Audio.play`.
    var buffer: JSObject?

    init(audio: Audio?) { self.audio = audio }

    /// Load through the ambient `Audio.current`, mirroring native `Sound(path:)`.
    public convenience init(path: String) throws {
        guard let audio = Audio.current else {
            throw AudioError.loadFailed("no ambient Audio installed")
        }
        self.init(audio: audio)
        fetchAndDecode(path: path, context: audio.context)
    }

    /// Kick off `decodeAudioData` over `bytes`, storing the result when ready.
    func beginDecode(bytes: Data, context: JSObject) {
        // `decodeAudioData` detaches the buffer it's given, so hand it the
        // typed array's own backing `ArrayBuffer`.
        let typed = JSTypedArray<UInt8>([UInt8](bytes))
        decode(arrayBuffer: typed.jsObject.buffer, context: context)
    }

    /// Fetch `path`, then decode the response body (for the path-based loaders).
    func fetchAndDecode(path: String, context: JSObject) {
        guard let fetchFn = JSObject.global.fetch.function,
              let promiseObj = fetchFn(path).object,
              let promise = JSPromise(promiseObj) else { return }
        _ = promise.then(success: { [weak self] value in
            guard let self,
                  let response = value.object,
                  (response["ok"].boolean ?? false),
                  let bufPromiseObj = response.arrayBuffer?().object,
                  let bufPromise = JSPromise(bufPromiseObj) else { return .undefined }
            _ = bufPromise.then(success: { [weak self] arrayBuf in
                self?.decode(arrayBuffer: arrayBuf, context: context)
                return .undefined
            })
            return .undefined
        })
    }

    /// Run `context.decodeAudioData(arrayBuffer)` and stash the resolved buffer.
    private func decode(arrayBuffer: JSValue, context: JSObject) {
        guard let decodeFn = context.decodeAudioData.function,
              let promiseObj = decodeFn(this: context, arrayBuffer).object,
              let promise = JSPromise(promiseObj) else { return }
        _ = promise.then(success: { [weak self] value in
            if let buf = value.object { self?.buffer = buf }
            return .undefined
        })
    }
}

extension Sound {
    /// Play through the ambient `Audio.current`. Returns nil if none installed.
    @discardableResult
    public func play(volume: Float = 1, pan: Float = 0, pitch: Float = 1, loops: Int = 0) -> Voice? {
        Audio.current?.play(self, volume: volume, pan: pan, pitch: pitch, loops: loops)
    }
}

/// Web twin of `Music`: a `Sound`-like looping buffer. `AudioScene` and the demo
/// don't use music, so this is the minimal compiling/playing/looping form.
public final class Music {
    let sound: Sound

    init(audio: Audio?) { self.sound = Sound(audio: audio) }

    /// Load through the ambient `Audio.current`. Throws if none installed.
    public convenience init(path: String) throws {
        guard let audio = Audio.current else {
            throw AudioError.loadFailed("no ambient Audio installed")
        }
        self.init(audio: audio)
        sound.fetchAndDecode(path: path, context: audio.context)
    }
}

/// Web twin of `Voice`: a handle to a playing sound. Mirrors the native struct's
/// surface so scene code stays identical.
public struct Voice {
    let id: UInt64
    weak var audio: Audio?

    public var isPlaying: Bool { audio?.isVoicePlaying(id) ?? false }

    public var volume: Float {
        get { audio?.voiceVolume(id) ?? 0 }
        nonmutating set { audio?.setVoiceVolume(id, newValue) }
    }

    public var pan: Float {
        get { audio?.voicePan(id) ?? 0 }
        nonmutating set { audio?.setVoicePan(id, newValue) }
    }

    public var pitch: Float {
        get { audio?.voicePitch(id) ?? 1 }
        nonmutating set { audio?.setVoicePitch(id, newValue) }
    }

    public func stop(fadeOut: Double = 0) { audio?.stopVoice(id, fadeOut: fadeOut) }
}
#endif
