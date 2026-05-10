import Testing
@testable import Bielik2D

private let unit = Rect(x: 0, y: 0, width: 1, height: 1)
private let uv = Rect(x: 0, y: 0, width: 1, height: 1)
private let white = SIMD4<Float>(1, 1, 1, 1)

@Test func transformStackAppliesToEmittedVertices() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushTransform(.translation(x: 100, y: -50))
    d.quad(rect: unit, uv: uv, color: white)
    let first = b.vertices.first
    #expect(first?.pos == SIMD2<Float>(100, -50))
}

@Test func nestedTransformsCompose() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushTransform(.translation(x: 10, y: 0))
    d.pushTransform(.translation(x: 5, y: 0))
    d.quad(rect: Rect(x: 0, y: 0, width: 1, height: 1), uv: uv, color: white)
    #expect(b.vertices.first?.pos == SIMD2<Float>(15, 0))
    d.popTransform()
    d.quad(rect: Rect(x: 0, y: 0, width: 1, height: 1), uv: uv, color: white)
    #expect(b.vertices.last?.pos == SIMD2<Float>(10, 1))
}

@Test func colorStackTintsVertices() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushColor(Color(r: 0.5, g: 0.25, b: 1.0, a: 0.8))
    d.quad(rect: unit, uv: uv, color: white)
    let c = b.vertices.first!.color
    #expect(abs(c.x - 0.5) < 1e-5)
    #expect(abs(c.y - 0.25) < 1e-5)
    #expect(abs(c.z - 1.0) < 1e-5)
    #expect(abs(c.w - 0.8) < 1e-5)
}
