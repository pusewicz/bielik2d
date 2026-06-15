import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

private let squareA = Polygon(vertices: [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2)])

@Test func polyPolyOverlapAndManifold() {
    let b = Polygon(vertices: [SIMD2(1, 0), SIMD2(3, 0), SIMD2(3, 2), SIMD2(1, 2)])  // overlap x = 1
    #expect(squareA.overlaps(b))
    let m = squareA.manifold(with: b)
    #expect(m != nil)
    #expect(abs(m!.depth - 1) < 1e-3)
    #expect(abs(m!.normal.x - 1) < 1e-3)        // self(A) -> other(B), +x
    #expect(abs(m!.normal.y) < 1e-3)
}

@Test func polyPolyDisjoint() {
    let b = Polygon(vertices: [SIMD2(5, 5), SIMD2(7, 5), SIMD2(7, 7), SIMD2(5, 7)])
    #expect(!squareA.overlaps(b))
    #expect(squareA.manifold(with: b) == nil)
}

@Test func polyPolyMinimumAxisMatchesAABB() {
    // Same geometry as the closed-form aabbAABBManifoldPicksMinimumAxis test.
    let b = Polygon(vertices: [SIMD2(1.5, 0.5), SIMD2(3.5, 0.5), SIMD2(3.5, 2.5), SIMD2(1.5, 2.5)])
    let m = squareA.manifold(with: b)!
    #expect(abs(m.depth - 0.5) < 1e-3)
    #expect(abs(m.normal.x - 1) < 1e-3)
}

private let triangle = Polygon(vertices: [SIMD2(0, 0), SIMD2(4, 0), SIMD2(0, 4)])

@Test func polyCircleMarginOverlap() {
    // Circle core 1 unit left of the triangle's left edge (x=0), radius 1.5 -> overlap 0.5.
    let c = Circle(center: SIMD2(-1, 2), radius: 1.5)
    #expect(triangle.overlaps(c))
    let m = triangle.manifold(with: c)!
    #expect(abs(m.depth - 0.5) < 1e-3)
    #expect(abs(m.normal.x + 1) < 1e-3)         // self(triangle) -> other(circle), -x
    #expect(abs(m.normal.y) < 1e-3)
}

@Test func polyCircleDisjoint() {
    let c = Circle(center: SIMD2(-3, 2), radius: 1.5)   // core dist 3 > radius
    #expect(!triangle.overlaps(c))
    #expect(triangle.manifold(with: c) == nil)
}

@Test func circlePolyReverseNegatesNormal() {
    let c = Circle(center: SIMD2(-1, 2), radius: 1.5)
    let fwd = triangle.manifold(with: c)!
    let rev = c.manifold(with: triangle)!
    #expect(abs(rev.normal.x - 1) < 1e-3)        // negated: circle -> triangle, +x
    #expect(abs(fwd.depth - rev.depth) < 1e-3)
    #expect(c.overlaps(triangle) == triangle.overlaps(c))
}
