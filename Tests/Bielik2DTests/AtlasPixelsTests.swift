import Foundation
import Testing
@testable import Bielik2D

@Test func paddingAddsATransparentBorderAroundTheImage() {
    // 2×1 image: red, then green.
    let src = ImageBytes(width: 2, height: 1, pixels: Data([
        255, 0, 0, 255, /**/ 0, 255, 0, 255,
    ]))

    let out = src.padded(by: 1)

    #expect(out.width == 4)
    #expect(out.height == 3)
    let px = [UInt8](out.pixels)
    #expect(px.count == 4 * 3 * 4)

    func texel(_ x: Int, _ y: Int) -> [UInt8] {
        let o = (y * out.width + x) * 4
        return Array(px[o..<o + 4])
    }
    // The original pixels land at (1,1) and (2,1).
    #expect(texel(1, 1) == [255, 0, 0, 255])
    #expect(texel(2, 1) == [0, 255, 0, 255])
    // Every border texel is fully transparent.
    #expect(texel(0, 0) == [0, 0, 0, 0])
    #expect(texel(3, 1) == [0, 0, 0, 0])
    #expect(texel(1, 0) == [0, 0, 0, 0])
    #expect(texel(1, 2) == [0, 0, 0, 0])
}

@Test func paddingByZeroReturnsTheImageUnchanged() {
    let src = ImageBytes(width: 1, height: 1, pixels: Data([1, 2, 3, 4]))
    let out = src.padded(by: 0)
    #expect(out.width == 1)
    #expect(out.height == 1)
    #expect([UInt8](out.pixels) == [1, 2, 3, 4])
}

@Test func subImageExtractsARectangle() {
    // 3×2 image; encode each pixel's (x + 10*y) in the red channel.
    var px = [UInt8]()
    for y in 0..<2 { for x in 0..<3 { px += [UInt8(x + 10 * y), 0, 0, 255] } }
    let src = ImageBytes(width: 3, height: 2, pixels: Data(px))

    let out = src.subImage(x: 1, y: 0, width: 2, height: 2)

    #expect(out.width == 2)
    #expect(out.height == 2)
    let o = [UInt8](out.pixels)
    func red(_ x: Int, _ y: Int) -> UInt8 { o[(y * 2 + x) * 4] }
    #expect(red(0, 0) == 1)    // src (1,0)
    #expect(red(1, 0) == 2)    // src (2,0)
    #expect(red(0, 1) == 11)   // src (1,1)
    #expect(red(1, 1) == 12)   // src (2,1)
}
