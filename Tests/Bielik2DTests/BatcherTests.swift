import Testing
@testable import Bielik2D

nonisolated(unsafe) private let t1 = OpaquePointer(bitPattern: 0x100)
nonisolated(unsafe) private let t2 = OpaquePointer(bitPattern: 0x200)
private let unit = Rect(x: 0, y: 0, width: 1, height: 1)
private let uv = Rect(x: 0, y: 0, width: 1, height: 1)
private let white = SIMD4<Float>(1, 1, 1, 1)

@Test func stateChangeFlushesCommand() {
    let b = Batcher()
    b.setTexture(t1)
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setTexture(t2)
    b.emitQuad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 2)
    #expect(cmds[0].vertexCount == 6)
    #expect(cmds[1].vertexCount == 6)
}

@Test func sameStateMergesIntoOneCommand() {
    let b = Batcher()
    b.setTexture(t1)
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.emitQuad(rect: unit, uv: uv, color: white)
    #expect(b.commands.count == 1)
    #expect(b.commands[0].vertexCount == 12)
}

@Test func commandsSortedByLayerAscending() {
    let b = Batcher()
    b.setTexture(t1)
    b.setLayer(2); b.emitQuad(rect: unit, uv: uv, color: white)
    b.setLayer(0); b.emitQuad(rect: unit, uv: uv, color: white)
    b.setLayer(1); b.emitQuad(rect: unit, uv: uv, color: white)
    let sorted = b.commandsSortedByLayer
    #expect(sorted.map(\.state.layer) == [0, 1, 2])
}

@Test func resetClearsVerticesAndCommands() {
    let b = Batcher()
    b.setTexture(t1)
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.reset()
    #expect(b.vertices.isEmpty)
    #expect(b.commands.isEmpty)
}

@Test func resetClearsTextureState() {
    // A flushed frame must not leak its texture into the next, or an untextured
    // draw (or render-to-canvas) inherits it — e.g. the canvas samples itself.
    let b = Batcher()
    b.setTexture(t1)
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.reset()
    b.emitQuad(rect: unit, uv: uv, color: white)
    #expect(b.commands.first?.state.texture == nil)
}

@Test func emitCarriesUVBoundsIntoEveryVertex() {
    // Atlas sprites ride a uv-clip rect so the shader can clamp sampling to the
    // sprite's sub-rect; untextured emits leave it zero (shader passthrough).
    let b = Batcher()
    let bounds = SIMD4<Float>(0.1, 0.2, 0.3, 0.4)
    b.emitQuadCorners(p0: .zero, p1: .zero, p2: .zero, p3: .zero,
                      uv: uv, color: white, scaleData: .zero, uvBounds: bounds)
    #expect(b.vertices.count == 6)
    #expect(b.vertices.allSatisfy { $0.uvBounds == bounds })
}

@Test func scissorChangeFlushesCommand() {
    let b = Batcher()
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setScissor(Rect(x: 10, y: 20, width: 100, height: 50))
    b.emitQuad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 2)
    #expect(cmds[0].state.scissor == nil)
    #expect(cmds[1].state.scissor == Rect(x: 10, y: 20, width: 100, height: 50))
}

@Test func viewportChangeFlushesCommand() {
    let b = Batcher()
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setViewport(Rect(x: 0, y: 0, width: 320, height: 240))
    b.emitQuad(rect: unit, uv: uv, color: white)
    let cmds = b.commands
    #expect(cmds.count == 2)
    #expect(cmds[1].state.viewport == Rect(x: 0, y: 0, width: 320, height: 240))
}

@Test func sameScissorMergesIntoOneCommand() {
    let b = Batcher()
    let s = Rect(x: 1, y: 2, width: 3, height: 4)
    b.setScissor(s)
    b.emitQuad(rect: unit, uv: uv, color: white)
    b.setScissor(s)
    b.emitQuad(rect: unit, uv: uv, color: white)
    #expect(b.commands.count == 1)
}

@Test func scissorSurvivesLayerSort() {
    let b = Batcher()
    let s = Rect(x: 5, y: 5, width: 5, height: 5)
    b.setLayer(2)
    b.setScissor(s)
    b.emitQuad(rect: unit, uv: uv, color: white)
    let sorted = b.commandsSortedByLayer
    #expect(sorted.last?.state.scissor == s)
}
