#if os(WASI)
import JavaScriptKit
import Bielik2D

/// Browser twin of the native `App`. Same public surface so the demo's scene code
/// reads `app.input`, `app.renderer`, `app.deltaTime`, etc. identically across
/// platforms — only one `App` compiles per build (`#if canImport(CSDL3)` native,
/// `#if os(WASI)` web), so scene code never branches.
///
/// ## The one API divergence: async construction
/// WebGPU device acquisition is asynchronous (`navigator.gpu.requestAdapter()` →
/// `requestDevice()`), so there is no synchronous `init` here. The native sync
/// `init(title:width:height:)` is replaced by `static func create(...) async
/// throws -> App`. A conditionally-compiled web `main` must `await App.create(...)`
/// where native `main` would `try App(...)`. This is the single seam the platform
/// `main` has to special-case.
public final class App {
    let platform: WebPlatform
    public let renderer: WebRenderer

    /// The audio mixer, or nil if no `AudioContext` could be created. Also installed
    /// as the ambient `Audio.current` so `Sound(path:)` / `sound.play()` work.
    public private(set) var audio: Audio?

    /// This frame's input state (keyboard, mouse, gamepad). Advanced by `update()`.
    public var input: Input { platform.input }

    /// True until the loop requests a quit.
    public var isRunning: Bool { !platform.shouldQuit }

    /// Logical canvas size in points — the FIXED design size the demo passed to
    /// `create` (e.g. 1280×720), matching native `App.size`. The web `Camera` and
    /// mouse positions both live in this logical space (see `WebPlatform.attach` /
    /// `canvasLogical`), so the camera, `size`, and `mouse.position` all agree.
    /// DPR lives only in the framebuffer (`sizeInPixels`) and glyph rasterization.
    public var size: SIMD2<Int> { platform.size }
    /// Physical drawable size in pixels = `size × devicePixelRatio` — the canvas
    /// backing store the swapchain renders into. (Native: the HiDPI-scaled drawable.)
    public var sizeInPixels: SIMD2<Int> { platform.sizeInPixels }
    /// Pixels per logical CSS point — the browser's `devicePixelRatio`.
    public var pixelDensity: Float { platform.pixelDensity }

    /// The active GPU backend name. Web always runs on WebGPU. Diagnostics only.
    public var driverName: String { "webgpu" }

    /// The renderer's image cache. The web bootstrap `await`s `prefetch(_:)` on
    /// this with every sprite path before building scenes, so `Sprite(path:)`
    /// resolves synchronously per frame.
    public var assetLoader: AssetLoader? { renderer.assetLoader }

    /// Seconds elapsed during the last `update()`, clamped to `maxFrameSeconds` so a
    /// stall (tab backgrounded, asset load) can't blow up tweens with one giant step.
    public private(set) var deltaTime: Double = 0
    /// Total elapsed seconds — the running sum of the clamped per-frame deltas.
    public private(set) var time: Double = 0

    /// The ambient coroutine/tween runner, advanced automatically by `update()`.
    /// Installed as `Flow.current` so `app.flow.run { … }` and the bare
    /// `Flow.current` resolve to the same instance.
    public let flow = Flow()

    /// Longest frame `update()` will report; the spike guard for the flow runner.
    /// Matches native `App.maxFrameSeconds`.
    private static let maxFrameSeconds = 0.1

    /// Wall clock backed by JS `performance.now()` (milliseconds), pulled one frame
    /// delta per `update()` — the web counterpart of the native SDL `Clock`. We use
    /// `performance.now()` rather than the RAF timestamp so the clock is independent
    /// of the loop driver (and stays correct if `update()` is ever called outside a
    /// RAF tick, e.g. in tests).
    private let performance: JSObject?
    private var lastNow: Double = 0

    private init(platform: WebPlatform, renderer: WebRenderer, audio: Audio?) {
        self.platform = platform
        self.renderer = renderer
        self.audio = audio
        self.performance = JSObject.global.performance.object

        // Seed ambient densities so bare Font/Draw calls rasterize/scale at the
        // canvas's pixel resolution, matching native.
        Font.ambientPixelDensity = platform.pixelDensity
        Draw.ambientPixelDensity = platform.pixelDensity
        // Audio + Flow ambients, like native. The web `Sprite` twin resolves
        // `Sprite(path:)` through `WebRenderer.current` (the web analogue of the
        // native `Renderer.current`), reading images the bootstrap prefetched into
        // the renderer's `assetLoader`.
        Audio.current = audio
        Flow.current = flow
        WebRenderer.current = renderer

        self.lastNow = nowMillis()
    }

