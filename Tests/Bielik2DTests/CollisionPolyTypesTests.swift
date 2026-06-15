import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func polygonStoresVertices() {
    let p = Polygon(vertices: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1)])
    #expect(p.vertices.count == 3)
    #expect(p.vertices[1] == SIMD2(1, 0))
}

@Test func halfspaceNormalizesNormal() {
    let h = Halfspace(point: SIMD2(0, 0), normal: SIMD2(0, 3))
    #expect(abs(simd_length(h.normal) - 1) < 1e-5)
    #expect(h.normal == SIMD2(0, 1))
    #expect(h.point == SIMD2(0, 0))
}

@Test func halfspaceDegenerateNormalFallsBack() {
    let h = Halfspace(point: SIMD2(1, 2), normal: SIMD2(0, 0))
    #expect(h.normal == SIMD2(0, 1))
}
