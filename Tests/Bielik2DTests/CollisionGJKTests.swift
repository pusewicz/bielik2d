import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func gjkDistanceBetweenSeparatedSquares() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2)).support
    let b = AABB(min: SIMD2(3, 0), max: SIMD2(5, 2)).support
    guard case let .separated(distance, pointA, pointB, normal) = gjkDistance(a, b) else {
        Issue.record("expected separated"); return
    }
    #expect(abs(distance - 1) < 1e-4)        // gap between x=2 and x=3
    #expect(abs(pointA.x - 2) < 1e-4)        // witness on A's right face
    #expect(abs(pointB.x - 3) < 1e-4)        // witness on B's left face
    #expect(abs(normal.x - 1) < 1e-4)        // points A -> B (+x)
    #expect(abs(normal.y) < 1e-4)
}

@Test func gjkDistanceDiagonalSquares() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(1, 1)).support
    let b = AABB(min: SIMD2(2, 2), max: SIMD2(3, 3)).support
    guard case let .separated(distance, pointA, pointB, _) = gjkDistance(a, b) else {
        Issue.record("expected separated"); return
    }
    #expect(abs(distance - Float(2).squareRoot()) < 1e-4)
    #expect(abs(pointA.x - 1) < 1e-4 && abs(pointA.y - 1) < 1e-4)
    #expect(abs(pointB.x - 2) < 1e-4 && abs(pointB.y - 2) < 1e-4)
}

@Test func gjkDistanceTouchingIsNearZero() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2)).support
    let b = AABB(min: SIMD2(2, 0), max: SIMD2(4, 2)).support
    // Exact touch: either a near-zero separation or the penetrating branch is acceptable.
    if case let .separated(distance, _, _, _) = gjkDistance(a, b) {
        #expect(distance < 1e-3)
    }
}
