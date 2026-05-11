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
let sampler = try app.gpu.makeSampler(filter: .nearest)

let maxVertexCount = 6 * 1024
let vertexBufferSize = maxVertexCount * MemoryLayout<Vertex>.stride
let vbuf = try app.gpu.makeBuffer(size: vertexBufferSize, usage: .vertex)
let vxfer = try app.gpu.makeTransferBuffer(size: vertexBufferSize, usage: .upload)

let textEngine = try TextEngine(on: app.gpu)
let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 28)

let batcher = Batcher()
let draw = Draw(batcher: batcher, textEngine: textEngine)
let camera = Camera(viewportSize: windowSize)
let startTime = Date()

while app.isRunning {
    app.update()
    guard let window = app.window else { break }

    let t = Float(Date().timeIntervalSince(startTime))

    batcher.reset()
    batcher.setTexture(whiteTex.handle)

    let center = SIMD2<Float>(windowSize.x / 2, windowSize.y / 2)

    draw.pushTransform(.translation(x: center.x, y: center.y))
    draw.pushTransform(.rotation(angleRadians: t))
    draw.pushColor(Color(r: 1.0, g: 0.4, b: 0.6))
    draw.quad(rect: Rect(x: -150, y: -150, width: 300, height: 300),
              uv: Rect(x: 0, y: 0, width: 1, height: 1),
              color: SIMD4<Float>(1, 1, 1, 1))
    draw.popColor()
    draw.popTransform()
    draw.popTransform()

    draw.circleFill(center: center + SIMD2(220, 0), radius: 60,
                    color: Color(r: 0.4, g: 0.8, b: 1.0))
    draw.line(from: center + SIMD2(-300, -150), to: center + SIMD2(-300, 150),
              thickness: 8, color: Color(r: 1.0, g: 0.9, b: 0.3))
    draw.text("Hello, Bielik!", font: font, at: SIMD2<Float>(40, 40), color: .white)

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

    cmd.pushVertexUniform(camera.viewProjection)

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
