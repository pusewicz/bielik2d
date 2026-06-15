import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func polygonSupportPicksFarthestVertex() {
    let p = Polygon(vertices: [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2)])
    let s = p.support
    #expect(s.radius == 0)
    let far = s.support(SIMD2(1, 0))
    #expect(far.x == 2)                         // one of the +x corners
    #expect(simd_dot(far, SIMD2(1, 0)) == 2)
    #expect(s.support(SIMD2(-1, -1)) == SIMD2(0, 0))
}

@Test func circleSupportIsCenterWithRadius() {
    let c = Circle(center: SIMD2(5, 1), radius: 3)
    let s = c.support
    #expect(s.radius == 3)
    #expect(s.support(SIMD2(1, 0)) == SIMD2(5, 1))   // core is the centre, dir-independent
    #expect(s.support(SIMD2(-7, 2)) == SIMD2(5, 1))
}

@Test func capsuleSupportPicksFarEndpoint() {
    let cap = Capsule(a: SIMD2(0, 0), b: SIMD2(4, 0), radius: 1)
    let s = cap.support
    #expect(s.radius == 1)
    #expect(s.support(SIMD2(1, 0)) == SIMD2(4, 0))
    #expect(s.support(SIMD2(-1, 0)) == SIMD2(0, 0))
}

@Test func aabbSupportPicksCorner() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    let s = box.support
    #expect(s.radius == 0)
    #expect(s.support(SIMD2(-1, -1)) == SIMD2(0, 0))
    #expect(s.support(SIMD2(1, 1)) == SIMD2(2, 2))
    #expect(s.support(SIMD2(1, -1)) == SIMD2(2, 0))
}
