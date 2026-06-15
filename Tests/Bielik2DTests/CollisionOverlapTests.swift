import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func circleCircleOverlap() {
    let a = Circle(center: SIMD2(0, 0), radius: 2)
    #expect(a.overlaps(Circle(center: SIMD2(3, 0), radius: 2)))   // dist 3 < 4
    #expect(a.overlaps(Circle(center: SIMD2(4, 0), radius: 2)))   // dist 4 == 4 (touching)
    #expect(!a.overlaps(Circle(center: SIMD2(5, 0), radius: 2)))  // dist 5 > 4
}

@Test func circleAABBOverlapBothDirections() {
    let c = Circle(center: SIMD2(0, 0), radius: 1)
    let near = AABB(min: SIMD2(0.5, -1), max: SIMD2(2, 1))   // closest pt (0.5,0), dist 0.5
    let far = AABB(min: SIMD2(2, -1), max: SIMD2(4, 1))      // closest pt (2,0), dist 2
    #expect(c.overlaps(near))
    #expect(near.overlaps(c))    // reverse delegate
    #expect(!c.overlaps(far))
    #expect(!far.overlaps(c))
}

@Test func circleCapsuleOverlap() {
    let cap = Capsule(a: SIMD2(-5, 0), b: SIMD2(5, 0), radius: 1)
    #expect(Circle(center: SIMD2(0, 1.5), radius: 1).overlaps(cap))   // gap 0.5 < r sum 2
    #expect(!Circle(center: SIMD2(0, 4), radius: 1).overlaps(cap))    // gap 3 > 2
    #expect(cap.overlaps(Circle(center: SIMD2(0, 1.5), radius: 1)))   // reverse delegate
}

@Test func aabbAABBOverlap() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    #expect(a.overlaps(AABB(min: SIMD2(1, 1), max: SIMD2(3, 3))))
    #expect(!a.overlaps(AABB(min: SIMD2(3, 0), max: SIMD2(5, 2))))
}

@Test func aabbCapsuleOverlap() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    let through = Capsule(a: SIMD2(-5, 1), b: SIMD2(5, 1), radius: 0.5)   // passes through
    let near = Capsule(a: SIMD2(2.4, -5), b: SIMD2(2.4, 5), radius: 0.5)  // gap 0.4 < 0.5
    let far = Capsule(a: SIMD2(3, -5), b: SIMD2(3, 5), radius: 0.5)       // gap 1 > 0.5
    #expect(box.overlaps(through))
    #expect(box.overlaps(near))
    #expect(near.overlaps(box))   // reverse delegate
    #expect(!box.overlaps(far))
}

@Test func capsuleCapsuleOverlap() {
    let a = Capsule(a: SIMD2(0, 0), b: SIMD2(10, 0), radius: 1)
    let crossing = Capsule(a: SIMD2(5, -5), b: SIMD2(5, 5), radius: 1)
    let parallelNear = Capsule(a: SIMD2(0, 1.5), b: SIMD2(10, 1.5), radius: 1) // gap 1.5 < 2
    let parallelFar = Capsule(a: SIMD2(0, 3), b: SIMD2(10, 3), radius: 1)      // gap 3 > 2
    #expect(a.overlaps(crossing))
    #expect(a.overlaps(parallelNear))
    #expect(!a.overlaps(parallelFar))
}

@Test func zeroLengthCapsuleActsAsCircle() {
    let dot = Capsule(a: SIMD2(0, 0), b: SIMD2(0, 0), radius: 2)
    #expect(Circle(center: SIMD2(3, 0), radius: 2).overlaps(dot))   // like circle dist 3 < 4
    #expect(!Circle(center: SIMD2(5, 0), radius: 2).overlaps(dot))
}
