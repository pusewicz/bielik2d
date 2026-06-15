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
