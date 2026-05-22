#if canImport(CSDL3)
import CSDL3

/// Owns every GPU resource needed to turn a `Draw`'s queued geometry into pixels:
/// the device, the builtin pipeline (cached per color format), a 1×1 white texture
/// for untextured geometry, a linear sampler, and a reused vertex/transfer buffer
/// pair. Callers never touch a Batcher, vertex buffer, or render pass — they queue
/// draws and then flush with `render(_:to:)` (a canvas) or `App.drawOntoScreen`
/// (the window). This is the CF `cf_render_to` / `cf_app_draw_onto_screen` split.
public final class Renderer {
    let device: GPUDevice
    private let vertexShader: Shader
    private let fragmentShader: Shader
    private let pipelines: PipelineCache<GraphicsPipeline>
    private let sampler: Sampler
    private let whiteTexture: Texture
    private var vbuf: Buffer
    private var xfer: TransferBuffer
    private var capacityBytes: Int

    init(device: GPUDevice) throws {
        self.device = device
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
        pxXfer.withMappedMemory { $0.copyMemory(from: px, byteCount: 4) }
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

    /// Flushes `draw`'s queued geometry into `canvas`, then resets the queue.
    /// `camera` defaults to an orthographic projection sized to the canvas.
    public func render(_ draw: Draw, to canvas: Canvas, clear: Color? = nil, camera: Camera? = nil) throws {
        let cam = camera ?? Camera(viewportSize: SIMD2(Float(canvas.width), Float(canvas.height)))
        let cmd = try device.acquireCommandBuffer()
        flush(draw, into: canvas.texture, clear: clear, camera: cam, on: cmd)
        cmd.submit()
    }

    /// Uploads the queued vertices, runs one render pass into `colorTarget`
    /// (binding the white texture for untextured commands), then resets the queue.
    /// Shared by canvas rendering and `App.drawOntoScreen`.
    func flush(_ draw: Draw, into colorTarget: Texture, clear: Color?, camera: Camera, on cmd: CommandBuffer) {
        let verts = draw.batcher.vertices
        let byteCount = verts.count * MemoryLayout<Vertex>.stride
        if byteCount > 0 {
            ensureCapacity(byteCount)
            // cycle: true lets SDL hand us fresh backing if a prior flush this
            // frame is still in flight, so one pooled buffer is safe to reuse.
            xfer.withMappedMemory(cycle: true) { ptr in
                verts.withUnsafeBytes { src in
                    ptr.copyMemory(from: src.baseAddress!, byteCount: src.count)
                }
            }
            cmd.withCopyPass { copy in
                copy.upload(from: xfer, offset: 0, to: vbuf, offset: 0, size: byteCount, cycle: true)
            }
        }

        cmd.pushVertexUniform(camera.viewProjection)
        cmd.withRenderPass(colorTarget: colorTarget, clear: clear) { pass in
            guard byteCount > 0 else { return }
            let pipe = pipelines.get(PipelineKey(shaderID: 0, colorFormat: colorTarget.format, blendMode: .alpha))
            pass.bind(pipe)
            pass.bindVertexBuffer(vbuf)
            for c in draw.batcher.commandsSortedByLayer {
                let tex = c.state.texture ?? whiteTexture.handle
                pass.bindFragmentSampler(textureHandle: tex, sampler: sampler)
                pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
            }
        }
        draw.batcher.reset()
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

    public func destroy() {
        vbuf.destroy()
        xfer.destroy()
        whiteTexture.destroy()
        sampler.destroy()
        vertexShader.destroy()
        fragmentShader.destroy()
    }
}
#endif
