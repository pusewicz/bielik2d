import Bielik2D
import Foundation

/// A procedurally-generated decaying blip with dynamic pitch and stereo pan — no asset file.
final class AudioScene: Scene {
    let name = "Audio"
    let summary = "A procedural blip with dynamic pitch and stereo pan over SDL3_mixer"
    let controls = "space: fire blip   ·   mouse x: pan   ·   pitch: random"

    private let blip: Sound?

    init(app: App) throws { blip = try app.audio?.makeSound(bytes: AudioScene.blipWav()) }

    func update(_ ctx: SceneContext) {
        if ctx.app.input.keyboard.pressed(.space), let blip {
            let pan = ctx.app.input.mouse.position.x / ctx.windowSize.x * 2 - 1
            blip.play(pan: pan, pitch: Float.random(in: 0.8...1.4))
        }
        let cx = ctx.stage.x + ctx.stage.width / 2
        let cy = ctx.stage.y + ctx.stage.height / 2
        ctx.draw.circle(center: SIMD2(cx, cy), radius: 64, thickness: 6, color: Color(r: 0.6, g: 0.9, b: 1.0))
        ctx.draw.text("press space to fire", font: ctx.font, at: SIMD2(cx - 110, cy + 96), color: .white)
    }

    /// A 0.12s 660Hz sine that decays exponentially, as a mono 16-bit WAV in memory.
    static func blipWav() -> Data {
        let sampleRate = 48_000
        let frames = sampleRate * 12 / 100
        var bytes = [UInt8]()
        func u32(_ v: Int) { let x = UInt32(v); bytes += [UInt8(x & 0xff), UInt8((x >> 8) & 0xff), UInt8((x >> 16) & 0xff), UInt8((x >> 24) & 0xff)] }
        func u16(_ v: Int) { let x = UInt16(v); bytes += [UInt8(x & 0xff), UInt8((x >> 8) & 0xff)] }
        func ascii(_ s: String) { bytes += Array(s.utf8) }
        let dataSize = frames * 2
        ascii("RIFF"); u32(36 + dataSize); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        ascii("data"); u32(dataSize)
        for i in 0..<frames {
            let tt = Double(i) / Double(sampleRate)
            let s = sin(2 * .pi * 660 * tt) * exp(-tt * 18) * 0.6
            let v = UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32767))
            bytes.append(UInt8(v & 0xff)); bytes.append(UInt8((v >> 8) & 0xff))
        }
        return Data(bytes)
    }
}
