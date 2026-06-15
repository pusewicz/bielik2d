import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func translatesCircle() {
    let c = Circle(center: SIMD2(1, 2), radius: 3).translated(by: SIMD2(4, -1))
    #expect(c == Circle(center: SIMD2(5, 1), radius: 3))
}

@Test func translatesAABB() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2)).translated(by: SIMD2(1, 1))
    #expect(a == AABB(min: SIMD2(1, 1), max: SIMD2(3, 3)))
}

@Test func translatesCapsule() {
    let cap = Capsule(a: SIMD2(0, 0), b: SIMD2(0, 4), radius: 1).translated(by: SIMD2(2, 0))
    #expect(cap == Capsule(a: SIMD2(2, 0), b: SIMD2(2, 4), radius: 1))
}

@Test func translatesPolygon() {
    let p = Polygon(vertices: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1)]).translated(by: SIMD2(1, 1))
    #expect(p == Polygon(vertices: [SIMD2(1, 1), SIMD2(2, 1), SIMD2(1, 2)]))
}
