import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func debugPolygonEmitsOneLinePerEdge() {
    let b = Batcher()
    let square = Polygon(vertices: [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2)])
    Draw(batcher: b).debug(square)
    #expect(b.vertices.count == 24)                 // 4 edges * 6 verts per line quad
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.line.rawValue })
}

@Test func debugHalfspaceEmitsOneLine() {
    let b = Batcher()
    Draw(batcher: b).debug(Halfspace(point: SIMD2(0, 0), normal: SIMD2(0, 1)))
    #expect(b.vertices.count == 6)                  // a single line segment
    #expect(b.vertices.first!.type == ShapeType.line.rawValue)
}
