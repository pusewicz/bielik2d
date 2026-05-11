import Bielik2D
import CSDL3
import Foundation

let windowSize = SIMD2<Float>(1280, 720)
let initialEntityCount = 10_000
let maxEntityCount = 100_000
let countStep = 2_000
let entityRadius: Float = 6
let spriteScale: Float = 0.35

let app = try App(title: "Bielik2D Benchmark", width: Int(windowSize.x), height: Int(windowSize.y))
if let window = app.window {
    app.gpu.setSwapchainPresentMode(.immediate, for: window)   // no vsync — measure real cost
}
print("GPU driver: \(app.gpu.driverName)")

let vs = try Shader.builtin(name: "sprite.vert", stage: .vertex, on: app.gpu)
let fs = try Shader.builtin(name: "sprite.frag", stage: .fragment, on: app.gpu)
let pipe = try app.gpu.makePipeline(
    vertex: vs, fragment: fs,
    vertexBuffer: Vertex.bufferLayout,
    colorTargetFormat: .bgra8Unorm,
    blendMode: .alpha
)

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

let playerPath = Bundle.module.url(forResource: "p1_stand", withExtension: "png", subdirectory: "assets")!.path
var player = try Sprite(png: playerPath, on: app.gpu)
player.scale = SIMD2(spriteScale, spriteScale)

let textEngine = try TextEngine(on: app.gpu)
let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 20)

// Vertex buffer sized for the maximum entity count we'll ever spawn.
let vertexBufferSize = maxEntityCount * 6 * MemoryLayout<Vertex>.stride
let vbuf = try app.gpu.makeBuffer(size: vertexBufferSize, usage: .vertex)
let vxfer = try app.gpu.makeTransferBuffer(size: vertexBufferSize, usage: .upload)

let batcher = Batcher()
let draw = Draw(batcher: batcher, textEngine: textEngine)
let camera = Camera(viewportSize: windowSize)

enum Mode { case shapes, sprites }
var mode: Mode = .shapes

struct Entity {
    var pos: SIMD2<Float>
    var vel: SIMD2<Float>
    var color: Color
}

let spriteW = Float(player.width) * spriteScale
let spriteH = Float(player.height) * spriteScale

func makeEntity() -> Entity {
    Entity(
        pos: SIMD2(Float.random(in: spriteW...windowSize.x - spriteW),
                   Float.random(in: spriteH...windowSize.y - spriteH)),
        vel: SIMD2(Float.random(in: -250...250), Float.random(in: -250...250)),
        color: Color(r: Float.random(in: 0.3...1),
                     g: Float.random(in: 0.3...1),
                     b: Float.random(in: 0.3...1))
    )
}

var entities = ContiguousArray<Entity>((0..<initialEntityCount).map { _ in makeEntity() })

@MainActor
func adjustEntityCount(by delta: Int) {
    let target = max(0, min(maxEntityCount, entities.count + delta))
    if target > entities.count {
        entities.reserveCapacity(target)
        for _ in 0..<(target - entities.count) {
            entities.append(makeEntity())
        }
    } else if target < entities.count {
        entities.removeLast(entities.count - target)
    }
}

let clock = Clock()
_ = clock.tickSeconds()           // burn the startup spike
var frameTimer = FrameTimer(windowSize: 120)

while app.isRunning {
    app.update()
    if app.keyJustPressed(SDL_SCANCODE_SPACE) {
        mode = (mode == .shapes) ? .sprites : .shapes
    }
    // '=' (unshifted '+') and the keypad '+' both grow the count.
    if app.keyJustPressed(SDL_SCANCODE_EQUALS) || app.keyJustPressed(SDL_SCANCODE_KP_PLUS) {
        adjustEntityCount(by: countStep)
    }
    // '-' and the keypad '-' shrink it.
    if app.keyJustPressed(SDL_SCANCODE_MINUS) || app.keyJustPressed(SDL_SCANCODE_KP_MINUS) {
        adjustEntityCount(by: -countStep)
    }
    guard let window = app.window else { break }

    let dt = clock.tickSeconds()
    frameTimer.record(deltaSeconds: dt)
    let dtF = Float(dt)

    // Update bouncing entities.
    let lo: SIMD2<Float>
    let hi: SIMD2<Float>
    switch mode {
    case .shapes:
        lo = SIMD2(entityRadius, entityRadius)
        hi = SIMD2(windowSize.x - entityRadius, windowSize.y - entityRadius)
    case .sprites:
        lo = SIMD2(0, 0)
        hi = SIMD2(windowSize.x - spriteW, windowSize.y - spriteH)
    }
    for i in entities.indices {
        var e = entities[i]
        e.pos += e.vel * dtF
        if e.pos.x < lo.x { e.pos.x = lo.x; e.vel.x = -e.vel.x }
        if e.pos.x > hi.x { e.pos.x = hi.x; e.vel.x = -e.vel.x }
        if e.pos.y < lo.y { e.pos.y = lo.y; e.vel.y = -e.vel.y }
        if e.pos.y > hi.y { e.pos.y = hi.y; e.vel.y = -e.vel.y }
        entities[i] = e
    }

    batcher.reset()
    switch mode {
    case .shapes:
        batcher.setTexture(whiteTex.handle)  // give the pipeline *some* texture binding
        for e in entities {
            draw.circleFill(center: e.pos, radius: entityRadius, color: e.color)
        }
    case .sprites:
        for e in entities {
            draw.sprite(player, at: e.pos)
        }
    }

    // HUD overlay.
    let avgMs = frameTimer.averageFrameSeconds * 1000.0
    let fps = frameTimer.fps
    let label = String(format: "%.0f fps  %.2f ms  %d %@  [Space swap, +/- ±%d]",
                       fps, avgMs, entities.count,
                       mode == .shapes ? "shapes" : "sprites",
                       countStep)
    draw.text(label, font: font, at: SIMD2(20, 28), color: .white)

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

    cmd.withRenderPass(colorTarget: swap, clear: Color(r: 0.07, g: 0.09, b: 0.14)) { pass in
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
