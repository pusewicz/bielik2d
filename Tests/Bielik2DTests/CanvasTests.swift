import AppKit
import Testing
import CSDL3
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct CanvasTests {
    init() { _ = NSApplication.shared }

    @Test func canvasOwnsAColorTargetTexture() throws {
        let app = try App(title: "canvas-make", width: 64, height: 64)
        defer { app.destroy() }
        let c = try Canvas(width: 128, height: 96, on: app.renderer)
        defer { c.destroy() }
        #expect(c.width == 128)
        #expect(c.height == 96)
    }

    @Test func drawCanvasEmitsTexturedQuadReferencingTheCanvas() throws {
        let app = try App(title: "canvas-draw", width: 64, height: 64)
        defer { app.destroy() }
        let c = try Canvas(width: 32, height: 32, on: app.renderer)
        defer { c.destroy() }
        let b = Batcher()
        let d = Draw(batcher: b)
        d.canvas(c, at: SIMD2<Float>(50, 60))
        #expect(b.vertices.count == 6)
        let cmd = b.commands.first
        #expect(cmd?.state.texture == c.texture.handle)
    }
}
