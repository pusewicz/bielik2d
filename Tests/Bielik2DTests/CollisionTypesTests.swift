import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func rayNormalizesDirection() {
    let r = Ray(origin: SIMD2(0, 0), direction: SIMD2(3, 4), length: 10)
    #expect(abs(simd_length(r.direction) - 1) < 1e-5)
    #expect(abs(r.direction.x - 0.6) < 1e-5)
    #expect(abs(r.direction.y - 0.8) < 1e-5)
    #expect(r.length == 10)
}

@Test func aabbBridgesToAndFromRect() {
    let box = AABB(Rect(x: 1, y: 2, width: 4, height: 6))
    #expect(box.min == SIMD2(1, 2))
    #expect(box.max == SIMD2(5, 8))
    let back = box.rect
    #expect(back == Rect(x: 1, y: 2, width: 4, height: 6))
}

@Test func aabbContainsPoint() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    #expect(box.contains(SIMD2(1, 1)))
    #expect(box.contains(SIMD2(0, 0)))    // boundary counts
    #expect(!box.contains(SIMD2(3, 1)))
}
