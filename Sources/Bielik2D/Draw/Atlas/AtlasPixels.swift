#if canImport(CSDL3)
import Foundation

extension ImageBytes {
    /// Returns a copy with a `pad`-texel fully-transparent border on every side.
    /// The `SpriteBatch` bakes this gutter in before packing so that linear
    /// filtering at a sprite's edge can never pull in a neighbour's texels — a
    /// belt-and-suspenders pairing with the shader's half-texel UV clamp.
    func padded(by pad: Int) -> ImageBytes {
        guard pad > 0 else { return self }
        let outW = width + pad * 2
        let outH = height + pad * 2
        var out = Data(count: outW * outH * 4)  // zero-filled = transparent
        out.withUnsafeMutableBytes { dstRaw in
            let dst = dstRaw.bindMemory(to: UInt8.self).baseAddress!
            pixels.withUnsafeBytes { srcRaw in
                let src = srcRaw.bindMemory(to: UInt8.self).baseAddress!
                for row in 0..<height {
                    let srcOff = row * width * 4
                    let dstOff = ((row + pad) * outW + pad) * 4
                    memcpy(dst + dstOff, src + srcOff, width * 4)
                }
            }
        }
        return ImageBytes(width: outW, height: outH, pixels: out)
    }
}
#endif
