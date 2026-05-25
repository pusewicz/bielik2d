import Testing
@testable import Bielik2D

// Pure device-layer tests: no SDL, just synthetic motion/scroll/button sequences.

@Test func mouseTracksPositionAndAccumulatesDeltaPerFrame() {
    let m = Mouse()
    m.beginFrame()
    m.moved(to: SIMD2(10, 20), relative: SIMD2(10, 20))
    m.moved(to: SIMD2(13, 18), relative: SIMD2(3, -2))
    #expect(m.position == SIMD2<Float>(13, 18))
    #expect(m.delta == SIMD2<Float>(13, 18))  // 10+3, 20-2
    m.beginFrame()
    #expect(m.delta == SIMD2<Float>.zero)       // delta resets each frame
    #expect(m.position == SIMD2<Float>(13, 18)) // position persists
}

@Test func mouseWheelAccumulatesPerFrameThenResets() {
    let m = Mouse()
    m.beginFrame()
    m.scrolled(SIMD2(0, 1))
    m.scrolled(SIMD2(0, 2))
    #expect(m.wheel == SIMD2<Float>(0, 3))
    m.beginFrame()
    #expect(m.wheel == SIMD2<Float>.zero)
}

@Test func mouseButtonPressedReleasedTrackTransitions() {
    let m = Mouse()
    m.beginFrame()
    m.press(.left)
    #expect(m.pressed(.left))
    #expect(m.down(.left))
    m.beginFrame()
    #expect(!m.pressed(.left))  // no longer a fresh press
    #expect(m.down(.left))       // still held
    m.beginFrame()
    m.release(.left)
    #expect(m.released(.left))
    #expect(!m.down(.left))
}
