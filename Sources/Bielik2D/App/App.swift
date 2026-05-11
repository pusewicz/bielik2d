import CSDL3

/// SDL3's `SDL_WINDOW_HIGH_PIXEL_DENSITY` flag. The matching SDL macro uses
/// `SDL_UINT64_C(...)` which Swift's importer can't fold into a constant.
public let SDL_WINDOW_HIGH_PIXEL_DENSITY: SDL_WindowFlags = 0x2000

public enum AppError: Error, CustomStringConvertible {
    case sdlInit(String)
    case createWindow(String)

    public var description: String {
        switch self {
        case .sdlInit(let m): "SDL_Init failed: \(m)"
        case .createWindow(let m): "SDL_CreateWindow failed: \(m)"
        }
    }
}

public final class App {
    public private(set) var isRunning: Bool = false
    public let gpu: GPUDevice
    public private(set) var window: OpaquePointer?
    private var keysJustPressed: Set<UInt32> = []

    public init(title: String, width: Int, height: Int) throws {
        guard SDL_Init(SDL_INIT_VIDEO) else {
            throw AppError.sdlInit(lastSDLError())
        }
        guard let win = SDL_CreateWindow(title, Int32(width), Int32(height), SDL_WINDOW_HIGH_PIXEL_DENSITY) else {
            SDL_Quit()
            throw AppError.createWindow(lastSDLError())
        }
        self.window = win
        do {
            self.gpu = try GPUDevice()
            try gpu.claim(window: win)
        } catch {
            SDL_DestroyWindow(win)
            SDL_Quit()
            throw error
        }
        self.isRunning = true
    }

    public func update() {
        keysJustPressed.removeAll(keepingCapacity: true)
        var ev = SDL_Event()
        while SDL_PollEvent(&ev) {
            switch SDL_EventType(rawValue: ev.type) {
            case SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                isRunning = false
            case SDL_EVENT_KEY_DOWN:
                if !ev.key.repeat {
                    keysJustPressed.insert(ev.key.scancode.rawValue)
                }
            default:
                break
            }
        }
    }

    /// Returns true exactly on the frame the key transitioned from up to down.
    public func keyJustPressed(_ scancode: SDL_Scancode) -> Bool {
        keysJustPressed.contains(scancode.rawValue)
    }

    public func destroy() {
        if let win = window {
            gpu.release(window: win)
            SDL_DestroyWindow(win)
            window = nil
        }
        gpu.destroy()
        SDL_Quit()
        isRunning = false
    }

    deinit {
        if isRunning {
            destroy()
        }
    }
}
