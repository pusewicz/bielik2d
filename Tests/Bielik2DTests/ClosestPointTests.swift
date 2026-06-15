import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func closestPointOnSegmentClampsToEndpoints() {
    let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(10, 0)
    #expect(closestPointOnSegment(SIMD2(5, 3), a, b) == SIMD2(5, 0))   // perpendicular foot
    #expect(closestPointOnSegment(SIMD2(-4, 1), a, b) == SIMD2(0, 0))  // before a
    #expect(closestPointOnSegment(SIMD2(99, 1), a, b) == SIMD2(10, 0)) // past b
}

@Test func closestPointOnSegmentHandlesDegenerateSegment() {
    let a = SIMD2<Float>(2, 2)
    #expect(closestPointOnSegment(SIMD2(9, 9), a, a) == a)
}

@Test func closestPointOnAABBClamps() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(4, 4))
    #expect(closestPointOnAABB(SIMD2(2, 9), box) == SIMD2(2, 4))   // above
    #expect(closestPointOnAABB(SIMD2(-3, 2), box) == SIMD2(0, 2))  // left
    #expect(closestPointOnAABB(SIMD2(2, 2), box) == SIMD2(2, 2))   // inside -> itself
}

@Test func segmentSegmentClosestParallelOffset() {
    // Two horizontal segments offset by 2 in y; closest distance is 2.
    let (c1, c2) = segmentSegmentClosest(SIMD2(0, 0), SIMD2(10, 0),
                                         SIMD2(0, 2), SIMD2(10, 2))
    #expect(abs(simd_distance(c1, c2) - 2) < 1e-4)
}

@Test func segmentSegmentClosestCrossingIsZero() {
    let (c1, c2) = segmentSegmentClosest(SIMD2(-5, 0), SIMD2(5, 0),
                                         SIMD2(0, -5), SIMD2(0, 5))
    #expect(simd_distance(c1, c2) < 1e-4)   // they intersect at the origin
}

@Test func segmentAABBClosestOutsideAndCrossing() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    // Segment fully to the right of the box; nearest distance is 1 (x=3 vs x=2).
    let (s1, b1) = segmentAABBClosest(SIMD2(3, -5), SIMD2(3, 5), box)
    #expect(abs(simd_distance(s1, b1) - 1) < 1e-4)
    // Segment passing through the box -> distance 0.
    let (s2, b2) = segmentAABBClosest(SIMD2(-5, 1), SIMD2(5, 1), box)
    #expect(simd_distance(s2, b2) < 1e-4)
}
