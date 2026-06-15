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
    let gpu: GPUDevice
    public let renderer: Renderer
    let platform: SDL3Platform

    /// The audio mixer, or nil if no output device could be opened. Also installed
    /// as the ambient `Audio.current` so `Sound(path:)` and `sound.play()` work.
    public private(set) var audio: Audio?

    public var isRunning: Bool { platform.windowHandle != nil && !platform.shouldQuit }
    public var window: OpaquePointer? { platform.windowHandle }

    /// Logical window size in points. Use this for game logic and camera setup.
    public var size: SIMD2<Int> { platform.size }
    /// Physical drawable size in pixels — larger than `size` on HiDPI displays.
    public var sizeInPixels: SIMD2<Int> { platform.sizeInPixels }
    /// Pixels per logical point (e.g. 2.0 on a Retina / 2× display).
    public var pixelDensity: Float { platform.pixelDensity }

    /// This frame's input state (keyboard, …). Updated by `update()`.
    public var input: Input { platform.input }

    public init(title: String, width: Int, height: Int) throws {
        let plat = try SDL3Platform.start(title: title, width: width, height: height)
        do {
            self.gpu = try GPUDevice()
            try gpu.claim(window: plat.windowHandle!)
            self.renderer = try Renderer(device: gpu, window: plat.windowHandle!)
        } catch {
            plat.stop()
            throw error
        }
        self.platform = plat
        // Seed the ambient font density so bare `Font(path:ptSize:)` calls
        // automatically rasterize at native resolution for this display.
        Font.ambientPixelDensity = plat.pixelDensity
        // Make this the ambient renderer so bare `Sprite(path:)` and `sprite.update`
        // resolve against it. Last app created wins.
        Renderer.current = renderer
        // Audio is best-effort: a host with no output device runs silently.
        self.audio = try? Audio()
        Audio.current = audio
    }

    public func update() {
        platform.pollEvents()
        audio?.update()
    }

    /// The active GPU backend name (e.g. "metal"). Diagnostics only.
    public var driverName: String { gpu.driverName }

    /// Sets the swapchain present mode (vsync / immediate / mailbox).
    @discardableResult
    public func setPresentMode(_ mode: PresentMode) -> Bool {
        guard let win = platform.windowHandle else { return false }
        return gpu.setSwapchainPresentMode(mode, for: win)
    }

    /// Flushes everything queued in `draw` to the window and presents, then
    /// resets the queue. This is the only call that touches the swapchain — the
    /// CF `cf_app_draw_onto_screen` equivalent. `camera` defaults to an ortho
    /// projection sized to the window.
    public func drawOntoScreen(_ draw: Draw, clear: Color? = nil, camera: Camera? = nil) {
        let cam = camera ?? Camera(viewportSize: SIMD2(Float(platform.size.x), Float(platform.size.y)))
        draw.flush(through: renderer, camera: cam, clear: clear)
    }

    public func destroy() {
        if Audio.current === audio { Audio.current = nil }
        audio?.destroy()
        audio = nil
        if Renderer.current === renderer { Renderer.current = nil }
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
