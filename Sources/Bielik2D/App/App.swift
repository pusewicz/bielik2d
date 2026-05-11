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
    public let gpu: GPUDevice
    let platform: SDL3Platform

    public var isRunning: Bool { platform.windowHandle != nil && !platform.shouldQuit }
    public var window: OpaquePointer? { platform.windowHandle }

    public init(title: String, width: Int, height: Int) throws {
        let plat = try SDL3Platform.start(title: title, width: width, height: height)
        do {
            self.gpu = try GPUDevice()
            try gpu.claim(window: plat.windowHandle!)
        } catch {
            plat.stop()
            throw error
        }
        self.platform = plat
    }

    public func update() {
        platform.pollEvents()
    }

    /// Returns true exactly on the frame the key transitioned from up to down.
    public func keyJustPressed(_ scancode: SDL_Scancode) -> Bool {
        platform.keyJustPressed(scancode.rawValue)
    }

    public func destroy() {
        if let win = platform.windowHandle {
            gpu.release(window: win)
        }
        gpu.destroy()
        platform.stop()
    }

    deinit {
        if platform.windowHandle != nil {
            destroy()
        }
    }
}
