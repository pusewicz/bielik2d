import Testing
@testable import Bielik2D

private func approx(_ a: Float, _ b: Float) -> Bool { abs(a - b) < 1e-5 }

@Test func placementMapsImageToItsAtlasSubRect() {
    // 30×20 image, packed at slot (10,10) with a 1px gutter on a 256×256 page.
    // The image's pixels therefore start at (11,11).
    let p = Placement.compute(slotX: 10, slotY: 10, imageW: 30, imageH: 20,
                              pageW: 256, pageH: 256, gutter: 1, page: 0)
    let P: Float = 256
    #expect(p.page == 0)
    #expect(approx(p.uvRect.x, 11 / P))
    #expect(approx(p.uvRect.y, 11 / P))
    #expect(approx(p.uvRect.width, 30 / P))
    #expect(approx(p.uvRect.height, 20 / P))
}

@Test func placementInsetsUVBoundsByHalfATexel() {
    let p = Placement.compute(slotX: 10, slotY: 10, imageW: 30, imageH: 20,
                              pageW: 256, pageH: 256, gutter: 1, page: 0)
    let P: Float = 256
    let half = 0.5 / P
    #expect(approx(p.uvBounds.x, 11 / P + half))   // minU
    #expect(approx(p.uvBounds.y, 11 / P + half))   // minV
    #expect(approx(p.uvBounds.z, 41 / P - half))   // maxU = (11+30)/P
    #expect(approx(p.uvBounds.w, 31 / P - half))   // maxV = (11+20)/P
}
