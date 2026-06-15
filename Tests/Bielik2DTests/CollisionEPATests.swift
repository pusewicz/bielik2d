import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

private func penetration(_ A: Support, _ B: Support) -> EPAResult {
    guard case let .penetrating(simplex) = gjkDistance(A, B) else {
        Issue.record("expected penetrating"); return EPAResult(normal: .zero, depth: 0, witnessA: .zero, witnessB: .zero)
    }
    return epaPenetration(simplex, A, B)
}

@Test func epaAxisAlignedOverlapDepthAndNormal() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2)).support
    let b = AABB(min: SIMD2(1, 0), max: SIMD2(3, 2)).support   // overlap x = 1
    let r = penetration(a, b)
    #expect(abs(r.depth - 1) < 1e-3)
    #expect(abs(r.normal.x - 1) < 1e-3)        // +x: A pushed -x to separate
    #expect(abs(r.normal.y) < 1e-3)
}

@Test func epaPicksMinimumPenetrationAxis() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2)).support
    let b = AABB(min: SIMD2(1.5, 0.5), max: SIMD2(3.5, 2.5)).support  // overlap x 0.5 < y 1.5
    let r = penetration(a, b)
    #expect(abs(r.depth - 0.5) < 1e-3)
    #expect(abs(r.normal.x - 1) < 1e-3)
    #expect(abs(r.normal.y) < 1e-3)
}

@Test func epaSeparationInvariant() {
    // Backstop: shifting A by -normal*depth must make the cores just-touch (distance ~ 0).
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2)).support
    let b = AABB(min: SIMD2(1.5, 0.5), max: SIMD2(3.5, 2.5)).support
    let r = penetration(a, b)
    let shift = -r.normal * r.depth
    let aShifted = Support(radius: a.radius) { dir in a.support(dir) + shift }
    if case let .separated(distance, _, _, _) = gjkDistance(aShifted, b) {
        #expect(distance < 1e-2)
    }
}
