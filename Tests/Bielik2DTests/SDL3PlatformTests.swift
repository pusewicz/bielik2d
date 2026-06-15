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

    @Test func hiDPIInvariantsHold() throws {
        let platform = try SDL3Platform.start(title: "hidpi invariants", width: 320, height: 200)
        defer { platform.stop() }
        // Pixel size must be at least as large as logical size on any display.
        #expect(platform.sizeInPixels.x >= platform.size.x)
        #expect(platform.sizeInPixels.y >= platform.size.y)
        // Pixel density must be ≥ 1.0 on any real display.
        #expect(platform.pixelDensity >= 1.0)
        // Density must approximately match the ratio of pixel to logical width.
        let ratio = Float(platform.sizeInPixels.x) / Float(platform.size.x)
        #expect(abs(platform.pixelDensity - ratio) < 0.05)
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

    @Test func mouseEventsReachInput() throws {
        let platform = try SDL3Platform.start(title: "platform mouse", width: 64, height: 64)
        defer { platform.stop() }

        var motion = SDL_Event()
        motion.type = SDL_EVENT_MOUSE_MOTION.rawValue
        motion.motion.x = 12
        motion.motion.y = 34
        motion.motion.xrel = 5
        motion.motion.yrel = 6
        _ = SDL_PushEvent(&motion)

        var wheel = SDL_Event()
        wheel.type = SDL_EVENT_MOUSE_WHEEL.rawValue
        wheel.wheel.x = 0
        wheel.wheel.y = 2
        _ = SDL_PushEvent(&wheel)

        var button = SDL_Event()
        button.type = SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue
        button.button.button = UInt8(SDL_BUTTON_LEFT)
        button.button.down = true
        _ = SDL_PushEvent(&button)

        platform.pollEvents()
        #expect(platform.input.mouse.position == SIMD2<Float>(12, 34))
        #expect(platform.input.mouse.delta == SIMD2<Float>(5, 6))
        #expect(platform.input.mouse.wheel == SIMD2<Float>(0, 2))
        #expect(platform.input.mouse.pressed(.left))
    }
}
