import AppKit
import Foundation
import Testing
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct RendererAtlasTests {
    init() { _ = NSApplication.shared }

    private func solid(_ w: Int, _ h: Int) -> ImageBytes {
        ImageBytes(width: w, height: h, pixels: Data([UInt8](repeating: 0xFF, count: w * h * 4)))
    }

    @Test func manyDistinctSpritesCollapseToOneDrawCall() throws {
        let app = try App(title: "atlas-collapse", width: 64, height: 64)
        defer { app.destroy() }
        let canvas = try app.renderer.makeCanvas(width: 256, height: 256)

        let draw = Draw()
        for i in 0..<32 {
            let s = app.renderer.makeSprite(image: solid(4, 4))   // 32 distinct images
            draw.sprite(s, at: SIMD2(Float(i), Float(i)))
        }
        app.renderer.render(draw, to: canvas)

        // All 32 share one atlas page → one bind → one draw call.
        #expect(app.renderer.lastDrawCallCount == 1)
    }
}
