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

    @Test func drawTextEmitsAtLeastOneQuadPerGlyph() throws {
        let app = try App(title: "font-draw", width: 64, height: 64)
        defer { app.destroy() }
        let engine = try TextEngine(on: app.gpu)
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
