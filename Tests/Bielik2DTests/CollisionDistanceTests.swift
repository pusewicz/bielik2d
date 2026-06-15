import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

private let squareP = Polygon(vertices: [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2)])
private let triangleP = Polygon(vertices: [SIMD2(0, 0), SIMD2(4, 0), SIMD2(0, 4)])

@Test func distanceBetweenSeparatedPolygons() {
    let b = Polygon(vertices: [SIMD2(3, 0), SIMD2(5, 0), SIMD2(5, 2), SIMD2(3, 2)])
    let d = squareP.distance(to: b)
    #expect(abs(d.distance - 1) < 1e-4)
    #expect(abs(d.pointA.x - 2) < 1e-4)
    #expect(abs(d.pointB.x - 3) < 1e-4)
}

@Test func distancePolyCircleSubtractsRadius() {
    let c = Circle(center: SIMD2(-3, 2), radius: 1.5)   // core dist 3 -> surface 1.5
    #expect(abs(triangleP.distance(to: c).distance - 1.5) < 1e-3)
    // Reverse swaps witnesses but keeps the distance.
    let rev = c.distance(to: triangleP)
    #expect(abs(rev.distance - 1.5) < 1e-3)
    #expect(abs(rev.pointB.x) < 1e-3)                   // pointB now on the triangle edge x=0
}

@Test func distanceZeroWhenOverlapping() {
    let b = Polygon(vertices: [SIMD2(1, 0), SIMD2(3, 0), SIMD2(3, 2), SIMD2(1, 2)])
    #expect(squareP.distance(to: b).distance == 0)
}
