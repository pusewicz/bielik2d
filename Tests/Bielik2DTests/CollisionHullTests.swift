import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

private func signedArea(_ vs: [SIMD2<Float>]) -> Float {
    var a: Float = 0
    for i in 0..<vs.count {
        let p = vs[i], q = vs[(i + 1) % vs.count]
        a += p.x * q.y - q.x * p.y
    }
    return a * 0.5
}

@Test func hullDropsInteriorPointAndIsCCW() {
    let p = Polygon(hull: [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2), SIMD2(1, 1)])
    #expect(p.vertices.count == 4)                 // interior (1,1) dropped
    #expect(signedArea(p.vertices) > 0)            // CCW => positive area
    let xs = Set(p.vertices.map { $0.x })
    let ys = Set(p.vertices.map { $0.y })
    #expect(xs == Set([0, 2]))
    #expect(ys == Set([0, 2]))
}

@Test func hullCollapsesCollinearToTwoExtremes() {
    let p = Polygon(hull: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(2, 0)])
    #expect(p.vertices.count == 2)
    #expect(p.vertices.contains(SIMD2(0, 0)))
    #expect(p.vertices.contains(SIMD2(2, 0)))
}

@Test func hullRemovesDuplicatePoints() {
    let p = Polygon(hull: [SIMD2(0, 0), SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1)])
    #expect(p.vertices.count == 3)
}

@Test func hullPassesThroughTinyInputs() {
    #expect(Polygon(hull: [SIMD2(0, 0)]).vertices.count == 1)
    #expect(Polygon(hull: []).vertices.isEmpty)
}

@Test func hullOfUnorderedSquareGivesFourCCWCorners() {
    // Deliberately scrambled order; result must still be a CCW quad.
    let p = Polygon(hull: [SIMD2(2, 2), SIMD2(0, 0), SIMD2(0, 2), SIMD2(2, 0)])
    #expect(p.vertices.count == 4)
    #expect(signedArea(p.vertices) > 0)
}
