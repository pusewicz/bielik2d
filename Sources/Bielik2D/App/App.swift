import CSDL3

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
    private var window: OpaquePointer?

    public init(title: String, width: Int, height: Int) throws {
        guard SDL_Init(SDL_INIT_VIDEO) else {
            throw AppError.sdlInit(Self.lastError())
        }
        guard let win = SDL_CreateWindow(title, Int32(width), Int32(height), 0) else {
            SDL_Quit()
            throw AppError.createWindow(Self.lastError())
        }
        self.window = win
        self.isRunning = true
    }

    public func destroy() {
        if let win = window {
            SDL_DestroyWindow(win)
            window = nil
        }
        SDL_Quit()
        isRunning = false
    }

    deinit {
        if isRunning {
            destroy()
        }
    }

    private static func lastError() -> String {
        guard let cstr = SDL_GetError() else { return "(no error message)" }
        return String(cString: cstr)
    }
}
