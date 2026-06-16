#if canImport(CSDL3)
import CSDL3

/// Owns every GPU resource needed to turn a `Draw`'s queued geometry into pixels:
/// the device, the builtin pipeline (cached per color format), a 1×1 white texture
/// for untextured geometry, a linear sampler, and a reused vertex/transfer buffer
/// pair. Callers never touch a Batcher, vertex buffer, or render pass — they queue
/// draws and flush with `App.drawOntoScreen` (the window, via `RenderBackend`) or
/// `render(_:to:)` (an offscreen canvas). The CF `cf_app_draw_onto_screen` /
/// `cf_render_to` split.
public final class Renderer: RenderBackend {
    let device: GPUDevice
    private let window: OpaquePointer
    private let vertexShader: Shader
    private let fragmentShader: Shader
    private let pipelines: PipelineCache<GraphicsPipeline>
    private let sampler: Sampler
    private let whiteTexture: Texture
    private let spriteBatch: SpriteBatch
    let spriteRegistry: SpriteRegistry
    private var vbuf: Buffer
    private var xfer: TransferBuffer
    private var capacityBytes: Int

    /// The renderer that bare `Sprite(path:)` / `sprite.update(_:)` calls resolve
    /// against — installed by `App` at startup. `nonisolated(unsafe)` because the
    /// engine, like CF, drives everything from one thread; the explicit `on:`/`in:`
    /// forms exist for tests and multi-context setups that can't lean on this.
    public static nonisolated(unsafe) var current: Renderer?

    /// Draw calls issued by the last flush — handy for confirming the atlas is
    /// collapsing many sprites into few binds.
    public private(set) var lastDrawCallCount: Int = 0

    init(device: GPUDevice, window: OpaquePointer) throws {
        self.device = device
        self.window = window
        let batch = SpriteBatch(device: device)
        self.spriteBatch = batch
        self.spriteRegistry = SpriteRegistry(registrar: batch)
        let vs = try Shader.builtin(name: "sprite.vert", stage: .vertex, on: device)
        let fs = try Shader.builtin(name: "sprite.frag", stage: .fragment, on: device)
        self.vertexShader = vs
        self.fragmentShader = fs
        self.pipelines = PipelineCache { key in
            // A pipeline that fails to build is unrecoverable; surface it loudly.
            try! device.makePipeline(
                vertex: vs, fragment: fs,
                vertexBuffer: Vertex.bufferLayout,
                colorTargetFormat: key.colorFormat,
                blendMode: key.blendMode
            )
        }
        self.sampler = try device.makeSampler(filter: .linear)

        // 1×1 white texture so untextured quads and SDF shapes sample 1.0 — the
        // batcher leaves their texture nil and we substitute white at flush.
        let white = try device.makeTexture(width: 1, height: 1, usage: .sampler)
        let px: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        let pxXfer = try device.makeTransferBuffer(size: 4, usage: .upload)
        pxXfer.withMappedMemory { dst in
            px.withUnsafeBytes { src in dst.copyMemory(from: src.baseAddress!, byteCount: 4) }
        }
        let initCmd = try device.acquireCommandBuffer()
        initCmd.withCopyPass { $0.upload(from: pxXfer, to: white) }
        initCmd.submit()
        pxXfer.destroy()
        self.whiteTexture = white

        let initialCount = 6 * 1024
        self.capacityBytes = initialCount * MemoryLayout<Vertex>.stride
        self.vbuf = try device.makeBuffer(size: capacityBytes, usage: .vertex)
        self.xfer = try device.makeTransferBuffer(size: capacityBytes, usage: .upload)
    }

    // MARK: - RenderBackend (the window/swapchain)

    /// Flushes a draw list to the window's swapchain and presents. Driven by
    /// `App.drawOntoScreen` via `Draw.flush(through:)`.
    public func render(_ list: DrawList, camera: Camera, clear: Color?) {
        guard let cmd = try? device.acquireCommandBuffer() else { return }
        guard let swap = cmd.acquireSwapchainTexture(for: window, device: device) else {
            cmd.submit()
            return
        }
        flushList(list, into: swap, clear: clear, camera: camera, on: cmd, pointScale: Draw.ambientPixelDensity)
        cmd.submit()
    }

    // MARK: - Offscreen canvas

    /// Flushes `draw`'s queued geometry into `canvas`, then resets the queue.
    /// `camera` defaults to an orthographic projection sized to the canvas.
    public func render(_ draw: Draw, to canvas: Canvas, clear: Color? = nil, camera: Camera? = nil) {
        let cam = camera ?? Camera(viewportSize: SIMD2(Float(canvas.width), Float(canvas.height)))
        let list = DrawList(vertices: draw.batcher.vertices,
                            commands: draw.batcher.commandsSortedByLayer,
                            spriteInstances: draw.spriteInstances)
        guard let cmd = try? device.acquireCommandBuffer() else { return }
        // cycle: the canvas is sampled (composited) the same frame it's drawn, and
        // across frames while in flight — fresh backing each frame avoids feedback.
        flushList(list, into: canvas.texture, clear: clear, camera: cam, on: cmd, cycleTarget: true)
        cmd.submit()
        draw.clearQueue()
    }

    // MARK: - Shared flush

