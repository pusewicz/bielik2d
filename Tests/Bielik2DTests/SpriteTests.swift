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

    @Test func loadPNGFromFixtureHasKnownSize() throws {
        let app = try App(title: "spr-load", width: 64, height: 64)
        defer { app.destroy() }
        let s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        #expect(s.width == 4)
        #expect(s.height == 4)
    }

    @Test func drawSpriteRecordsOneDeferredInstance() throws {
        let app = try App(title: "spr-draw", width: 64, height: 64)
        defer { app.destroy() }
        let s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        let b = Batcher()
        let d = Draw(batcher: b)
        d.sprite(s, at: SIMD2<Float>(10, 20))
        // Deferred: nothing hits the batcher until the renderer resolves the atlas.
        #expect(b.vertices.isEmpty)
        #expect(d.spriteInstances.count == 1)
        let inst = d.spriteInstances[0]
        #expect(inst.p0 == SIMD2<Float>(10, 20))           // top-left at the draw point
        #expect(inst.p2 == SIMD2<Float>(10 + 4, 20 + 4))   // bottom-right = native size
    }

    @Test func spriteDefaultsToInheritScaleMode() throws {
        let app = try App(title: "spr-mode", width: 64, height: 64)
        defer { app.destroy() }
        let s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        // nil means "inherit the ambient Draw scale mode".
        #expect(s.scaleMode == nil)
    }

    @Test func pixelArtSpritePacksTexelSizeIntoTheInstance() throws {
        let app = try App(title: "spr-pa", width: 64, height: 64)
        defer { app.destroy() }
        var s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        s.scaleMode = .pixelArt
        let d = Draw(batcher: Batcher())
        d.sprite(s, at: .zero)
        // texelW, texelH = native size; mode 1 = pixelArt.
        #expect(d.spriteInstances.first?.scaleData == SIMD4<Float>(4, 4, 1, 0))
    }

    @Test func spritePropertyUsedWhenNoArgOrPush() throws {
        let app = try App(title: "spr-prop", width: 64, height: 64)
        defer { app.destroy() }
        var s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        s.scaleMode = .nearest
        let d = Draw(batcher: Batcher())
        d.sprite(s, at: .zero)
        #expect(d.spriteInstances.first?.scaleData == SIMD4<Float>(4, 4, 2, 0))
    }

    @Test func perCallArgOverridesSpriteProperty() throws {
        let app = try App(title: "spr-arg", width: 64, height: 64)
        defer { app.destroy() }
        var s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        s.scaleMode = .pixelArt
        let d = Draw(batcher: Batcher())
        d.sprite(s, at: .zero, scaleMode: .nearest)
        #expect(d.spriteInstances.first?.scaleData == SIMD4<Float>(4, 4, 2, 0))
    }

    @Test func ambientUsedWhenSpriteModeNil() throws {
        let app = try App(title: "spr-amb", width: 64, height: 64)
        defer { app.destroy() }
        let s = try Sprite(png: fixturePath("4x4.png"), on: app.renderer)
        let d = Draw(batcher: Batcher())
        d.pushScaleMode(.pixelArt)
        d.sprite(s, at: .zero)
        #expect(d.spriteInstances.first?.scaleData == SIMD4<Float>(4, 4, 1, 0))
    }
}
