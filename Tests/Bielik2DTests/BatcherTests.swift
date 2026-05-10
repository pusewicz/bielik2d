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
