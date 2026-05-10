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
    public let gpu: GPUDevice
    private var window: OpaquePointer?

    public init(title: String, width: Int, height: Int) throws {
        guard SDL_Init(SDL_INIT_VIDEO) else {
            throw AppError.sdlInit(lastSDLError())
        }
        guard let win = SDL_CreateWindow(title, Int32(width), Int32(height), 0) else {
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
