import Foundation
import Testing
@testable import Bielik2D

// A registrar that just hands out incrementing ids and remembers what it was given,
// so registry tests need no GPU/atlas.
private final class FakeRegistrar: ImageRegistrar {
    private(set) var images: [ImageBytes] = []
    func register(_ image: ImageBytes) -> SpriteID {
        images.append(image)
        return images.count - 1
    }
    var count: Int { images.count }
}

private func solid(_ w: Int, _ h: Int) -> ImageBytes {
    ImageBytes(width: w, height: h, pixels: Data(repeating: 255, count: w * h * 4))
}

@Test func staticAssetHasOneFrameMatchingTheImage() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let asset = reg.asset(reg.makeStaticAsset(solid(4, 6)))
    #expect(asset.animations.count == 1)
    #expect(asset.animations[0].frames.count == 1)
    #expect(asset.animations[0].frames[0].width == 4)
    #expect(asset.animations[0].frames[0].height == 6)
}

@Test func loadingTheSamePathReusesOneAsset() throws {
    let fake = FakeRegistrar()
    var loads = 0
    let reg = SpriteRegistry(registrar: fake) { _ in loads += 1; return solid(2, 2) }
    let a = try reg.loadAsset(path: "hero.png")
    let b = try reg.loadAsset(path: "hero.png")
    #expect(a == b)            // same asset id
    #expect(loads == 1)        // disk read happened exactly once
    #expect(fake.count == 1)   // registered exactly once
}

@Test func differentPathsProduceDistinctAssets() throws {
    let reg = SpriteRegistry(registrar: FakeRegistrar()) { _ in solid(1, 1) }
    let a = try reg.loadAsset(path: "a.png")
    let b = try reg.loadAsset(path: "b.png")
    #expect(a != b)
}

@Test func sheetSlicesIntoOneLoopingAnimationOfFrames() {
    let fake = FakeRegistrar()
    let reg = SpriteRegistry(registrar: fake)
    // 8×8 sheet, 4×4 cells → 4 frames (2 cols × 2 rows), row-major.
    let id = reg.makeSheetAsset(solid(8, 8), frameWidth: 4, frameHeight: 4, fps: 10)
    let anim = reg.asset(id).animations[0]
    #expect(reg.asset(id).animations.count == 1)
    #expect(anim.mode == .loop)
    #expect(anim.frames.count == 4)
    #expect(anim.frames[0].width == 4)
    #expect(anim.frames[0].height == 4)
    #expect(anim.frames[0].duration == 0.1)   // 1 / fps
    #expect(fake.count == 4)                   // every frame registered
}
