import Testing
import CSDL3

@Test func sdl3CanInitAndQuitVideo() {
    _ = SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "dummy")
    let ok = SDL_Init(SDL_INIT_VIDEO)
    if !ok, let cstr = SDL_GetError() {
        Issue.record("SDL_Init failed: \(String(cString: cstr))")
    }
    #expect(ok)
    SDL_Quit()
}

@Test func sdl3ImageHasVersion() {
    let v = IMG_Version()
    #expect(v >= 3_000_000)
}

@Test func sdl3TtfHasVersion() {
    let v = TTF_Version()
    #expect(v >= 3_000_000)
}
