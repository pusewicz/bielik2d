import Testing
@testable import Bielik2D

@Test func nilScissorIsFullTarget() {
    let s = scissorPixelRect(nil, scale: 1, targetW: 800, targetH: 600)
    #expect(s.x == 0 && s.y == 0 && s.w == 800 && s.h == 600)
}

@Test func scissorScalesByDensity() {
    let s = scissorPixelRect(Rect(x: 10, y: 20, width: 100, height: 50),
                             scale: 2, targetW: 1000, targetH: 1000)
    #expect(s.x == 20 && s.y == 40 && s.w == 200 && s.h == 100)
}

@Test func scissorClampsToTargetBounds() {
    // Rect extends past the 100×100 target and starts negative -> clamped into [0,100].
    let s = scissorPixelRect(Rect(x: -20, y: -20, width: 200, height: 200),
                             scale: 1, targetW: 100, targetH: 100)
    #expect(s.x == 0 && s.y == 0 && s.w == 100 && s.h == 100)
}

@Test func nilViewportIsFullTarget() {
    let v = viewportPixelRect(nil, scale: 1, targetW: 640, targetH: 480)
    #expect(v.x == 0 && v.y == 0 && v.w == 640 && v.h == 480)
}

@Test func viewportScalesByDensity() {
    let v = viewportPixelRect(Rect(x: 10, y: 5, width: 100, height: 80),
                              scale: 2, targetW: 1000, targetH: 1000)
    #expect(v.x == 20 && v.y == 10 && v.w == 200 && v.h == 160)
}
