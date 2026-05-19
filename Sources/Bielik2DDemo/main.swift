import Bielik2D
import Foundation

let windowSize = SIMD2<Float>(1280, 720)

let app = try App(title: "Bielik2D Demo", width: Int(windowSize.x), height: Int(windowSize.y))
print("GPU driver: \(app.gpu.driverName)")

let vs = try Shader.builtin(name: "sprite.vert", stage: .vertex, on: app.gpu)
let fs = try Shader.builtin(name: "sprite.frag", stage: .fragment, on: app.gpu)
let pipe = try app.gpu.makePipeline(
    vertex: vs, fragment: fs,
    vertexBuffer: Vertex.bufferLayout,
    colorTargetFormat: .bgra8Unorm,
    blendMode: .alpha
)

// 1×1 white texture for solid quads.
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
let sampler = try app.gpu.makeSampler(filter: .linear)

// PNG asset shipped with the demo (Kenney, CC0).
let playerPath = Bundle.module.url(forResource: "p1_stand", withExtension: "png", subdirectory: "assets")!.path
let player = try Sprite(png: playerPath, on: app.gpu)

let maxVertexCount = 6 * 1024
let vertexBufferSize = maxVertexCount * MemoryLayout<Vertex>.stride
let vbuf = try app.gpu.makeBuffer(size: vertexBufferSize, usage: .vertex)
let vxfer = try app.gpu.makeTransferBuffer(size: vertexBufferSize, usage: .upload)
let vbufCanvas = try app.gpu.makeBuffer(size: vertexBufferSize, usage: .vertex)
let vxferCanvas = try app.gpu.makeTransferBuffer(size: vertexBufferSize, usage: .upload)

let textEngine = try TextEngine(on: app.gpu)
let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 28)

// Offscreen canvas matched to the swapchain's BGRA8 format so the existing
// sprite pipeline binds to both render targets without a second pipeline.
let canvasSize = SIMD2<Float>(256, 256)
let canvas = try Canvas(width: Int(canvasSize.x), height: Int(canvasSize.y),
                        format: .bgra8Unorm, on: app.gpu)

let batcher = Batcher()
let draw = Draw(batcher: batcher, textEngine: textEngine)
let batcherCanvas = Batcher()
let drawCanvas = Draw(batcher: batcherCanvas)
let camera = Camera(viewportSize: windowSize)
let cameraCanvas = Camera(viewportSize: canvasSize)
let startTime = Date()

while app.isRunning {
    app.update()
    guard let window = app.window else { break }

    let t = Float(Date().timeIntervalSince(startTime))

    let center = SIMD2<Float>(windowSize.x / 2, windowSize.y / 2)

    // Canvas pass: spinning pink quad in canvas-local coords.
    batcherCanvas.reset()
    batcherCanvas.setTexture(whiteTex.handle)
    drawCanvas.pushTransform(.translation(x: canvasSize.x / 2, y: canvasSize.y / 2))
    drawCanvas.pushTransform(.rotation(angleRadians: t))
    drawCanvas.pushColor(Color(r: 1.0, g: 0.4, b: 0.6))
    drawCanvas.quad(rect: Rect(x: -90, y: -90, width: 180, height: 180),
                    uv: Rect(x: 0, y: 0, width: 1, height: 1),
                    color: SIMD4<Float>(1, 1, 1, 1))
    drawCanvas.popColor()
    drawCanvas.popTransform()
    drawCanvas.popTransform()

    // Main pass: everything else, plus the canvas composited back as a sprite.
    batcher.reset()
    batcher.setTexture(whiteTex.handle)

    draw.circleFill(center: center + SIMD2(220, 0), radius: 60,
                    color: Color(r: 0.4, g: 0.8, b: 1.0))
    draw.line(from: center + SIMD2(-300, -150), to: center + SIMD2(-300, 150),
              thickness: 8, color: Color(r: 1.0, g: 0.9, b: 0.3))
    draw.text("Hello, Bielik!", font: font, at: SIMD2<Float>(40, 40), color: .white)

    // PNG sprite bouncing along the bottom.
    let bounce: Float = abs(sin(t * 2)) * 60
    draw.sprite(player, at: SIMD2<Float>(120, windowSize.y - 150 - bounce))

    // Composite the offscreen canvas back at the window center.
    draw.canvas(canvas, at: center - canvasSize / 2)

    let cmd = try app.gpu.acquireCommandBuffer()
    guard let swap = cmd.acquireSwapchainTexture(for: window, device: app.gpu) else {
        cmd.submit()
        continue
    }

    let canvasBytes = batcherCanvas.vertices.count * MemoryLayout<Vertex>.stride
    let mainBytes = batcher.vertices.count * MemoryLayout<Vertex>.stride
    if canvasBytes > 0 {
        vxferCanvas.withMappedMemory(cycle: true) { ptr in
            batcherCanvas.vertices.withUnsafeBytes { src in
                ptr.copyMemory(from: src.baseAddress!, byteCount: src.count)
            }
        }
    }
    if mainBytes > 0 {
        vxfer.withMappedMemory(cycle: true) { ptr in
            batcher.vertices.withUnsafeBytes { src in
                ptr.copyMemory(from: src.baseAddress!, byteCount: src.count)
            }
        }
    }
    if canvasBytes > 0 || mainBytes > 0 {
        cmd.withCopyPass { copy in
            if canvasBytes > 0 {
                copy.upload(from: vxferCanvas, offset: 0, to: vbufCanvas, offset: 0, size: canvasBytes)
            }
            if mainBytes > 0 {
                copy.upload(from: vxfer, offset: 0, to: vbuf, offset: 0, size: mainBytes)
            }
        }
    }

    cmd.pushVertexUniform(cameraCanvas.viewProjection)
    cmd.renderTo(canvas, clear: Color(r: 0.05, g: 0.10, b: 0.30)) { pass in
        guard !batcherCanvas.vertices.isEmpty else { return }
        pass.bind(pipe)
        pass.bindVertexBuffer(vbufCanvas)
        for c in batcherCanvas.commandsSortedByLayer {
            pass.bindFragmentSampler(textureHandle: c.state.texture, sampler: sampler)
            pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
        }
    }

    cmd.pushVertexUniform(camera.viewProjection)
    cmd.withRenderPass(colorTarget: swap, clear: Color(r: 0.10, g: 0.12, b: 0.18)) { pass in
        guard !batcher.vertices.isEmpty else { return }
        pass.bind(pipe)
        pass.bindVertexBuffer(vbuf)
        for c in batcher.commandsSortedByLayer {
            pass.bindFragmentSampler(textureHandle: c.state.texture, sampler: sampler)
            pass.draw(vertexCount: c.vertexCount, firstVertex: c.vertexStart)
        }
    }
    cmd.submit()
}
app.destroy()
