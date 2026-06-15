import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

// Boundary y=0, outward normal +y, so the solid side is y < 0.
private let floor = Halfspace(point: SIMD2(0, 0), normal: SIMD2(0, 1))

@Test func halfspaceCircleOverlap() {
    let c = Circle(center: SIMD2(0, 0.5), radius: 1)    // dips to y=-0.5 -> overlap 0.5
    #expect(floor.overlaps(c))
    let m = floor.manifold(with: c)!
    #expect(abs(m.depth - 0.5) < 1e-4)
    #expect(abs(m.normal.y - 1) < 1e-4)                 // halfspace -> shape = +normal
    #expect(c.overlaps(floor) == floor.overlaps(c))
}

@Test func halfspaceCircleAbove() {
    let c = Circle(center: SIMD2(0, 2), radius: 1)      // lowest point y=1 > 0
    #expect(!floor.overlaps(c))
    #expect(floor.manifold(with: c) == nil)
}

@Test func circleHalfspaceReversePushesOut() {
    let c = Circle(center: SIMD2(0, 0.5), radius: 1)
    let m = c.manifold(with: floor)!
    #expect(abs(m.normal.y + 1) < 1e-4)                 // negated
    // Resolve self(circle) by -normal*depth -> moves +y, out of the solid half.
    let resolved = c.center - m.normal * m.depth
    #expect(resolved.y > c.center.y)
}

@Test func halfspaceAABBStraddles() {
    let box = AABB(min: SIMD2(-1, -1), max: SIMD2(1, 1))   // deepest corner y=-1
    #expect(floor.overlaps(box))
    #expect(abs(floor.manifold(with: box)!.depth - 1) < 1e-4)
}

@Test func halfspacePolygonOneVertexInside() {
    let tri = Polygon(vertices: [SIMD2(0, 1), SIMD2(1, 1), SIMD2(0.5, -0.5)])
    #expect(floor.overlaps(tri))
    #expect(abs(floor.manifold(with: tri)!.depth - 0.5) < 1e-4)
}

@Test func rayHitsHalfspaceBoundary() {
    let ray = Ray(origin: SIMD2(0, 3), direction: SIMD2(0, -1), length: 10)
    let hit = ray.cast(against: floor)
    #expect(hit != nil)
    #expect(abs(hit!.t - 3) < 1e-4)
    #expect(abs(hit!.point.y) < 1e-4)
    #expect(abs(hit!.normal.y - 1) < 1e-4)               // faces back up toward origin
}

@Test func rayParallelToHalfspaceMisses() {
    let ray = Ray(origin: SIMD2(0, 3), direction: SIMD2(1, 0), length: 10)
    #expect(ray.cast(against: floor) == nil)
}
