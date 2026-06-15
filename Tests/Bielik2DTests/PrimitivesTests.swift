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

@Test func circleFillAAScalesWithPixelDensity() {
    let saved = Draw.ambientPixelDensity
    defer { Draw.ambientPixelDensity = saved }
    Draw.ambientPixelDensity = 2.0
    let b = Batcher()
    Draw(batcher: b).circleFill(center: .zero, radius: 30)
    // Default aa should be 1.5 / density = 0.75 at 2× density.
    #expect(abs(b.vertices.first!.aa - 0.75) < 0.01)
}

@Test func boxEmitsVerticesWithBoxTypeAndHalfExtents() {
    let b = Batcher()
    Draw(batcher: b).box(Rect(x: 10, y: 20, width: 100, height: 80))
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.box.rawValue)
    #expect(v.attributes.x == 50)  // halfW = 100/2
    #expect(v.attributes.y == 40)  // halfH = 80/2
}

@Test func boxQuadExpandedBeyondRectByAA() {
    let b = Batcher()
    Draw(batcher: b).box(Rect(x: 0, y: 0, width: 100, height: 60), aa: 2.0)
    let xs = b.vertices.map(\.pos.x)
    let ys = b.vertices.map(\.pos.y)
    #expect(xs.min()! <= -2.0 + 0.01)   // ≤ rect.x − aa
    #expect(xs.max()! >= 100.0 + 2.0 - 0.01) // ≥ rect.maxX + aa
    #expect(ys.min()! <= -2.0 + 0.01)
    #expect(ys.max()! >= 60.0 + 2.0 - 0.01)
}

@Test func circleOutlineEmitsStrokedCircleParams() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.circle(center: SIMD2<Float>(50, 50), radius: 20, thickness: 4, color: .white)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.circle.rawValue)
    #expect(v.fill == 0)
    #expect(v.stroke == 4)
    #expect(v.radius == 20)
}

@Test func triFilledPacksCornersIntoVertexChannels() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let a = SIMD2<Float>(0, 0), bb = SIMD2<Float>(30, 0), c = SIMD2<Float>(0, 30)
    d.tri(a, bb, c)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.triangle.rawValue)
    #expect(v.fill == 1)
    let centroid = (a + bb + c) / 3
    #expect(abs(v.attributes.x - (a.x - centroid.x)) < 1e-3)
    #expect(abs(v.attributes.y - (a.y - centroid.y)) < 1e-3)
    #expect(abs(v.attributes.z - (bb.x - centroid.x)) < 1e-3)
    #expect(abs(v.attributes.w - (bb.y - centroid.y)) < 1e-3)
    #expect(abs(v.uvBounds.x - (c.x - centroid.x)) < 1e-3)
    #expect(abs(v.uvBounds.y - (c.y - centroid.y)) < 1e-3)
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
