import Foundation
import Testing
@testable import Bielik2D

/// Audio tests run on a *memory* mixer (`Audio.memory()`): no device, fully
/// headless. `render(frameCount:)` pulls mixed samples so we can assert on the
/// real output. MIX global state is process-wide, so these run serially.
@Suite(.serialized)
struct AudioTests {

    @Test func playingASoundGeneratesNonSilentAudio() throws {
        let audio = try Audio.memory()
        let sound = try audio.makeSound(bytes: toneWav())
        let voice = audio.play(sound)
        #expect(voice.isPlaying)
        let samples = audio.render(frameCount: 1024)
        #expect(samples.contains { $0 != 0 })
    }

    @Test func zeroVolumeProducesSilence() throws {
        let audio = try Audio.memory()
        let sound = try audio.makeSound(bytes: toneWav())
        _ = audio.play(sound, volume: 0)
        let samples = audio.render(frameCount: 1024)
        #expect(samples.allSatisfy { $0 == 0 })
    }

    @Test func stoppingAVoiceEndsPlayback() throws {
        let audio = try Audio.memory()
        let sound = try audio.makeSound(bytes: toneWav())
        let voice = audio.play(sound)
        #expect(voice.isPlaying)
        voice.stop()
        #expect(!voice.isPlaying)
    }

    @Test func updateReapsFinishedVoices() throws {
        let audio = try Audio.memory()
        let sound = try audio.makeSound(bytes: toneWav(seconds: 0.01))
        let voice = audio.play(sound)
        #expect(audio.activeCount == 1)
        _ = audio.render(frameCount: 8192)  // drain the short sound
        audio.update()
        #expect(!voice.isPlaying)
        #expect(audio.activeCount == 0)
    }

    @Test func panHardLeftSilencesTheRightChannel() throws {
        let audio = try Audio.memory()
        let sound = try audio.makeSound(bytes: toneWav())
        _ = audio.play(sound, pan: -1)  // hard left
        let s = audio.render(frameCount: 1024)
        var left: Float = 0, right: Float = 0
        for i in stride(from: 0, to: s.count, by: 2) {  // interleaved: even=L, odd=R
            left += abs(s[i])
            right += abs(s[i + 1])
        }
        #expect(left > 0)
        #expect(right < left * 0.001)
    }

    @Test func higherPitchFinishesSooner() throws {
        func framesUntilDone(pitch: Float) throws -> Int {
            let audio = try Audio.memory()
            let sound = try audio.makeSound(bytes: toneWav(seconds: 0.1))
            let voice = audio.play(sound, pitch: pitch)
            var frames = 0
            while voice.isPlaying && frames < 48_000 {
                _ = audio.render(frameCount: 256)
                audio.update()
                frames += 256
            }
            return frames
        }
        #expect(try framesUntilDone(pitch: 2) < framesUntilDone(pitch: 1))
    }
}

// MARK: - In-memory WAV fixture (no committed binary)

private func toneWav(seconds: Double = 0.1, freq: Double = 440, sampleRate: Int = 48000) -> Data {
    let frames = Int(Double(sampleRate) * seconds)
    var samples = [Int16]()
    samples.reserveCapacity(frames)
    for i in 0..<frames {
        let t = Double(i) / Double(sampleRate)
        samples.append(Int16(sin(2 * .pi * freq * t) * 0.5 * 32767))
    }
    return wavContainer(samples: samples, sampleRate: sampleRate)
}

private func wavContainer(samples: [Int16], sampleRate: Int, channels: Int = 1) -> Data {
    let bitsPerSample = 16
    let blockAlign = channels * bitsPerSample / 8
    let byteRate = sampleRate * blockAlign
    let dataSize = samples.count * 2
    var b = [UInt8]()
    func u32(_ v: Int) {
        let x = UInt32(v)
        b.append(contentsOf: [UInt8(x & 0xff), UInt8((x >> 8) & 0xff), UInt8((x >> 16) & 0xff), UInt8((x >> 24) & 0xff)])
    }
    func u16(_ v: Int) {
        let x = UInt16(v)
        b.append(contentsOf: [UInt8(x & 0xff), UInt8((x >> 8) & 0xff)])
    }
    func ascii(_ s: String) { b.append(contentsOf: s.utf8) }
    ascii("RIFF"); u32(36 + dataSize); ascii("WAVE")
    ascii("fmt "); u32(16); u16(1); u16(channels); u32(sampleRate); u32(byteRate); u16(blockAlign); u16(bitsPerSample)
    ascii("data"); u32(dataSize)
    for s in samples {
        let x = UInt16(bitPattern: s)
        b.append(UInt8(x & 0xff)); b.append(UInt8((x >> 8) & 0xff))
    }
    return Data(b)
}
