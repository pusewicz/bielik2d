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

@Test func polylineEmitsOneCapsulePerSegment() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyline([SIMD2<Float>(0, 0), SIMD2<Float>(10, 0), SIMD2<Float>(10, 10)], thickness: 4)
    // 3 points -> 2 segments -> 2 capsules -> 12 vertices, all capsule type.
    #expect(b.vertices.count == 12)
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.capsule.rawValue })
}

@Test func closedPolylineWrapsBackToStart() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyline([SIMD2<Float>(0, 0), SIMD2<Float>(10, 0), SIMD2<Float>(10, 10)],
               thickness: 4, closed: true)
    // 3 segments (incl. closing edge) -> 18 vertices.
    #expect(b.vertices.count == 18)
}

@Test func polyOutlineIsAClosedPolyline() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.poly([SIMD2<Float>(0, 0), SIMD2<Float>(20, 0), SIMD2<Float>(10, 20)], stroke: 2)
    #expect(b.vertices.count == 18)  // 3 segments
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.capsule.rawValue })
}

@Test func strokedTriIsAClosedThreeSegmentOutline() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.tri(SIMD2<Float>(0, 0), SIMD2<Float>(20, 0), SIMD2<Float>(10, 20), stroke: 2)
    #expect(b.vertices.count == 18)
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.capsule.rawValue })
}

@Test func polyFillEmitsCentroidFanOfConvexPolyTriangles() {
    let b = Batcher()
    let d = Draw(batcher: b)
    // A square: 4 edges -> 4 fan triangles -> 12 vertices.
    d.polyFill([SIMD2<Float>(-10, -10), SIMD2<Float>(10, -10),
                SIMD2<Float>(10, 10), SIMD2<Float>(-10, 10)])
    #expect(b.vertices.count == 12)
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.convexPoly.rawValue })
    #expect(b.vertices.allSatisfy { $0.fill == 1 })
}

@Test func polyFillPacksTrueOuterEdgeIntoAttributes() {
    let b = Batcher()
    let d = Draw(batcher: b)
    // Centroid is the origin, so centroid-local edge 0 is (-10,-10)->(10,-10).
    d.polyFill([SIMD2<Float>(-10, -10), SIMD2<Float>(10, -10),
                SIMD2<Float>(10, 10), SIMD2<Float>(-10, 10)], aa: 2)
    let v = b.vertices.first!
    #expect(v.attributes.x == -10 && v.attributes.y == -10)  // edge start A
    #expect(v.attributes.z == 10 && v.attributes.w == -10)   // edge end B
    #expect(v.aa == 2)
}

@Test func polyFillExpandsRimOutwardByAAForFringe() {
    let b = Batcher()
    let d = Draw(batcher: b)
    // Square ±10 centred at origin, identity transform: positions are centroid-local.
    // Mitred corners push out by ~aa, so the bounds grow from ±10 to ≈ ±12.
    d.polyFill([SIMD2<Float>(-10, -10), SIMD2<Float>(10, -10),
                SIMD2<Float>(10, 10), SIMD2<Float>(-10, 10)], aa: 2)
    let xs = b.vertices.map(\.pos.x)
    let ys = b.vertices.map(\.pos.y)
    #expect(abs(xs.min()! - (-12)) < 0.5)
    #expect(abs(xs.max()! -   12) < 0.5)
    #expect(abs(ys.min()! - (-12)) < 0.5)
    #expect(abs(ys.max()! -   12) < 0.5)
}

@Test func polyFillWithFewerThanThreePointsEmitsNothing() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyFill([SIMD2<Float>(0, 0), SIMD2<Float>(10, 0)])
    #expect(b.vertices.isEmpty)
}

@Test func polylineWithFewerThanTwoPointsEmitsNothing() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyline([SIMD2<Float>(5, 5)], thickness: 4)
    #expect(b.vertices.isEmpty)
}

@Test func boxFillEmitsFilledBox() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.boxFill(Rect(x: 0, y: 0, width: 40, height: 20), cornerRadius: 6)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.box.rawValue)
    #expect(v.fill == 1)
    #expect(v.radius == 6)  // cornerRadius forwarded
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
