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

    @Test func density2FontProducesLogicalSizeQuads() throws {
        // A 2× font should generate quads scaled back to logical size — half the raw
        // atlas coords — so text occupies the same logical area as a 1× font.
        let app = try App(title: "font-scale-quads", width: 64, height: 64)
        defer { app.destroy() }
        let engine = try TextEngine(on: app.renderer)
        defer { engine.destroy() }
        let font1x = try Font(path: fixturePath("Geneva.ttf"), ptSize: 18, pixelDensity: 1)
        defer { font1x.destroy() }
        let font2x = try Font(path: fixturePath("Geneva.ttf"), ptSize: 18, pixelDensity: 2)
        defer { font2x.destroy() }
        let b1 = Batcher()
        let b2 = Batcher()
        Draw(batcher: b1, textEngine: engine).text("H", font: font1x, at: .zero)
        Draw(batcher: b2, textEngine: engine).text("H", font: font2x, at: .zero)
        // Both fonts should produce quads of approximately the same logical extent.
        // Compare the x-range of generated vertices (max - min).
        let xs1 = b1.vertices.map(\.pos.x)
        let xs2 = b2.vertices.map(\.pos.x)
        guard !xs1.isEmpty, !xs2.isEmpty else {
            Issue.record("expected vertices from both fonts"); return
        }
        let range1 = xs1.max()! - xs1.min()!
        let range2 = xs2.max()! - xs2.min()!
        // Allow ±20% for rounding differences between font sizes.
        #expect(abs(range1 - range2) < range1 * 0.20,
                "1× range \(range1) and 2× range \(range2) should be similar")
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
