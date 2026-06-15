#if canImport(CSDL3)
import CSDL3

/// Owns the SDL3 process-global state (init, window, event pump) so `App`
/// can be retargeted at a different platform impl later without rewriting
/// the lifecycle plumbing.
public final class SDL3Platform {
    public private(set) var windowHandle: OpaquePointer?
    /// Logical window size in points — use this for game logic and camera setup.
    public private(set) var size: SIMD2<Int>
    /// Physical drawable size in pixels — larger than `size` on HiDPI displays.
    public private(set) var sizeInPixels: SIMD2<Int>
    /// Pixels per logical point (e.g. 2.0 on a Retina / 2× display).
    public private(set) var pixelDensity: Float
    public private(set) var shouldQuit: Bool = false
    public let input = Input()
    private var gamepadHandles: [Int: OpaquePointer] = [:]

    private init(window: OpaquePointer, size: SIMD2<Int>, sizeInPixels: SIMD2<Int>, pixelDensity: Float) {
        self.windowHandle = window
        self.size = size
        self.sizeInPixels = sizeInPixels
        self.pixelDensity = pixelDensity
    }

    public static func start(title: String, width: Int, height: Int) throws -> SDL3Platform {
        guard SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD | SDL_INIT_AUDIO) else {
            throw AppError.sdlInit(lastSDLError())
        }
        guard let win = SDL_CreateWindow(title, Int32(width), Int32(height), SDL_WINDOW_HIGH_PIXEL_DENSITY) else {
            SDL_Quit()
            throw AppError.createWindow(lastSDLError())
        }
        var pw: Int32 = Int32(width)
        var ph: Int32 = Int32(height)
        SDL_GetWindowSizeInPixels(win, &pw, &ph)
        let density = SDL_GetWindowPixelDensity(win)
        return SDL3Platform(
            window: win,
            size: SIMD2(width, height),
            sizeInPixels: SIMD2(Int(pw), Int(ph)),
            pixelDensity: density > 0 ? density : 1.0
        )
    }

    public func pollEvents() {
        input.beginFrame()
        var ev = SDL_Event()
        while SDL_PollEvent(&ev) {
            switch SDL_EventType(rawValue: ev.type) {
            case SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                shouldQuit = true
            case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED, SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
                refreshPixelMetrics()
                // Already-open fonts keep their rasterization; new Font() calls
                // and subsequent Draw SDF calls use the updated density.
                Font.ambientPixelDensity = pixelDensity
                Draw.ambientPixelDensity = pixelDensity
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
            case SDL_EVENT_GAMEPAD_ADDED:
                let id = Int(ev.gdevice.which)
                if let handle = SDL_OpenGamepad(ev.gdevice.which) {
                    gamepadHandles[id] = handle
                    input.connectGamepad(id: id)
                }
            case SDL_EVENT_GAMEPAD_REMOVED:
                let id = Int(ev.gdevice.which)
                if let handle = gamepadHandles.removeValue(forKey: id) {
                    SDL_CloseGamepad(handle)
                }
                input.disconnectGamepad(id: id)
            case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
                if let button = GamepadButton(sdlRaw: Int32(ev.gbutton.button)) {
                    input.gamepad(byID: Int(ev.gbutton.which))?.press(button)
                }
            case SDL_EVENT_GAMEPAD_BUTTON_UP:
                if let button = GamepadButton(sdlRaw: Int32(ev.gbutton.button)) {
                    input.gamepad(byID: Int(ev.gbutton.which))?.release(button)
                }
            case SDL_EVENT_GAMEPAD_AXIS_MOTION:
                if let axis = GamepadAxis(sdlRaw: Int32(ev.gaxis.axis)) {
                    let value = axis.isTrigger
                        ? Gamepad.normalizedTrigger(ev.gaxis.value)
                        : Gamepad.normalizedAxis(ev.gaxis.value)
                    input.gamepad(byID: Int(ev.gaxis.which))?.setAxis(axis, value)
                }
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

    /// Re-queries SDL for the current logical size, pixel size, and pixel density
    /// and writes them into the stored properties. Call on display-scale change events.
    private func refreshPixelMetrics() {
        guard let win = windowHandle else { return }
        var lw: Int32 = 0, lh: Int32 = 0
        SDL_GetWindowSize(win, &lw, &lh)
        var pw: Int32 = 0, ph: Int32 = 0
        SDL_GetWindowSizeInPixels(win, &pw, &ph)
        let density = SDL_GetWindowPixelDensity(win)
        size = SIMD2(Int(lw), Int(lh))
        sizeInPixels = SIMD2(Int(pw), Int(ph))
        pixelDensity = density > 0 ? density : 1.0
    }

    public func stop() {
        for handle in gamepadHandles.values { SDL_CloseGamepad(handle) }
        gamepadHandles.removeAll()
        if let win = windowHandle {
            SDL_DestroyWindow(win)
            windowHandle = nil
        }
        SDL_Quit()
    }
}
#endif
