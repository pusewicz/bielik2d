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

@Test func aSpriteCachesItsCurrentFrameSize() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let s = Sprite(asset: reg.makeStaticAsset(solid(5, 7)), in: reg)
    #expect(s.width == 5)
    #expect(s.height == 7)
}

@Test func updatingAnAnimatedSpriteAdvancesItsCachedFrame() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let id = reg.makeSheetAsset(solid(8, 4), frameWidth: 4, frameHeight: 4, fps: 10)  // 2 frames @0.1s
    var s = Sprite(asset: id, in: reg)
    let frame0 = s.imageID
    s.update(0.1, in: reg)
    #expect(s.imageID != frame0)   // now showing frame 1's image
}

@Test func updatingAStaticSpriteIsANoOp() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    var s = Sprite(asset: reg.makeStaticAsset(solid(4, 4)), in: reg)
    let before = s.imageID
    s.update(100, in: reg)
    #expect(s.imageID == before)
}

@Test func aPausedSpriteDoesNotAdvance() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let id = reg.makeSheetAsset(solid(8, 4), frameWidth: 4, frameHeight: 4, fps: 10)
    var s = Sprite(asset: id, in: reg)
    let before = s.imageID
    s.pause()
    s.update(1.0, in: reg)
    #expect(s.imageID == before)
}

@Test func playRestartsTheNamedAnimation() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let id = reg.makeSheetAsset(solid(8, 4), frameWidth: 4, frameHeight: 4, fps: 10)
    var s = Sprite(asset: id, in: reg)
    s.update(0.1, in: reg)        // advance off frame 0
    s.play("default", in: reg)    // restart
    #expect(s.imageID == reg.asset(id).animations[0].frames[0].imageID)
}

@Test func playingAnUnknownAnimationIsIgnored() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let id = reg.makeSheetAsset(solid(8, 4), frameWidth: 4, frameHeight: 4, fps: 10)
    var s = Sprite(asset: id, in: reg)
    s.update(0.1, in: reg)
    let onFrame1 = s.imageID
    s.play("walk", in: reg)       // no such animation
    #expect(s.imageID == onFrame1)
}

@Test func twoSpritesOfOneSheetShareTheAssetButPlayIndependently() throws {
    let fake = FakeRegistrar()
    let reg = SpriteRegistry(registrar: fake) { _ in solid(8, 4) }  // a 2-frame sheet
    var a = try reg.sprite(sheet: "enemy.png", frameWidth: 4, frameHeight: 4, fps: 10)
    var b = try reg.sprite(sheet: "enemy.png", frameWidth: 4, frameHeight: 4, fps: 10)

    #expect(a.asset == b.asset)   // same shared asset — one atlas footprint, deduped
    #expect(fake.count == 2)      // sliced/registered once (2 frames), not 4

    b.pause()
    a.update(0.1, in: reg)        // only a advances
    b.update(0.1, in: reg)        // b is paused — no-op
    #expect(a.frame == 1)
    #expect(b.frame == 0)         // fully independent playback
    #expect(a.imageID != b.imageID)
}

@Test func settingTheFrameJumpsToItAndCachesIt() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let id = reg.makeSheetAsset(solid(12, 4), frameWidth: 4, frameHeight: 4, fps: 10)  // 3 frames
    var s = Sprite(asset: id, in: reg)
    s.setFrame(2, in: reg)
    #expect(s.frame == 2)
    #expect(s.imageID == reg.asset(id).animations[0].frames[2].imageID)
}

@Test func settingTheFrameClampsIntoRange() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    let id = reg.makeSheetAsset(solid(12, 4), frameWidth: 4, frameHeight: 4, fps: 10)  // 3 frames
    var s = Sprite(asset: id, in: reg)
    s.setFrame(99, in: reg)
    #expect(s.frame == 2)   // clamped to the last frame
}

@Test func anInMemorySheetMakesAnAnimatedSprite() {
    let reg = SpriteRegistry(registrar: FakeRegistrar())
    var s = reg.makeSprite(sheet: solid(8, 4), frameWidth: 4, frameHeight: 4, fps: 10)  // 2 frames
    let frame0 = s.imageID
    s.update(0.1, in: reg)
    #expect(s.imageID != frame0)
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
