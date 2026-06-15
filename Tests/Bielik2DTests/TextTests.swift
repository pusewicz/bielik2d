import AppKit
import Foundation
import Testing
import CSDL3
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct TextTests {
    init() { _ = NSApplication.shared }

    private func fixturePath(_ name: String) -> String {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "fixtures")!.path
    }

    @Test func openFontFromFixture() throws {
        let app = try App(title: "font-open", width: 64, height: 64)
        defer { app.destroy() }
        let font = try Font(path: fixturePath("Geneva.ttf"), ptSize: 18)
        defer { font.destroy() }
        #expect(font.handle != nil)
    }

    @Test func fontWithDensity1HasRenderScaleOf1() throws {
        let app = try App(title: "font-scale-1x", width: 64, height: 64)
        defer { app.destroy() }
        let font = try Font(path: fixturePath("Geneva.ttf"), ptSize: 18, pixelDensity: 1)
        defer { font.destroy() }
        #expect(font.renderScale == 1.0)
        // SDL_ttf rasterizes at the same ptSize — no scaling.
        #expect(TTF_GetFontSize(font.handle) == 18.0)
    }

    @Test func fontWithDensity2RasterizesAtDoubleResolution() throws {
        let app = try App(title: "font-scale-2x", width: 64, height: 64)
        defer { app.destroy() }
        let font = try Font(path: fixturePath("Geneva.ttf"), ptSize: 18, pixelDensity: 2)
        defer { font.destroy() }
        // renderScale shrinks glyph quads back to logical size.
        #expect(font.renderScale == 0.5)
        // SDL_ttf must open at 2× ptSize so the atlas glyph is native-resolution.
        #expect(TTF_GetFontSize(font.handle) == 36.0)
    }

    @Test func drawTextEmitsAtLeastOneQuadPerGlyph() throws {
        let app = try App(title: "font-draw", width: 64, height: 64)
        defer { app.destroy() }
        let engine = try TextEngine(on: app.renderer)
        defer { engine.destroy() }
        let font = try Font(path: fixturePath("Geneva.ttf"), ptSize: 18)
        defer { font.destroy() }
        let b = Batcher()
        let d = Draw(batcher: b, textEngine: engine)
        d.text("Hi", font: font, at: SIMD2<Float>(0, 0), color: .white)
        // Each glyph contributes 6 vertices.
        #expect(b.vertices.count >= 12)
    }
}
