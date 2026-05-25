import Testing
@testable import Bielik2D

@Test func identityTransformIsNoOp() {
    let p = Mat3x2.identity.transform(SIMD2<Float>(3, 5))
    #expect(p == SIMD2<Float>(3, 5))
}

@Test func translationAddsToPoint() {
    let p = Mat3x2.translation(x: 10, y: -2).transform(SIMD2<Float>(1, 1))
    #expect(p == SIMD2<Float>(11, -1))
}

@Test func rotation90DegreesMapsXToY() {
    let m = Mat3x2.rotation(angleRadians: .pi / 2)
    let p = m.transform(SIMD2<Float>(1, 0))
    #expect(abs(p.x) < 1e-4)
    #expect(abs(p.y - 1) < 1e-4)
}

@Test func translateThenRotateAppliesRotationFirstInLocalSpace() {
    // T * R, applied to a point, conceptually rotates the point then translates.
    let t = Mat3x2.translation(x: 10, y: 0)
    let r = Mat3x2.rotation(angleRadians: .pi / 2)
    let composed = t * r
    let p = composed.transform(SIMD2<Float>(1, 0))
    #expect(abs(p.x - 10) < 1e-4)
    #expect(abs(p.y - 1) < 1e-4)
}

@Test func inverseUndoesTransform() {
    let m = Mat3x2.translation(x: 10, y: 0)
        * Mat3x2.rotation(angleRadians: .pi / 2)
        * Mat3x2.scale(2, 3)
    let p = SIMD2<Float>(4, -7)
    let back = m.inverse.transform(m.transform(p))
    #expect(abs(back.x - p.x) < 1e-4)
    #expect(abs(back.y - p.y) < 1e-4)
}
