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

@Test func defaultQuadCarriesNoScalePayload() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.quad(rect: unit, uv: uv, color: white)
    // linear (0) with no texture size: every existing draw stays byte-identical.
    #expect(b.vertices.allSatisfy { $0.attributes == .zero })
}

@Test func pixelArtQuadPacksTexelSizeAndMode() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.quad(rect: unit, uv: uv, color: white, scaleMode: .pixelArt, textureSize: SIMD2(32, 48))
    #expect(b.vertices.allSatisfy { $0.attributes == SIMD4<Float>(32, 48, 1, 0) })
}

@Test func nearestQuadPacksModeTwo() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.quad(rect: unit, uv: uv, color: white, scaleMode: .nearest, textureSize: SIMD2(16, 16))
    #expect(b.vertices.first?.attributes == SIMD4<Float>(16, 16, 2, 0))
}

@Test func pushedScaleModeAppliesToQuad() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushScaleMode(.pixelArt)
    d.quad(rect: unit, uv: uv, color: white, textureSize: SIMD2(8, 8))
    #expect(b.vertices.first?.attributes == SIMD4<Float>(8, 8, 1, 0))
}

@Test func perCallScaleModeOverridesPushed() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushScaleMode(.pixelArt)
    d.quad(rect: unit, uv: uv, color: white, scaleMode: .nearest, textureSize: SIMD2(8, 8))
    #expect(b.vertices.first?.attributes == SIMD4<Float>(8, 8, 2, 0))
}

@Test func popScaleModeRestoresPrevious() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushScaleMode(.pixelArt)
    d.pushScaleMode(.nearest)
    d.popScaleMode()
    #expect(d.currentScaleMode == .pixelArt)
    d.quad(rect: unit, uv: uv, color: white, textureSize: SIMD2(8, 8))
    #expect(b.vertices.first?.attributes == SIMD4<Float>(8, 8, 1, 0))
}

@Test func withScaleModeAppliesInsideAndRestoresAfter() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.with(scaleMode: .pixelArt) {
        d.quad(rect: unit, uv: uv, color: white, textureSize: SIMD2(8, 8))
    }
    #expect(b.vertices.first?.attributes == SIMD4<Float>(8, 8, 1, 0))
    #expect(d.currentScaleMode == .linear)   // reverted on scope exit
}

@Test func withCombinesColorAndScaleModeThenReverts() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.with(color: Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0), scaleMode: .nearest) {
        d.quad(rect: unit, uv: uv, color: white, textureSize: SIMD2(4, 4))
    }
    let v = b.vertices.first!
    #expect(v.attributes == SIMD4<Float>(4, 4, 2, 0))
    #expect(abs(v.color.x - 0.5) < 1e-5)
    #expect(d.currentScaleMode == .linear)        // both axes reverted
    #expect(d.currentColor == .white)
}

@Test func withReturnsBodyValue() {
    let d = Draw(batcher: Batcher())
    let n = d.with(scaleMode: .pixelArt) { 42 }
    #expect(n == 42)
}

@Test func withTransformComposesLikeManualPush() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.with(transform: .translation(x: 10, y: 5)) {
        d.quad(rect: unit, uv: uv, color: white)
    }
    #expect(b.vertices.first?.pos == SIMD2<Float>(10, 5))
    #expect(d.currentTransform == .identity)   // reverted
}

@Test func pushScissorSplitsAndRestores() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let s = Rect(x: 10, y: 20, width: 100, height: 50)
    d.quad(rect: unit, uv: uv, color: white)
    d.pushScissor(s)
    #expect(d.currentScissor == s)
    d.quad(rect: unit, uv: uv, color: white)
    d.popScissor()
    #expect(d.currentScissor == nil)
    d.quad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 3)
    #expect(cmds[0].state.scissor == nil)
    #expect(cmds[1].state.scissor == s)
    #expect(cmds[2].state.scissor == nil)
}

@Test func pushBlendStateAffectsCommandState() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushBlendState(.additive)
    #expect(d.currentBlendState == .additive)
    d.quad(rect: unit, uv: uv, color: white)
    #expect(b.commands.last?.state.blendMode == .additive)
}

@Test func withScissorScopesAndAutoPops() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let s = Rect(x: 0, y: 0, width: 10, height: 10)
    d.with(scissor: s) {
        d.quad(rect: unit, uv: uv, color: white)
    }
    #expect(d.currentScissor == nil)
    #expect(b.commands.first?.state.scissor == s)
}
