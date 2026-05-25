#if canImport(CSDL3)
import CSDL3

/// Owns the SDL3 process-global state (init, window, event pump) so `App`
/// can be retargeted at a different platform impl later without rewriting
/// the lifecycle plumbing.
public final class SDL3Platform {
    public private(set) var windowHandle: OpaquePointer?
    public private(set) var size: SIMD2<Int>
    public private(set) var shouldQuit: Bool = false
    public let input = Input()

    private init(window: OpaquePointer, size: SIMD2<Int>) {
        self.windowHandle = window
        self.size = size
    }

    public static func start(title: String, width: Int, height: Int) throws -> SDL3Platform {
        guard SDL_Init(SDL_INIT_VIDEO) else {
            throw AppError.sdlInit(lastSDLError())
        }
        guard let win = SDL_CreateWindow(title, Int32(width), Int32(height), SDL_WINDOW_HIGH_PIXEL_DENSITY) else {
            SDL_Quit()
            throw AppError.createWindow(lastSDLError())
        }
        return SDL3Platform(window: win, size: SIMD2(width, height))
    }

    public func pollEvents() {
        input.beginFrame()
        var ev = SDL_Event()
        while SDL_PollEvent(&ev) {
            switch SDL_EventType(rawValue: ev.type) {
            case SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                shouldQuit = true
            case SDL_EVENT_KEY_DOWN:
                if !ev.key.repeat, let key = Key(scancode: ev.key.scancode) {
                    input.keyboard.press(key)
                }
            case SDL_EVENT_KEY_UP:
                if let key = Key(scancode: ev.key.scancode) {
                    input.keyboard.release(key)
                }
            case SDL_EVENT_MOUSE_MOTION:
                input.mouse.moved(
                    to: SIMD2(ev.motion.x, ev.motion.y),
                    relative: SIMD2(ev.motion.xrel, ev.motion.yrel))
            case SDL_EVENT_MOUSE_BUTTON_DOWN:
                if let button = Self.mouseButton(ev.button.button) {
                    input.mouse.press(button)
                }
            case SDL_EVENT_MOUSE_BUTTON_UP:
                if let button = Self.mouseButton(ev.button.button) {
                    input.mouse.release(button)
                }
            case SDL_EVENT_MOUSE_WHEEL:
                input.mouse.scrolled(SIMD2(ev.wheel.x, ev.wheel.y))
            default:
                break
            }
        }
    }

    private static func mouseButton(_ raw: UInt8) -> MouseButton? {
        switch Int32(raw) {
        case SDL_BUTTON_LEFT: .left
        case SDL_BUTTON_MIDDLE: .middle
        case SDL_BUTTON_RIGHT: .right
        case SDL_BUTTON_X1: .x1
        case SDL_BUTTON_X2: .x2
        default: nil
        }
    }

    public func stop() {
        if let win = windowHandle {
            SDL_DestroyWindow(win)
            windowHandle = nil
        }
        SDL_Quit()
    }
}
#endif
