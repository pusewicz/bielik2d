import Testing
import CSDL3
@testable import Bielik2D

/// All tests that touch SDL global state run serially in one suite.
/// SDL_Init/SDL_Quit are process-global, so parallel tests collide.
@Suite(.serialized)
struct SDLBoundTests {
    @Test func canInitAndQuitVideo() {
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

    @Test func appLifecycleRoundtrips() throws {
        _ = SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "dummy")
        let app = try App(title: "test", width: 320, height: 200)
        #expect(app.isRunning)
        app.destroy()
    }
}
