import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func rayHitsCircle() {
    let ray = Ray(origin: SIMD2(-5, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2))
    #expect(hit != nil)
    #expect(abs(hit!.t - 3) < 1e-4)
    #expect(abs(hit!.point.x + 2) < 1e-4)        // (-2, 0)
    #expect(abs(hit!.normal.x + 1) < 1e-4)       // faces back toward origin
}

@Test func rayMissesCircle() {
    let ray = Ray(origin: SIMD2(-5, 10), direction: SIMD2(1, 0), length: 100)
    #expect(ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2)) == nil)
}

@Test func rayTooShortMissesCircle() {
    let ray = Ray(origin: SIMD2(-5, 0), direction: SIMD2(1, 0), length: 2)  // stops at x=-3
    #expect(ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2)) == nil)
}

@Test func rayFromInsideCircleHitsAtZero() {
    let ray = Ray(origin: SIMD2(0, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2))
    #expect(hit != nil)
    #expect(abs(hit!.t) < 1e-4)
}

@Test func rayHitsAABB() {
    let ray = Ray(origin: SIMD2(-5, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: AABB(min: SIMD2(-2, -2), max: SIMD2(2, 2)))
    #expect(hit != nil)
    #expect(abs(hit!.t - 3) < 1e-4)
    #expect(abs(hit!.normal.x + 1) < 1e-4)
}

@Test func rayParallelMissesAABB() {
    let ray = Ray(origin: SIMD2(-5, 9), direction: SIMD2(1, 0), length: 100)
    #expect(ray.cast(against: AABB(min: SIMD2(-2, -2), max: SIMD2(2, 2))) == nil)
}

@Test func rayHitsCapsuleSide() {
    let ray = Ray(origin: SIMD2(0, -5), direction: SIMD2(0, 1), length: 100)
    let hit = ray.cast(against: Capsule(a: SIMD2(-3, 0), b: SIMD2(3, 0), radius: 1))
    #expect(hit != nil)
    #expect(abs(hit!.t - 4) < 1e-4)              // hits y = -1
    #expect(abs(hit!.normal.y + 1) < 1e-4)
}

@Test func rayHitsCapsuleEndCap() {
    let ray = Ray(origin: SIMD2(-10, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: Capsule(a: SIMD2(-3, 0), b: SIMD2(3, 0), radius: 1))
    #expect(hit != nil)
    #expect(abs(hit!.t - 6) < 1e-4)              // hits the left cap at x = -4
}
