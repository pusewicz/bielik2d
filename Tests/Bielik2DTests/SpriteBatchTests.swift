import AppKit
import Foundation
import Testing
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct SpriteBatchTests {
    init() { _ = NSApplication.shared }

    private func solid(_ w: Int, _ h: Int, _ rgba: [UInt8] = [255, 255, 255, 255]) -> ImageBytes {
        var px = [UInt8]()
        px.reserveCapacity(w * h * 4)
        for _ in 0..<(w * h) { px.append(contentsOf: rgba) }
        return ImageBytes(width: w, height: h, pixels: Data(px))
    }

    private func instance(_ id: SpriteID, layer: Int = 0) -> SpriteInstance {
        SpriteInstance(id: id, p0: .zero, p1: SIMD2(1, 0), p2: SIMD2(1, 1), p3: SIMD2(0, 1),
                       color: .one, scaleData: .zero, layer: layer)
    }

    @Test func defragPacksTwoSmallImagesOntoOnePage() throws {
        let app = try App(title: "sb1", width: 64, height: 64); defer { app.destroy() }
        let sb = SpriteBatch(device: app.gpu, pageSize: 256)
        let a = sb.register(solid(4, 4))
        let b = sb.register(solid(8, 8))
        try sb.defrag(used: [a, b])
        #expect(sb.pages.count == 1)
        #expect(sb.placement(of: a)?.page == 0)
        #expect(sb.placement(of: b)?.page == 0)
    }

    @Test func defragGivesAnOversizedImageItsOwnPage() throws {
        let app = try App(title: "sb2", width: 64, height: 64); defer { app.destroy() }
        let sb = SpriteBatch(device: app.gpu, pageSize: 16)
        let big = sb.register(solid(20, 8))   // wider than a standard page
        try sb.defrag(used: [big])
        #expect(sb.pages.count == 1)
        #expect(sb.pages[0].width >= 20)
    }

    @Test func defragOpensASecondPageWhenAPageIsFull() throws {
        let app = try App(title: "sb3", width: 64, height: 64); defer { app.destroy() }
        let sb = SpriteBatch(device: app.gpu, pageSize: 16)
        // 7×7 raw → 9×9 padded; two of them can't share a 16×16 page.
        let a = sb.register(solid(7, 7))
        let b = sb.register(solid(7, 7))
        try sb.defrag(used: [a, b])
        #expect(sb.pages.count == 2)
    }

    @Test func defragLeavesAlreadyResidentImagesUntouched() throws {
        let app = try App(title: "sb4", width: 64, height: 64); defer { app.destroy() }
        let sb = SpriteBatch(device: app.gpu, pageSize: 256)
        let a = sb.register(solid(4, 4))
        try sb.defrag(used: [a])
        let first = sb.placement(of: a)
        try sb.defrag(used: [a])   // a is already resident — a no-op
        #expect(sb.pages.count == 1)
        #expect(sb.placement(of: a) == first)
    }

    @Test func resolveEmitsAtlasQuadsAndMergesSamePage() throws {
        let app = try App(title: "sb5", width: 64, height: 64); defer { app.destroy() }
        let sb = SpriteBatch(device: app.gpu, pageSize: 256)
        let a = sb.register(solid(4, 4))
        let b = sb.register(solid(4, 4))
        try sb.defrag(used: [a, b])

        let batcher = Batcher()
        sb.resolve([instance(a), instance(b)], into: batcher)

        #expect(batcher.commands.count == 1)        // same page → one draw call
        #expect(batcher.vertices.count == 12)
        let pa = sb.placement(of: a)!
        #expect(batcher.vertices[0].uv == SIMD2(pa.uvRect.minX, pa.uvRect.minY))
        #expect(batcher.vertices[0].uvBounds == pa.uvBounds)
        #expect(pa.uvRect.minX > 0)                  // not the full-texture [0,1] uv
    }
}