    /// Async factory: builds the platform, GPU backend, renderer, and audio, then
    /// returns a ready `App`. Replaces the native sync `init` — see the type doc.
    public static func create(title: String, width: Int, height: Int) async throws -> App {
        // `width`/`height` are the FIXED LOGICAL design size (the demo passes
        // 1280×720): the canvas backing store is sized to `width × DPR` by
        // `height × DPR` while its CSS box is left to the page stylesheet, so the
        // engine lays out in this logical space exactly like native. The `title`
        // isn't shown. We attach to the conventional "bielik2d" canvas.
        let platform = try WebPlatform.attach(canvasID: "bielik2d", width: width, height: height)
        let renderer = try await makeRenderer(on: platform)
        // Install the web asset loader so `Sprite(path:)` resolves prefetched
        // images; the bootstrap prefetches sprite paths through `app.assetLoader`
        // before constructing scenes.
        renderer.assetLoader = WebAssetLoader()
        // Audio is best-effort: a context that fails to construct runs silently.
        let audio = try? Audio()
        return App(platform: platform, renderer: renderer, audio: audio)
    }

    /// Assembles the full WebGPU renderer (backend → pipeline cache → buffers →
    /// sampler → white texture → `WebRenderer`). Awaits the async device + shader
    /// acquisition. Mirrors the setup the standalone web demo's `main` did inline.
    private static func makeRenderer(on platform: WebPlatform) async throws -> WebRenderer {
        let backend = try await WebGPURenderBackend.create(on: platform)
        let cache = try await WebPipelineCache.create(backend: backend)

        let uniformBuffer = backend.device.createBuffer!(WebJS.object([
            "size": .number(64),
            "usage": .number(Double(GPUBufferUsage.uniform | GPUBufferUsage.copyDst)),
        ])).object!

        let sampler = backend.device.createSampler!(WebJS.object([
            "magFilter": .string("linear"),
            "minFilter": .string("linear"),
        ])).object!

        // Vertex buffer sized for a comfortable per-frame upper bound; the Batcher
        // resets in place each frame so this doesn't churn.
        let maxVertexCount = 6 * 1024
        let vertexBuffer = backend.device.createBuffer!(WebJS.object([
            "size": .number(Double(maxVertexCount * MemoryLayout<Vertex>.stride)),
            "usage": .number(Double(GPUBufferUsage.vertex | GPUBufferUsage.copyDst)),
        ])).object!

        let whiteTexture = backend.makeWhitePixelTexture()

        return WebRenderer(
            backend: backend, cache: cache,
            vertexBuffer: vertexBuffer, maxVertexCount: maxVertexCount,
            sampler: sampler, uniformBuffer: uniformBuffer, whiteTexture: whiteTexture
        )
    }

    /// Advance one frame: input edges + gamepads, the delta clock, the flow runner,
    /// and the audio mixer — the same work `App.update()` does on native. The loop
    /// driver calls this at the top of every frame (via the demo's `runFrame`), so
    /// input advances exactly once before scene code reads it.
    public func update() {
        // Own the per-frame input advance here (not in `WebPlatform.run`), matching
        // native where `App.update()` drives input.
        platform.advanceInput()

        let now = nowMillis()
        let raw = (now - lastNow) / 1000.0
        lastNow = now
        let dt = min(max(raw, 0), App.maxFrameSeconds)
        deltaTime = dt
        time += dt

        flow.update(dt)
        audio?.update()
    }

    /// Flushes `draw`'s queued geometry to the canvas swapchain and presents, then
    /// resets the queue — the web `cf_app_draw_onto_screen`. `camera` defaults to an
    /// ortho projection sized to the LOGICAL design size (`platform.size`), matching
    /// native; the swapchain viewport scales that to the pixel framebuffer.
    public func drawOntoScreen(_ draw: Draw, clear: Color? = nil, camera: Camera? = nil) {
        let cam = camera ?? Camera(viewportSize: SIMD2(Float(platform.size.x), Float(platform.size.y)))
        draw.flush(through: renderer, camera: cam, clear: clear)
    }

    /// A text engine bound to this app's renderer — the web `SDL3_ttf` twin. Scene
    /// code stores it in `Draw(textEngine:)` and calls `draw.text(...)` unchanged.
    public func makeTextEngine() -> WebTextEngine {
        WebTextEngine(renderer: renderer)
    }

    /// Schedule `body` once per `requestAnimationFrame`. `body` is the demo's
    /// `runFrame`, which calls `update()` at its top; the RAF tick itself no longer
    /// advances input (see `WebPlatform.run`), so input advances exactly once per
    /// frame. The `Double` delta the platform loop passes is ignored — `update()`'s
    /// own clamped clock is the authority on `deltaTime`.
    public func startLoop(_ body: @escaping () -> Void) {
        platform.run { _ in body() }
    }

    /// Tear down: drop the ambient statics this app installed (only if still ours),
    /// stop the flow, and destroy audio. Mirrors native `App.destroy()`.
    public func destroy() {
        if Flow.current === flow { Flow.current = nil }
        if WebRenderer.current === renderer { WebRenderer.current = nil }
        flow.stopAll()
        if Audio.current === audio { Audio.current = nil }
        audio?.destroy()
        audio = nil
    }

    /// `performance.now()` in milliseconds, falling back to 0 if the API is absent.
    private func nowMillis() -> Double {
        performance?.now?().number ?? 0
    }
}
#endif
