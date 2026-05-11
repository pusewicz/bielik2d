import Testing
@testable import Bielik2D

@Test func circleFillEmitsQuadWithCircleSDFParams() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.circleFill(center: SIMD2<Float>(100, 100), radius: 30, color: .white)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.circle.rawValue)
    #expect(v.radius == 30)
}

@Test func circleFillQuadCoversTheBoundingBox() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.circleFill(center: SIMD2<Float>(100, 100), radius: 30, color: .white)
    let positions = b.vertices.map(\.pos)
    let minX = positions.map(\.x).min()!
    let maxX = positions.map(\.x).max()!
    let minY = positions.map(\.y).min()!
    let maxY = positions.map(\.y).max()!
    // Allow a small AA expansion margin around the bounding box.
    #expect(abs(minX - 70) < 2)
    #expect(abs(maxX - 130) < 2)
    #expect(abs(minY - 70) < 2)
    #expect(abs(maxY - 130) < 2)
}

@Test func lineEmitsQuadAlignedToSegment() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.line(from: SIMD2<Float>(0, 0), to: SIMD2<Float>(100, 0), thickness: 4, color: .white)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.line.rawValue)
    #expect(v.stroke == 4)
}
