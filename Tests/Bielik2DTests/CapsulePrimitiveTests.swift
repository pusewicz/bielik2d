import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func capsuleEmitsQuadWithCapsuleType() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.capsule(from: SIMD2(0, 0), to: SIMD2(100, 0), radius: 10, color: .white)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.capsule.rawValue)
    #expect(v.radius == 10)
    #expect(v.fill == 1)                          // stroke 0 -> filled
    #expect(abs(v.attributes.x - 50) < 1e-4)      // halfLen = length/2
}

@Test func capsuleStrokeMarksOutline() {
    let b = Batcher()
    Draw(batcher: b).capsule(from: SIMD2(0, 0), to: SIMD2(10, 0), radius: 4, stroke: 2)
    #expect(b.vertices.first!.fill == 0)          // stroke > 0 -> outline
    #expect(b.vertices.first!.stroke == 2)
}

@Test func capsuleQuadExtendsByRadiusPlusAA() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.capsule(from: SIMD2(0, 0), to: SIMD2(100, 0), radius: 10, color: .white, aa: 1)
    let xs = b.vertices.map(\.pos.x)
    let ys = b.vertices.map(\.pos.y)
    // Axis x extends radius+aa past each endpoint; perpendicular y spans radius+aa.
    #expect(abs(xs.min()! - (-11)) < 1e-3)
    #expect(abs(xs.max()! - 111) < 1e-3)
    #expect(abs(ys.min()! - (-11)) < 1e-3)
    #expect(abs(ys.max()! - 11) < 1e-3)
}

@Test func debugDrawCircleEmitsRing() {
    let b = Batcher()
    Draw(batcher: b).debug(Circle(center: SIMD2(0, 0), radius: 5))
    // A circle ring is drawn via a zero-length stroked capsule.
    #expect(b.vertices.first!.type == ShapeType.capsule.rawValue)
    #expect(b.vertices.first!.radius == 5)
    #expect(b.vertices.first!.fill == 0)   // stroked outline, not filled
}

@Test func debugDrawAABBEmitsBox() {
    let b = Batcher()
    Draw(batcher: b).debug(AABB(min: SIMD2(0, 0), max: SIMD2(4, 4)))
    #expect(b.vertices.first!.type == ShapeType.box.rawValue)
}

@Test func debugDrawCapsuleEmitsCapsule() {
    let b = Batcher()
    Draw(batcher: b).debug(Capsule(a: SIMD2(0, 0), b: SIMD2(10, 0), radius: 2))
    #expect(b.vertices.first!.type == ShapeType.capsule.rawValue)
}
