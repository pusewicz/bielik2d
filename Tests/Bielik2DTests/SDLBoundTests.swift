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
}
