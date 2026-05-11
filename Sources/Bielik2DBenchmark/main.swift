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
// Start in immediate so the benchmark measures peak throughput. Toggle with V.
let presentModes: [PresentMode] = [.immediate, .vsync, .mailbox]
let presentLabels = ["immediate", "vsync", "mailbox"]
var presentIndex = 0
if let window = app.window {
    app.gpu.setSwapchainPresentMode(presentModes[presentIndex], for: window)
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
let hudLabel = try Label(font: font, engine: textEngine)

// Vertex buffer sized for the maximum entity count we'll ever spawn, plus
// headroom for HUD glyph vertices (~6 verts per character × any line we draw).
// Without this slack, frames that hit `maxEntityCount` overflow the transfer
// buffer by the HUD's worth of bytes and crash inside memmove.
let hudVertexSlack = 8_192
let vertexCapacity = maxEntityCount * 6 + hudVertexSlack
let vertexBufferSize = vertexCapacity * MemoryLayout<Vertex>.stride
let vbuf = try app.gpu.makeBuffer(size: vertexBufferSize, usage: .vertex)
let vxfer = try app.gpu.makeTransferBuffer(size: vertexBufferSize, usage: .upload)

let batcher = Batcher()
// Reserve the full peak-frame capacity once, so vertex appends never reallocate.
batcher.reserveVertexCapacity(vertexCapacity)
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

// Per-section timers — nanoseconds since boot via mach_absolute_time.
// All four blocks run every frame; we average over `profileWindow` frames
// and print to stdout so we can see which section dominates.
let timebase: (numer: UInt64, denom: UInt64) = {
    var info = mach_timebase_info()
    mach_timebase_info(&info)
    return (UInt64(info.numer), UInt64(info.denom))
}()
@inline(__always) func nowNs() -> UInt64 {
    return mach_absolute_time() * timebase.numer / timebase.denom
}
let profileWindow = 60
var profileFrames = 0
var sumUpdateNs: UInt64 = 0
var sumBatchNs: UInt64 = 0
var sumUploadNs: UInt64 = 0
var sumSubmitNs: UInt64 = 0
var maxUpdateNs: UInt64 = 0
var maxBatchNs: UInt64 = 0
var maxUploadNs: UInt64 = 0
var maxSubmitNs: UInt64 = 0

while app.isRunning {
    app.update()
    if app.keyJustPressed(SDL_SCANCODE_SPACE) {
        mode = (mode == .shapes) ? .sprites : .shapes
    }
    if app.keyJustPressed(SDL_SCANCODE_V) {
        presentIndex = (presentIndex + 1) % presentModes.count
        if let window = app.window {
            _ = app.gpu.setSwapchainPresentMode(presentModes[presentIndex], for: window)
        }
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
    let tUpdate0 = nowNs()
    entities.withUnsafeMutableBufferPointer { buf in
        for i in 0..<buf.count {
            var e = buf[i]
            e.pos += e.vel * dtF
            if e.pos.x < lo.x { e.pos.x = lo.x; e.vel.x = -e.vel.x }
            if e.pos.x > hi.x { e.pos.x = hi.x; e.vel.x = -e.vel.x }
            if e.pos.y < lo.y { e.pos.y = lo.y; e.vel.y = -e.vel.y }
            if e.pos.y > hi.y { e.pos.y = hi.y; e.vel.y = -e.vel.y }
            buf[i] = e
        }
    }
    let tUpdate1 = nowNs()

    let tBatch0 = nowNs()
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
    let maxMs = frameTimer.maxFrameSeconds * 1000.0
    let fps = frameTimer.fps
    let label = String(format: "%.0f fps  %.2f ms (peak %.2f)  %d %@  vsync:%@  [Space swap, V cycle vsync, +/- ±%d]",
                       fps, avgMs, maxMs, entities.count,
                       mode == .shapes ? "shapes" : "sprites",
                       presentLabels[presentIndex],
                       countStep)
    hudLabel.setString(label)
    draw.text(hudLabel, at: SIMD2(20, 28), color: .white)
    let tBatch1 = nowNs()

    let cmd = try app.gpu.acquireCommandBuffer()
    guard let swap = cmd.acquireSwapchainTexture(for: window, device: app.gpu) else {
        cmd.submit()
        continue
    }

    let tUpload0 = nowNs()
    let vertexBytes = batcher.vertices.count * MemoryLayout<Vertex>.stride
    if vertexBytes > vxfer.size {
        fatalError("vertex bytes \(vertexBytes) exceed transfer buffer \(vxfer.size); raise hudVertexSlack or lower maxEntityCount")
    }
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
    let tUpload1 = nowNs()

    cmd.pushVertexUniform(camera.viewProjection)

    let tSubmit0 = nowNs()
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
    let tSubmit1 = nowNs()

    let dU = tUpdate1 - tUpdate0
    let dB = tBatch1 - tBatch0
    let dUp = tUpload1 - tUpload0
    let dS = tSubmit1 - tSubmit0
    sumUpdateNs &+= dU; if dU > maxUpdateNs { maxUpdateNs = dU }
    sumBatchNs  &+= dB; if dB > maxBatchNs  { maxBatchNs  = dB }
    sumUploadNs &+= dUp; if dUp > maxUploadNs { maxUploadNs = dUp }
    sumSubmitNs &+= dS; if dS > maxSubmitNs { maxSubmitNs = dS }
    profileFrames += 1
    if profileFrames >= profileWindow {
        let n = Double(profileFrames)
        func us(_ ns: UInt64) -> Double { Double(ns) / 1_000.0 }
        print(String(format: "[%d ent] update %5.0fµs (peak %5.0f)  batch %5.0fµs (peak %5.0f)  upload %5.0fµs (peak %5.0f)  submit %5.0fµs (peak %5.0f)",
                     entities.count,
                     us(sumUpdateNs) / n, us(maxUpdateNs),
                     us(sumBatchNs)  / n, us(maxBatchNs),
                     us(sumUploadNs) / n, us(maxUploadNs),
                     us(sumSubmitNs) / n, us(maxSubmitNs)))
        profileFrames = 0
        sumUpdateNs = 0; sumBatchNs = 0; sumUploadNs = 0; sumSubmitNs = 0
        maxUpdateNs = 0; maxBatchNs = 0; maxUploadNs = 0; maxSubmitNs = 0
    }
}
app.destroy()
