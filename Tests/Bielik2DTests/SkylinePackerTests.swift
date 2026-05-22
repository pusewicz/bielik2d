import Testing
@testable import Bielik2D

@Test func firstInsertGoesToOrigin() {
    var p = SkylinePacker(width: 64, height: 64)
    let pos = p.insert(width: 10, height: 10)
    #expect(pos?.x == 0)
    #expect(pos?.y == 0)
}

@Test func secondInsertSitsBesideTheFirst() {
    var p = SkylinePacker(width: 64, height: 64)
    _ = p.insert(width: 10, height: 10)
    let pos = p.insert(width: 10, height: 10)
    #expect(pos?.x == 10)
    #expect(pos?.y == 0)
}

@Test func tooBigToFitReturnsNil() {
    var p = SkylinePacker(width: 32, height: 32)
    #expect(p.insert(width: 33, height: 8) == nil)
    #expect(p.insert(width: 8, height: 33) == nil)
}

@Test func overflowAfterFillingReturnsNil() {
    var p = SkylinePacker(width: 16, height: 16)
    #expect(p.insert(width: 16, height: 16) != nil)  // fills the page
    #expect(p.insert(width: 1, height: 1) == nil)    // nothing left
}

@Test func wrapsToANewRowWhenWidthIsExhausted() {
    var p = SkylinePacker(width: 20, height: 64)
    _ = p.insert(width: 12, height: 10)         // (0, 0)
    let pos = p.insert(width: 12, height: 10)   // won't fit beside it (12+12 > 20)
    #expect(pos?.x == 0)
    #expect(pos?.y == 10)
}

@Test func placementsNeverOverlapAndStayInBounds() {
    var p = SkylinePacker(width: 128, height: 128)
    let sizes = [(20, 20), (33, 10), (15, 40), (50, 12), (8, 8), (40, 40), (10, 30), (25, 25)]
    var placed: [(x: Int, y: Int, w: Int, h: Int)] = []
    for (w, h) in sizes {
        guard let pos = p.insert(width: w, height: h) else { continue }
        #expect(pos.x >= 0 && pos.y >= 0)
        #expect(pos.x + w <= 128)
        #expect(pos.y + h <= 128)
        for r in placed {
            let disjoint = pos.x + w <= r.x || r.x + r.w <= pos.x
                || pos.y + h <= r.y || r.y + r.h <= pos.y
            #expect(disjoint, "rect (\(pos.x),\(pos.y),\(w),\(h)) overlaps (\(r.x),\(r.y),\(r.w),\(r.h))")
        }
        placed.append((pos.x, pos.y, w, h))
    }
    #expect(placed.count == sizes.count)
}
