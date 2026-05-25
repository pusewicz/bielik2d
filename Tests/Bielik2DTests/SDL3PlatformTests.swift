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

    @Test func keyDownEventMarksKeyPressedThenHeld() throws {
        let platform = try SDL3Platform.start(title: "platform keys", width: 64, height: 64)
        defer { platform.stop() }
        var ev = SDL_Event()
        ev.type = SDL_EVENT_KEY_DOWN.rawValue
        ev.key.scancode = SDL_SCANCODE_A
        ev.key.down = true
        ev.key.repeat = false
        _ = SDL_PushEvent(&ev)
        platform.pollEvents()
        #expect(platform.input.keyboard.pressed(.a))
        #expect(platform.input.keyboard.down(.a))
        platform.pollEvents()
        #expect(!platform.input.keyboard.pressed(.a))  // no longer a fresh press
        #expect(platform.input.keyboard.down(.a))       // but still held
    }

    @Test func keyUpEventReleasesHeldKey() throws {
        let platform = try SDL3Platform.start(title: "platform keyup", width: 64, height: 64)
        defer { platform.stop() }
        var down = SDL_Event()
        down.type = SDL_EVENT_KEY_DOWN.rawValue
        down.key.scancode = SDL_SCANCODE_SPACE
        down.key.down = true
        down.key.repeat = false
        _ = SDL_PushEvent(&down)
        platform.pollEvents()
        #expect(platform.input.keyboard.down(.space))

        var up = SDL_Event()
        up.type = SDL_EVENT_KEY_UP.rawValue
        up.key.scancode = SDL_SCANCODE_SPACE
        up.key.down = false
        _ = SDL_PushEvent(&up)
        platform.pollEvents()
        #expect(platform.input.keyboard.released(.space))
        #expect(!platform.input.keyboard.down(.space))
    }

    @Test func keyRoundTripsThroughScancode() {
        for key in Key.allCases {
            #expect(Key(scancode: key.scancode) == key)
        }
    }
}
