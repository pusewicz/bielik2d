import Testing
@testable import Bielik2D

// Note: the default value of `currentShapeAA` (1.5 / density) is covered by
// PrimitivesTests.circleFillAAScalesWithPixelDensity, which now flows through the
// shapeAA stack. Asserting it again here would mutate the global `Draw.ambientPixelDensity`
// and race that test under swift-testing's parallel execution, so it's omitted.

@Test func pushShapeAAOverridesPrimitiveAA() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushShapeAA(3.0)
    d.circleFill(center: .zero, radius: 10)
    #expect(b.vertices.first!.aa == 3.0)
    d.popShapeAA()
}

@Test func withShapeAAScopesAndRestores() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let before = d.currentShapeAA
    d.with(shapeAA: 4.0) {
        d.box(Rect(x: 0, y: 0, width: 10, height: 10))
    }
    #expect(b.vertices.first!.aa == 4.0)
    #expect(d.currentShapeAA == before)
}

@Test func explicitAAStillWins() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushShapeAA(3.0)
    d.circleFill(center: .zero, radius: 10, aa: 0.5)
    #expect(b.vertices.first!.aa == 0.5)
    d.popShapeAA()
}
