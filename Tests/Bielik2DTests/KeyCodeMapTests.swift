import Testing
@testable import Bielik2D

// Pure mapping tests: KeyboardEvent.code strings → Key, no browser involved.

@Test func browserCodeMapsArrows() {
    #expect(Key(browserCode: "ArrowLeft") == .left)
    #expect(Key(browserCode: "ArrowRight") == .right)
    #expect(Key(browserCode: "ArrowUp") == .up)
    #expect(Key(browserCode: "ArrowDown") == .down)
}

@Test func browserCodeMapsLetters() {
    #expect(Key(browserCode: "KeyQ") == .q)
    #expect(Key(browserCode: "KeyE") == .e)
    #expect(Key(browserCode: "KeyW") == .w)
    #expect(Key(browserCode: "KeyA") == .a)
    #expect(Key(browserCode: "KeyS") == .s)
    #expect(Key(browserCode: "KeyD") == .d)
    #expect(Key(browserCode: "KeyF") == .f)
}

@Test func browserCodeMapsSpace() {
    #expect(Key(browserCode: "Space") == .space)
}

@Test func browserCodeReturnsNilForUnknown() {
    #expect(Key(browserCode: "Nonsense") == nil)
}
