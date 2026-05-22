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
app.setPresentMode(presentModes[presentIndex])
print("GPU driver: \(app.driverName)")

let playerPath = Bundle.module.url(forResource: "p1_stand", withExtension: "png", subdirectory: "assets")!.path
var player = try app.renderer.makeSprite(png: playerPath)
player.scale = SIMD2(spriteScale, spriteScale)

let textEngine = try app.renderer.makeTextEngine()
let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 20)
let hudLabel = try Label(font: font, engine: textEngine)

let draw = Draw(textEngine: textEngine)
draw.reserveVertexCapacity(maxEntityCount * 6 + 8_192)
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
let hudRebuildInterval = 4
var hudFrameCounter = 0
var sumUpdateNs: UInt64 = 0
var sumBatchNs: UInt64 = 0
var sumPresentNs: UInt64 = 0
var maxUpdateNs: UInt64 = 0
var maxBatchNs: UInt64 = 0
var maxPresentNs: UInt64 = 0

while app.isRunning {
    app.update()
    if app.keyJustPressed(SDL_SCANCODE_SPACE) {
        mode = (mode == .shapes) ? .sprites : .shapes
    }
    if app.keyJustPressed(SDL_SCANCODE_V) {
        presentIndex = (presentIndex + 1) % presentModes.count
        app.setPresentMode(presentModes[presentIndex])
    }
    if app.keyJustPressed(SDL_SCANCODE_EQUALS) || app.keyJustPressed(SDL_SCANCODE_KP_PLUS) {
        adjustEntityCount(by: countStep)
    }
    if app.keyJustPressed(SDL_SCANCODE_MINUS) || app.keyJustPressed(SDL_SCANCODE_KP_MINUS) {
        adjustEntityCount(by: -countStep)
    }

    let dt = clock.tickSeconds()
    frameTimer.record(deltaSeconds: dt)
    let dtF = Float(dt)

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

    // Batch: queueing draws into the Draw (CPU only — no GPU work yet).
    let tBatch0 = nowNs()
    switch mode {
    case .shapes:
        for e in entities {
            draw.circleFill(center: e.pos, radius: entityRadius, color: e.color)
        }
    case .sprites:
        for e in entities {
            draw.sprite(player, at: e.pos)
        }
    }
    if hudFrameCounter % hudRebuildInterval == 0 {
        let avgMs = frameTimer.averageFrameSeconds * 1000.0
        let maxMs = frameTimer.maxFrameSeconds * 1000.0
        let fps = frameTimer.fps
        let label = String(format: "%.0f fps  %.2f ms (peak %.2f)  %d %@  %d calls  vsync:%@  [Space swap, V cycle vsync, +/- ±%d]",
                           fps, avgMs, maxMs, entities.count,
                           mode == .shapes ? "shapes" : "sprites",
                           app.renderer.lastDrawCallCount,
                           presentLabels[presentIndex],
                           countStep)
        hudLabel.setString(label)
    }
    hudFrameCounter &+= 1
    draw.text(hudLabel, at: SIMD2(20, 28), color: .white)
    let tBatch1 = nowNs()

    // Present: upload + render pass + submit, all inside drawOntoScreen.
    let tPresent0 = nowNs()
    app.drawOntoScreen(draw, clear: Color(r: 0.07, g: 0.09, b: 0.14), camera: camera)
    let tPresent1 = nowNs()

    let dU = tUpdate1 - tUpdate0
    let dB = tBatch1 - tBatch0
    let dP = tPresent1 - tPresent0
    sumUpdateNs &+= dU; if dU > maxUpdateNs { maxUpdateNs = dU }
    sumBatchNs  &+= dB; if dB > maxBatchNs  { maxBatchNs  = dB }
    sumPresentNs &+= dP; if dP > maxPresentNs { maxPresentNs = dP }
    profileFrames += 1
    if profileFrames >= profileWindow {
        let n = Double(profileFrames)
        func us(_ ns: UInt64) -> Double { Double(ns) / 1_000.0 }
        print(String(format: "[%d ent] update %5.0fµs (peak %5.0f)  batch %5.0fµs (peak %5.0f)  present %5.0fµs (peak %5.0f)",
                     entities.count,
                     us(sumUpdateNs) / n, us(maxUpdateNs),
                     us(sumBatchNs)  / n, us(maxBatchNs),
                     us(sumPresentNs) / n, us(maxPresentNs)))
        profileFrames = 0
        sumUpdateNs = 0; sumBatchNs = 0; sumPresentNs = 0
        maxUpdateNs = 0; maxBatchNs = 0; maxPresentNs = 0
    }
}
app.destroy()
