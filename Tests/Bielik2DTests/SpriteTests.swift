import AppKit
import Foundation
import Testing
import CSDL3
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct SpriteTests {
    init() { _ = NSApplication.shared }

    private func fixturePath(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "fixtures")!
        return url.path
    }

    @Test func loadPNGFromFixtureHasKnownPixel() throws {
        let app = try App(title: "spr-load", width: 64, height: 64)
        defer { app.destroy() }
        let s = try Sprite(png: fixturePath("4x4.png"), on: app.gpu)
        defer { s.destroy() }
        #expect(s.width == 4)
        #expect(s.height == 4)
    }

    @Test func drawSpriteEmitsOneTexturedQuad() throws {
        let app = try App(title: "spr-draw", width: 64, height: 64)
        defer { app.destroy() }
        let s = try Sprite(png: fixturePath("4x4.png"), on: app.gpu)
        defer { s.destroy() }
        let b = Batcher()
        let d = Draw(batcher: b)
        d.sprite(s, at: SIMD2<Float>(10, 20))
        #expect(b.vertices.count == 6)
        // Quad covers the sprite's native size starting at (10, 20).
        #expect(b.vertices.first?.pos == SIMD2<Float>(10, 20))
        #expect(b.vertices[2].pos == SIMD2<Float>(10 + 4, 20 + 4))
    }
}
