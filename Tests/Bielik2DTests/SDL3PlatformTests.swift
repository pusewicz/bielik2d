import AppKit
import Testing
import CSDL3
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct SDL3PlatformTests {
    init() { _ = NSApplication.shared }

    @Test func startReturnsPlatformWithRequestedSize() throws {
        let platform = try SDL3Platform.start(title: "platform test", width: 320, height: 200)
        defer { platform.stop() }
        #expect(platform.size == SIMD2<Int>(320, 200))
        #expect(platform.windowHandle != nil)
        #expect(!platform.shouldQuit)
    }

    @Test func pollEventsFlipsShouldQuitOnQuitEvent() throws {
        let platform = try SDL3Platform.start(title: "platform quit", width: 64, height: 64)
        defer { platform.stop() }
        var ev = SDL_Event()
        ev.type = SDL_EVENT_QUIT.rawValue
        _ = SDL_PushEvent(&ev)
        platform.pollEvents()
        #expect(platform.shouldQuit)
    }

    @Test func keyDownRegistersAsJustPressedThenClears() throws {
        let platform = try SDL3Platform.start(title: "platform keys", width: 64, height: 64)
        defer { platform.stop() }
        var ev = SDL_Event()
        ev.type = SDL_EVENT_KEY_DOWN.rawValue
        ev.key.scancode = SDL_SCANCODE_A
        ev.key.down = true
        ev.key.repeat = false
        _ = SDL_PushEvent(&ev)
        platform.pollEvents()
        #expect(platform.keyJustPressed(SDL_SCANCODE_A.rawValue))
        platform.pollEvents()
        #expect(!platform.keyJustPressed(SDL_SCANCODE_A.rawValue))
    }
}
