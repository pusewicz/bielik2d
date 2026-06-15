import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func moveStopsAtFloorWithNoSlideWhenVertical() {
    // Circle (0,5) r1 dropping by (0,-10) onto a floor plane at y=0. Bottom travels 4 -> stops
    // with center near y=1; small positive skin keeps it off the surface. No horizontal motion.
    let mover = Circle(center: SIMD2(0, 5), radius: 1)
    let floor = Halfspace(point: SIMD2(0, 0), normal: SIMD2(0, 1))
    let r = mover.move(by: SIMD2(0, -10), against: [floor])
    #expect(abs(r.motion.x) < 1e-3)
    #expect(r.motion.y > -4.0)                   // didn't fall the full 10
    #expect(r.motion.y < -3.9)                   // stopped ~4 down (center ~y=1)
    #expect(r.normals.count == 1)
    #expect(r.normals[0].y > 0.9)
}

@Test func moveSlidesAlongFloor() {
    // Circle (0,5) r1 moving by (3,-10) onto a floor at y=0. Vertical impact at t=0.4 after
    // x has advanced 1.2; the remaining (1.8,-6) loses its into-floor component and slides to
    // (1.8,0). Net motion ~ (3.0, -4) plus a tiny skin offset.
    let mover = Circle(center: SIMD2(0, 5), radius: 1)
    let floor = Halfspace(point: SIMD2(0, 0), normal: SIMD2(0, 1))
    let r = mover.move(by: SIMD2(3, -10), against: [floor])
    #expect(abs(r.motion.x - 3.0) < 5e-2)
    #expect(abs(r.motion.y + 4.0) < 5e-2)
    #expect(r.normals.first.map { $0.y > 0.9 } ?? false)
}

@Test func moveWithNoObstaclesAppliesFullDelta() {
    let mover = Circle(center: SIMD2(0, 0), radius: 1)
    let r = mover.move(by: SIMD2(5, -2), against: [])
    #expect(abs(r.motion.x - 5) < 1e-4)
    #expect(abs(r.motion.y + 2) < 1e-4)
    #expect(r.normals.isEmpty)
}

@Test func moveIntoVerticalWallKillsSlide() {
    // Circle (0,0) r1 moving (10,0) into a wall at x=5 (outward normal (-1,0), solid side +x).
    // Right edge reaches the wall after the center travels 4 -> t=0.4; the remaining (6,0) is
    // entirely into-surface, so the slide collapses to zero. Net motion ~ (4,0) minus a tiny skin.
    let mover = Circle(center: SIMD2(0, 0), radius: 1)
    let wall = Halfspace(point: SIMD2(5, 0), normal: SIMD2(-1, 0))
    let r = mover.move(by: SIMD2(10, 0), against: [wall])
    #expect(abs(r.motion.x - 4.0) < 5e-2)
    #expect(abs(r.motion.y) < 1e-3)
    #expect(r.normals.count == 1)
    #expect(r.normals[0].x < -0.9)
}
