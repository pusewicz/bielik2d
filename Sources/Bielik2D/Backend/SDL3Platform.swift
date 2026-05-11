#if canImport(CSDL3)
import CSDL3

/// Owns the SDL3 process-global state (init, window, event pump) so `App`
/// can be retargeted at a different platform impl later without rewriting
/// the lifecycle plumbing.
public final class SDL3Platform {
    public private(set) var windowHandle: OpaquePointer?
    public private(set) var size: SIMD2<Int>
    public private(set) var shouldQuit: Bool = false
    private var keysJustPressed: Set<UInt32> = []

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
        keysJustPressed.removeAll(keepingCapacity: true)
        var ev = SDL_Event()
        while SDL_PollEvent(&ev) {
            switch SDL_EventType(rawValue: ev.type) {
            case SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                shouldQuit = true
            case SDL_EVENT_KEY_DOWN:
                if !ev.key.repeat {
                    keysJustPressed.insert(ev.key.scancode.rawValue)
                }
            default:
                break
            }
        }
    }

    public func keyJustPressed(_ scancode: UInt32) -> Bool {
        keysJustPressed.contains(scancode)
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
