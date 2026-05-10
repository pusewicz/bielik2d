import Bielik2D

let app = try App(title: "Bielik2D Demo", width: 1280, height: 720)
print("GPU driver: \(app.gpu.driverName)")

// Build the sprite pipeline.
let vs = try Shader.builtin(name: "sprite.vert", stage: .vertex, on: app.gpu)
let fs = try Shader.builtin(name: "sprite.frag", stage: .fragment, on: app.gpu)
let pipe = try app.gpu.makePipeline(
    vertex: vs, fragment: fs,
    vertexBuffer: Vertex.bufferLayout,
    colorTargetFormat: .bgra8Unorm,
    blendMode: .alpha
)

// A 1×1 white texture lets the same shader draw solid-color quads.
let whiteTex = try app.gpu.makeTexture(width: 1, height: 1, usage: .sampler)
do {
    let pixel: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
    let pixelXfer = try app.gpu.makeTransferBuffer(size: 4, usage: .upload)
    pixelXfer.withMappedMemory { $0.copyMemory(from: pixel, byteCount: 4) }
    let init0 = try app.gpu.acquireCommandBuffer()
    init0.withCopyPass { $0.upload(from: pixelXfer, to: whiteTex) }
    init0.submit()
    pixelXfer.destroy()
}
let sampler = try app.gpu.makeSampler(filter: .nearest)

// Vertex buffer big enough for ~1k quads.
let maxVertexCount = 6 * 1024
let vertexBufferSize = maxVertexCount * MemoryLayout<Vertex>.stride
let vbuf = try app.gpu.makeBuffer(size: vertexBufferSize, usage: .vertex)
let vxfer = try app.gpu.makeTransferBuffer(size: vertexBufferSize, usage: .upload)

let batcher = Batcher()

while app.isRunning {
    app.update()
    guard let window = app.window else { break }

    batcher.reset()
    batcher.setTexture(whiteTex.handle)
    batcher.emitQuad(
        rect: Rect(x: -0.5, y: -0.5, width: 1.0, height: 1.0),
        uv: Rect(x: 0, y: 0, width: 1, height: 1),
        color: SIMD4<Float>(1.0, 0.4, 0.6, 1.0)
    )

    let cmd = try app.gpu.acquireCommandBuffer()
    guard let swap = cmd.acquireSwapchainTexture(for: window, device: app.gpu) else {
        cmd.submit()
        continue
    }

    let vertexBytes = batcher.vertices.count * MemoryLayout<Vertex>.stride
    if vertexBytes > 0 {
        vxfer.withMappedMemory(cycle: true) { ptr in
            batcher.vertices.withUnsafeBytes { src in
                ptr.copyMemory(from: src.baseAddress!, byteCount: src.count)
            }
        }
        cmd.withCopyPass { copy in
            copy.upload(from: vxfer, offset: 0, to: vbuf, offset: 0, size: vertexBytes)
        }
    }

    cmd.withRenderPass(colorTarget: swap, clear: Color(r: 0.10, g: 0.12, b: 0.18)) { pass in
        guard !batcher.vertices.isEmpty else { return }
        pass.bind(pipe)
        pass.bindVertexBuffer(vbuf)
        pass.bindFragmentSampler(whiteTex, sampler: sampler)
        for c in batcher.commandsSortedByLayer {
            pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
        }
    }
    cmd.submit()
}
app.destroy()
