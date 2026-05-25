import Testing
@testable import Bielik2D

// Pure device-layer tests: no SDL, just synthetic press/release/beginFrame sequences.

@Test func keyIsDownWhileHeld() {
    let kb = Keyboard()
    kb.beginFrame()
    kb.press(.a)
    #expect(kb.down(.a))
    #expect(!kb.down(.b))
}

@Test func keyPressedOnlyOnTheTransitionFrame() {
    let kb = Keyboard()
    kb.beginFrame()
    kb.press(.space)
    #expect(kb.pressed(.space))   // up → down this frame
    kb.beginFrame()               // next frame, still held
    #expect(!kb.pressed(.space))  // no longer a fresh press
    #expect(kb.down(.space))
}

@Test func keyReleasedOnlyOnTheReleaseFrame() {
    let kb = Keyboard()
    kb.beginFrame()
    kb.press(.escape)
    kb.beginFrame()
    kb.release(.escape)
    #expect(kb.released(.escape))
    #expect(!kb.down(.escape))
    kb.beginFrame()
    #expect(!kb.released(.escape))
}

@Test func modifiersReflectHeldModifierKeys() {
    let kb = Keyboard()
    kb.beginFrame()
    kb.press(.leftShift)
    kb.press(.rightCommand)
    #expect(kb.modifiers.contains(.shift))
    #expect(kb.modifiers.contains(.command))
    #expect(!kb.modifiers.contains(.control))
}
