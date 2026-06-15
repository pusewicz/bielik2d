import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func sweepCircleHitsCircleHeadOn() {
    // Mover at (0,0) r1, target at (20,0) r1. Cores 20 apart, minus radii 2 -> gap 18.
    // delta (20,0): impact when gap closes -> t = 18/20 = 0.9.
    let mover = Circle(center: SIMD2(0, 0), radius: 1)
    let hit = mover.sweep(by: SIMD2(20, 0), against: Circle(center: SIMD2(20, 0), radius: 1))
    #expect(hit != nil)
    #expect(abs(hit!.t - 0.9) < 1e-2)
    #expect(hit!.normal.x < -0.9)               // surface normal faces back toward the mover
}

@Test func sweepFastCircleDoesNotTunnelCircle() {
    // A long sweep straight through a small target: discrete midpoint sampling could miss; CA must not.
    let mover = Circle(center: SIMD2(-100, 0), radius: 1)
    let hit = mover.sweep(by: SIMD2(200, 0), against: Circle(center: SIMD2(0, 0), radius: 1))
    #expect(hit != nil)
    // gap = 100 - 2 = 98; speed 200 -> t = 0.49.
    #expect(abs(hit!.t - 0.49) < 1e-2)
}

@Test func sweepCircleMissesCircle() {
    let mover = Circle(center: SIMD2(0, 0), radius: 1)
    #expect(mover.sweep(by: SIMD2(0, 5), against: Circle(center: SIMD2(20, 0), radius: 1)) == nil)
}

@Test func sweepBothMovingReportsWorldSpaceContact() {
    // mover (0,0) r1 by (20,0); target (10,0) r1 by (10,0) -> relDelta (10,0).
    // Cores 10 apart, minus radii 2 -> gap 8; relative speed 10 -> t = 0.8.
    // At t=0.8 the (moving) target center is (18,0); contact on its left surface is (17,0).
    let mover = Circle(center: SIMD2(0, 0), radius: 1)
    let hit = mover.sweep(by: SIMD2(20, 0),
                          against: Circle(center: SIMD2(10, 0), radius: 1),
                          movedBy: SIMD2(10, 0))
    #expect(hit != nil)
    #expect(abs(hit!.t - 0.8) < 1e-2)
    #expect(abs(hit!.point.x - 17) < 5e-2)
    #expect(abs(hit!.point.y) < 5e-2)
}

@Test func sweepCircleHitsAABBTop() {
    // Circle (0,5) r1 falling by (0,-10). AABB top edge at y=0. Bottom of circle at y=4,
    // gap to top = 4 -> t = 4/10 = 0.4. Surface normal faces up.
    let mover = Circle(center: SIMD2(0, 5), radius: 1)
    let box = AABB(min: SIMD2(-5, -1), max: SIMD2(5, 0))
    let hit = mover.sweep(by: SIMD2(0, -10), against: box)
    #expect(hit != nil)
    #expect(abs(hit!.t - 0.4) < 1e-2)
    #expect(hit!.normal.y > 0.9)
}

@Test func sweepFastCircleDoesNotTunnelThinBox() {
    // Circle (-10,0) r1 swept by (20,0) through a 0.2-wide box. CA must catch it.
    let mover = Circle(center: SIMD2(-10, 0), radius: 1)
    let thin = AABB(min: SIMD2(-0.1, -5), max: SIMD2(0.1, 5))
    let hit = mover.sweep(by: SIMD2(20, 0), against: thin)
    #expect(hit != nil)
    // closest box face at x=-0.1; center->face 9.9, minus radius 1 -> gap 8.9; t = 8.9/20 = 0.445.
    #expect(abs(hit!.t - 0.445) < 2e-2)
}

@Test func sweepPolygonHitsPolygon() {
    // Unit square mover centered (0,0) swept by (10,0) toward a unit square centered (5,0).
    // Right face of mover at x=1, left face of target at x=4 -> gap 3 -> t = 3/10 = 0.3.
    let mover = Polygon(vertices: [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)])
    let target = Polygon(vertices: [SIMD2(4, -1), SIMD2(6, -1), SIMD2(6, 1), SIMD2(4, 1)])
    let hit = mover.sweep(by: SIMD2(10, 0), against: target)
    #expect(hit != nil)
    #expect(abs(hit!.t - 0.3) < 1e-2)
}

@Test func sweepBothMovingUsesRelativeMotion() {
    // Both circles r1 close head-on: A (0,0) by (10,0), B (20,0) by (-10,0) -> relDelta (20,0).
    // gap 18, speed 20 -> t = 0.9.
    let a = Circle(center: SIMD2(0, 0), radius: 1)
    let hit = a.sweep(by: SIMD2(10, 0),
                      against: Circle(center: SIMD2(20, 0), radius: 1),
                      movedBy: SIMD2(-10, 0))
    #expect(hit != nil)
    #expect(abs(hit!.t - 0.9) < 1e-2)
}
