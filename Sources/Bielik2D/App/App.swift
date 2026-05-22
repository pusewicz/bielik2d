#if canImport(CSDL3)
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
    public let renderer: Renderer
    let platform: SDL3Platform

    public var isRunning: Bool { platform.windowHandle != nil && !platform.shouldQuit }
    public var window: OpaquePointer? { platform.windowHandle }

    public init(title: String, width: Int, height: Int) throws {
        let plat = try SDL3Platform.start(title: title, width: width, height: height)
        do {
            self.gpu = try GPUDevice()
            try gpu.claim(window: plat.windowHandle!)
            self.renderer = try Renderer(device: gpu)
        } catch {
            plat.stop()
            throw error
        }
        self.platform = plat
    }

    public func update() {
        platform.pollEvents()
    }

    /// Flushes everything queued in `draw` to the window and presents, then
    /// resets the queue. This is the only call that touches the swapchain — the
    /// CF `cf_app_draw_onto_screen` equivalent. `camera` defaults to an ortho
    /// projection sized to the window.
    public func drawOntoScreen(_ draw: Draw, clear: Color? = nil, camera: Camera? = nil) {
        guard let window = platform.windowHandle else { draw.batcher.reset(); return }
        guard let cmd = try? gpu.acquireCommandBuffer() else { draw.batcher.reset(); return }
        guard let swap = cmd.acquireSwapchainTexture(for: window, device: gpu) else {
            cmd.submit()
            draw.batcher.reset()
            return
        }
        let cam = camera ?? Camera(viewportSize: SIMD2(Float(swap.width), Float(swap.height)))
        renderer.flush(draw, into: swap, clear: clear, camera: cam, on: cmd)
        cmd.submit()
    }

    /// Returns true exactly on the frame the key transitioned from up to down.
    public func keyJustPressed(_ scancode: SDL_Scancode) -> Bool {
        platform.keyJustPressed(scancode.rawValue)
    }

    public func destroy() {
        renderer.destroy()
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
#endif
