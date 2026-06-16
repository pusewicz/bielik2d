#if os(WASI)
import JavaScriptKit
import JavaScriptEventLoop
import Bielik2D
import Bielik2DWeb

JavaScriptEventLoop.installGlobalExecutor()

enum DemoState {
    nonisolated(unsafe) static var platform: WebPlatform?
    nonisolated(unsafe) static var backend: WebGPURenderBackend?
    nonisolated(unsafe) static var renderer: WebRenderer?
}

Task {
    do { try await runDemo() }
    catch { print("bielik2d: error \(error)") }
}

func runDemo() async throws {
    let platform = try WebPlatform.attach(canvasID: "bielik2d")
    let backend = try await WebGPURenderBackend.create(on: platform)
    DemoState.platform = platform
    DemoState.backend = backend

    // The renderer owns its pipelines now: the cache loads both the basic and
    // sprite shader modules and builds a pipeline per (shader, blend) on demand.
    let cache = try await WebPipelineCache.create(backend: backend)

    // Camera + uniform buffer (the renderer re-uploads viewProjection each frame).
    let camera = Camera(viewportSize: SIMD2(Float(platform.size.x), Float(platform.size.y)))
    let uniformBuffer = backend.device.createBuffer!(WebJS.object([
        "size": .number(64),
        "usage": .number(Double(GPUBufferUsage.uniform | GPUBufferUsage.copyDst)),
    ])).object!

    let sampler = backend.device.createSampler!(WebJS.object([
        "magFilter": .string("linear"),
        "minFilter": .string("linear"),
    ])).object!

    // Vertex buffer sized for a comfortable per-frame upper bound. Bielik2D's
    // Batcher resets in place each frame so allocations don't churn.
    let maxVertexCount = 6 * 1024
    let vertexBuffer = backend.device.createBuffer!(WebJS.object([
        "size": .number(Double(maxVertexCount * MemoryLayout<Vertex>.stride)),
        "usage": .number(Double(GPUBufferUsage.vertex | GPUBufferUsage.copyDst)),
    ])).object!

    let whiteTexture = backend.makeWhitePixelTexture()

    let webRenderer = WebRenderer(
        backend: backend, cache: cache,
        vertexBuffer: vertexBuffer, maxVertexCount: maxVertexCount,
        sampler: sampler, uniformBuffer: uniformBuffer, whiteTexture: whiteTexture
    )
    DemoState.renderer = webRenderer

    // Sprite texture from a fetched PNG. The minimal demo's quad sets no texture,
    // so we make the sprite PNG the default group-1 binding: the untextured quad
    // samples the image, while SDF circle/line ignore the texture (shape != 0).
    let bitmap = try await WebAssetLoader.loadImageBitmap(url: "assets/p1_stand.png")
    let (spriteTexture, spriteW, spriteH) = backend.makeTexture(from: bitmap)
    let spriteBindGroup = WebRenderer.makeTextureBindGroup(
        device: backend.device, layout: cache.textureBindGroupLayout,
        texture: spriteTexture, sampler: sampler)

    // The label now flows through the real web text engine: it rasterizes,
    // uploads, caches, and emits a textured quad through the shared command loop,
    // exactly like portable `draw.text(...)` will on the unified demo.
    let textEngine = WebTextEngine(renderer: webRenderer)
    let labelFont = Font(family: "-apple-system, sans-serif", ptSize: 32)

    let cx = Float(platform.size.x) * 0.5
    let cy = Float(platform.size.y) * 0.5
    let halfW = Float(spriteW) * 0.5
    let halfH = Float(spriteH) * 0.5
    let white = SIMD4<Float>(1, 1, 1, 1)
    let spriteUV = Rect(x: 0, y: 0, width: 1, height: 1)
    let labelOrigin = SIMD2<Float>(40, 40)

    // Two Draw queues flushed each frame through the same command-driven renderer:
    // the sprite + SDF batch (default texture = the sprite PNG), then the label
    // (default texture = the label glyph atlas). Both go through render()'s
    // command loop — no special-cased draw path.
    let mainDraw = Draw()
    mainDraw.reserveVertexCapacity(maxVertexCount)
    let labelDraw = Draw(textEngine: textEngine)

    platform.run { _ in
        // Sprite (textured quad).
        mainDraw.quad(
            rect: Rect(x: cx - halfW, y: cy - halfH, width: halfW * 2, height: halfH * 2),
            uv: spriteUV, color: white
        )
        // SDF circle to the right of the sprite.
        mainDraw.circleFill(center: SIMD2(cx + halfW + 120, cy), radius: 60,
                            color: Color(r: 0.4, g: 0.8, b: 1.0))
        // SDF line below the sprite.
        mainDraw.line(from: SIMD2(cx - 220, cy + halfH + 80), to: SIMD2(cx + 220, cy + halfH + 80),
                      thickness: 8, color: Color(r: 1.0, g: 0.9, b: 0.3))

        webRenderer.defaultTextureBindGroup = spriteBindGroup
        mainDraw.flush(through: webRenderer, camera: camera, clear: Color(r: 0.10, g: 0.12, b: 0.18))

        // Label, drawn over the cleared frame (no clear this pass). Goes through
        // the real web text engine: the glyph quad carries its own texture token,
        // so the command loop binds the rasterized texture (the default binding is
        // only the fallback for untextured commands).
        labelDraw.text("Hello, Bielik!", font: labelFont, at: labelOrigin, color: .white)
        labelDraw.flush(through: webRenderer, camera: camera, clear: nil)
    }
}
#else
import Bielik2DWeb
print("Bielik2DWeb \(Bielik2DWeb.version) — built for non-wasi target; run via scripts/build-web.sh")
#endif