    /// Uploads the list's vertices, runs one render pass into `colorTarget`
    /// (binding the white texture for untextured commands). Does not reset any
    /// queue — callers own that.
    private func flushList(_ list: DrawList, into colorTarget: Texture, clear: Color?, camera: Camera, on cmd: CommandBuffer, cycleTarget: Bool = false, pointScale: Float = 1.0) {
        let (vertices, commands) = resolvedGeometry(for: list)
        lastDrawCallCount = commands.count

        let byteCount = vertices.count * MemoryLayout<Vertex>.stride
        if byteCount > 0 {
            ensureCapacity(byteCount)
            // cycle: true lets SDL hand us fresh backing if a prior flush this
            // frame is still in flight, so one pooled buffer is safe to reuse.
            xfer.withMappedMemory(cycle: true) { ptr in
                vertices.withUnsafeBytes { src in
                    ptr.copyMemory(from: src.baseAddress!, byteCount: src.count)
                }
            }
            cmd.withCopyPass { copy in
                copy.upload(from: xfer, offset: 0, to: vbuf, offset: 0, size: byteCount, cycle: true)
            }
        }

        cmd.pushVertexUniform(camera.viewProjection)
        cmd.withRenderPass(colorTarget: colorTarget, clear: clear, cycle: cycleTarget) { pass in
            guard byteCount > 0 else { return }
            pass.bindVertexBuffer(vbuf)   // bindings persist across pipeline switches
            let tw = colorTarget.width, th = colorTarget.height
            var lastBlend: BlendMode? = nil
            var lastScissor: Rect?? = nil
            var lastViewport: Rect?? = nil
            for c in commands {
                if lastBlend != c.state.blendMode {
                    pass.bind(pipelines.get(PipelineKey(shaderID: 0, colorFormat: colorTarget.format,
                                                        blendMode: c.state.blendMode)))
                    lastBlend = c.state.blendMode
                }
                if lastScissor != .some(c.state.scissor) {
                    let s = scissorPixelRect(c.state.scissor, scale: pointScale, targetW: tw, targetH: th)
                    pass.setScissor(x: s.x, y: s.y, width: s.w, height: s.h)
                    lastScissor = .some(c.state.scissor)
                }
                if lastViewport != .some(c.state.viewport) {
                    let v = viewportPixelRect(c.state.viewport, scale: pointScale, targetW: tw, targetH: th)
                    pass.setViewport(x: v.x, y: v.y, width: v.w, height: v.h)
                    lastViewport = .some(c.state.viewport)
                }
                let tex = c.state.texture ?? whiteTexture.handle
                pass.bindFragmentSampler(textureHandle: tex, sampler: sampler)
                pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
            }
        }
    }

    /// Packs any newly-seen sprites into the atlas, then merges the immediate
    /// geometry with the resolved sprite quads into one vertex/command stream sorted
    /// by layer. Within a layer, immediate geometry stays before sprites.
    private func resolvedGeometry(for list: DrawList) -> (ContiguousArray<Vertex>, [DrawCommand]) {
        guard !list.spriteInstances.isEmpty else { return (list.vertices, list.commands) }

        // Atlas uploads run on their own command buffer, submitted (and so executed)
        // before this frame's render pass samples the pages.
        do {
            try spriteBatch.defrag(used: Set(list.spriteInstances.map(\.id)))
        } catch {
            assertionFailure("atlas defrag failed: \(error)")
            return (list.vertices, list.commands)
        }

        let spriteBatcher = Batcher()
        spriteBatch.resolve(list.spriteInstances, into: spriteBatcher)

        var vertices = list.vertices
        let base = vertices.count
        vertices.append(contentsOf: spriteBatcher.vertices)

        var commands = list.commands
        for c in spriteBatcher.commands {
            commands.append(DrawCommand(state: c.state,
                                        vertexStart: c.vertexStart + base,
                                        vertexCount: c.vertexCount))
        }
        commands.sort { $0.state.layer < $1.state.layer }
        return (vertices, commands)
    }

    private func ensureCapacity(_ bytes: Int) {
        guard bytes > capacityBytes else { return }
        var newCap = capacityBytes
        while newCap < bytes { newCap *= 2 }
        vbuf.destroy()
        xfer.destroy()
        vbuf = try! device.makeBuffer(size: newCap, usage: .vertex)
        xfer = try! device.makeTransferBuffer(size: newCap, usage: .upload)
        capacityBytes = newCap
    }

    // MARK: - Resource factories (so callers never see a GPUDevice)

    /// Loads (and path-caches) a sprite from an image file.
    public func sprite(path: String) throws -> Sprite {
        try spriteRegistry.sprite(path: path)
    }

    /// Loads (and path-caches) an animated sprite by slicing a grid sprite sheet into
    /// `frameWidth`×`frameHeight` cells played as one looping animation at `fps`.
    public func sprite(sheet path: String, frameWidth: Int, frameHeight: Int, fps: Double = 10) throws -> Sprite {
        try spriteRegistry.sprite(sheet: path, frameWidth: frameWidth, frameHeight: frameHeight, fps: fps)
    }

    public func makeSprite(png path: String) throws -> Sprite {
        try spriteRegistry.sprite(path: path)
    }

    public func makeSprite(image: ImageBytes) -> Sprite {
        spriteRegistry.makeSprite(image)
    }

    /// Builds an animated sprite from an in-memory sheet (e.g. procedurally generated).
    public func makeSprite(sheet image: ImageBytes, frameWidth: Int, frameHeight: Int, fps: Double = 10) -> Sprite {
        spriteRegistry.makeSprite(sheet: image, frameWidth: frameWidth, frameHeight: frameHeight, fps: fps)
    }

    public func makeCanvas(width: Int, height: Int, format: TextureFormat = .rgba8Unorm) throws -> Canvas {
        try Canvas(width: width, height: height, format: format, on: self)
    }

    public func makeTextEngine() throws -> TextEngine {
        try TextEngine(on: self)
    }

    public func destroy() {
        spriteBatch.destroy()
        vbuf.destroy()
        xfer.destroy()
        whiteTexture.destroy()
        sampler.destroy()
        vertexShader.destroy()
        fragmentShader.destroy()
    }
}
#endif
