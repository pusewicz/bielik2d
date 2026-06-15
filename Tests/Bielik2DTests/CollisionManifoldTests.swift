import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func circleCircleManifold() {
    let a = Circle(center: SIMD2(0, 0), radius: 2)
    let b = Circle(center: SIMD2(3, 0), radius: 2)   // overlap depth 1
    let m = a.manifold(with: b)
    #expect(m != nil)
    #expect(abs(m!.normal.x - 1) < 1e-4)        // points from a toward b
    #expect(abs(m!.normal.y) < 1e-4)
    #expect(abs(m!.depth - 1) < 1e-4)
    #expect(abs(m!.contact.x - 2) < 1e-4)       // on a's surface along normal
}

@Test func disjointShapesHaveNoManifold() {
    let a = Circle(center: SIMD2(0, 0), radius: 1)
    #expect(a.manifold(with: Circle(center: SIMD2(5, 0), radius: 1)) == nil)
}

@Test func reversePairNegatesNormal() {
    let c = Circle(center: SIMD2(0, 0), radius: 1)
    let box = AABB(min: SIMD2(0.5, -1), max: SIMD2(3, 1))   // overlap on +x
    let forward = c.manifold(with: box)!
    let reverse = box.manifold(with: c)!
    #expect(abs(forward.normal.x - 1) < 1e-4)               // circle pushed -x to separate
    #expect(abs(reverse.normal.x + 1) < 1e-4)               // negated
    #expect(abs(forward.depth - reverse.depth) < 1e-4)
}

@Test func aabbAABBManifoldPicksMinimumAxis() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    let b = AABB(min: SIMD2(1.5, 0.5), max: SIMD2(3.5, 2.5))  // overlapX 0.5 < overlapY 1.5
    let m = a.manifold(with: b)!
    #expect(abs(m.normal.x - 1) < 1e-4)    // separates along x (b is to the right)
    #expect(abs(m.normal.y) < 1e-4)
    #expect(abs(m.depth - 0.5) < 1e-4)
}

@Test func capsuleCapsuleManifold() {
    let a = Capsule(a: SIMD2(0, 0), b: SIMD2(10, 0), radius: 1)
    let b = Capsule(a: SIMD2(0, 1.5), b: SIMD2(10, 1.5), radius: 1)  // gap 1.5, depth 0.5
    let m = a.manifold(with: b)!
    #expect(abs(m.normal.y - 1) < 1e-4)    // points from a up toward b
    #expect(abs(m.depth - 0.5) < 1e-4)
}
