import AppKit
import Testing
import CSDL3
@testable import Bielik2D

/// All tests that touch SDL global state run serially on the main actor.
/// SDL_Init/SDL_Quit are process-global, and SDL3's cocoa video driver needs
/// NSApplication.shared, which only exists if we touch AppKit on the main thread.
@Suite(.serialized)
@MainActor
struct SDLBoundTests {
    init() {
        _ = NSApplication.shared
    }

    @Test func canInitAndQuitVideo() {
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
        let app = try App(title: "test", width: 320, height: 200)
        #expect(app.isRunning)
        app.destroy()
    }

    @Test func gpuDeviceClaimsAppWindow() throws {
        let app = try App(title: "gpu test", width: 320, height: 200)
        defer { app.destroy() }
        #expect(app.gpu.driverName.isEmpty == false)
    }

    @Test func appUpdateStopsRunningOnQuitEvent() throws {
        let app = try App(title: "quit test", width: 320, height: 200)
        defer { app.destroy() }
        #expect(app.isRunning)
        var ev = SDL_Event()
        ev.type = SDL_EVENT_QUIT.rawValue
        _ = SDL_PushEvent(&ev)
        app.update()
        #expect(!app.isRunning)
    }

    @Test func keyDownEventReachesAppInput() throws {
        let app = try App(title: "key test", width: 320, height: 200)
        defer { app.destroy() }
        var ev = SDL_Event()
        ev.type = SDL_EVENT_KEY_DOWN.rawValue
        ev.key.scancode = SDL_SCANCODE_SPACE
        ev.key.down = true
        ev.key.repeat = false
        _ = SDL_PushEvent(&ev)
        app.update()
        #expect(app.input.keyboard.pressed(.space))
        // a second update without a new event clears the fresh-press flag
        app.update()
        #expect(!app.input.keyboard.pressed(.space))
        #expect(app.input.keyboard.down(.space))  // still held
    }
}
