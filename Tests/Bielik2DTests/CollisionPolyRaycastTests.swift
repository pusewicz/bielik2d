import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

private let triangle = Polygon(vertices: [SIMD2(0, 0), SIMD2(4, 0), SIMD2(0, 4)])

@Test func rayHitsTriangleLeftEdge() {
    let ray = Ray(origin: SIMD2(-1, 1), direction: SIMD2(1, 0), length: 10)
    let hit = ray.cast(against: triangle)
    #expect(hit != nil)
    #expect(abs(hit!.t - 1) < 1e-4)                 // enters at x=0
    #expect(abs(hit!.point.x) < 1e-4 && abs(hit!.point.y - 1) < 1e-4)
    #expect(abs(hit!.normal.x + 1) < 1e-4)          // faces back toward origin (-x)
}

@Test func rayMissesTriangle() {
    let ray = Ray(origin: SIMD2(5, 5), direction: SIMD2(1, 0), length: 10)
    #expect(ray.cast(against: triangle) == nil)
}

@Test func rayTooShortMissesTriangle() {
    let ray = Ray(origin: SIMD2(-1, 1), direction: SIMD2(1, 0), length: 0.5)  // stops at x=-0.5
    #expect(ray.cast(against: triangle) == nil)
}
