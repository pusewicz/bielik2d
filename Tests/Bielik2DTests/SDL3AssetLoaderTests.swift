import AppKit
import Foundation
import Testing
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct SDL3AssetLoaderTests {
    init() { _ = NSApplication.shared }

    private func fixturePath(_ name: String) -> String {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "fixtures")!.path
    }

    @Test func loadImageDecodesPNGToRGBA() throws {
        let image = try SDL3AssetLoader.loadImage(path: fixturePath("4x4.png"))
        #expect(image.width == 4)
        #expect(image.height == 4)
        #expect(image.pixels.count == 4 * 4 * 4)
    }

    @Test func cachePrefetchMakesImageResident() async throws {
        let path = fixturePath("4x4.png")
        let cache = SDL3AssetCache()
        #expect(cache.image(path) == nil)

        try await cache.prefetch([path])

        let image = cache.image(path)
        #expect(image != nil)
        #expect(image?.width == 4)
        #expect(image?.height == 4)
        #expect(image?.rgba.count == 4 * 4 * 4)
    }
}
