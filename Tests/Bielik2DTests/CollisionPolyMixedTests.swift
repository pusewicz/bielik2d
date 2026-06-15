import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

private let squareP = Polygon(vertices: [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2)])
private let triangleP = Polygon(vertices: [SIMD2(0, 0), SIMD2(4, 0), SIMD2(0, 4)])

@Test func polyAABBMatchesAABBCore() {
    let box = AABB(min: SIMD2(1, 0), max: SIMD2(3, 2))   // overlap x = 1
    let m = squareP.manifold(with: box)!
    #expect(abs(m.depth - 1) < 1e-3)
    #expect(abs(m.normal.x - 1) < 1e-3)
    #expect(box.overlaps(squareP))                       // reverse delegate
    #expect(abs(box.manifold(with: squareP)!.normal.x + 1) < 1e-3)  // negated
}

@Test func polyCapsuleMargin() {
    // Capsule spine 1 unit left of the triangle's left edge (x=0), radius 1.5 -> overlap 0.5.
    let cap = Capsule(a: SIMD2(-1, 1), b: SIMD2(-1, 3), radius: 1.5)
    #expect(triangleP.overlaps(cap))
    let m = triangleP.manifold(with: cap)!
    #expect(abs(m.depth - 0.5) < 1e-3)
    #expect(abs(m.normal.x + 1) < 1e-3)                  // triangle -> capsule, -x
}

@Test func polyCapsuleDisjoint() {
    let cap = Capsule(a: SIMD2(-3, 1), b: SIMD2(-3, 3), radius: 1)  // gap 3 > radius
    #expect(!triangleP.overlaps(cap))
    #expect(triangleP.manifold(with: cap) == nil)
}
