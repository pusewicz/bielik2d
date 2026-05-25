import Bielik2D
import Foundation

let windowSize = SIMD2<Float>(1280, 720)
let unit = Rect(x: 0, y: 0, width: 1, height: 1)

let app = try App(title: "Bielik2D Demo", width: Int(windowSize.x), height: Int(windowSize.y))
print("GPU driver: \(app.driverName)")

func assetPath(_ name: String, _ ext: String) -> String {
    Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "assets")!.path
}

// The ergonomic load: no renderer handle, just a path. The App installed the ambient
// renderer, so `Sprite(path:)` finds it. Asking twice reuses the same cached asset.
let player = try Sprite(path: assetPath("p1_stand", "png"))
let playerAgain = try Sprite(path: assetPath("p1_stand", "png"))
print("dedup: same asset on second load = \(player == playerAgain)")

// A procedurally-built 4-frame sheet (colour cycling) shown as a looping animation —
// no Aseprite needed, just an in-memory sheet sliced into frames.
func colorSheet(cell: Int, colors: [[UInt8]]) -> ImageBytes {
    let w = cell * colors.count
    var px = [UInt8](repeating: 0, count: w * cell * 4)
    for (c, color) in colors.enumerated() {
        for y in 0..<cell {
            for x in 0..<cell {
                let o = (y * w + c * cell + x) * 4
                px[o] = color[0]; px[o + 1] = color[1]; px[o + 2] = color[2]; px[o + 3] = 255
            }
        }
    }
    return ImageBytes(width: w, height: cell, pixels: Data(px))
}
var blinker = app.renderer.makeSprite(
    sheet: colorSheet(cell: 32, colors: [[230, 70, 70], [70, 200, 90], [80, 120, 240], [240, 200, 60]]),
    frameWidth: 32, frameHeight: 32, fps: 6)
blinker.scale = SIMD2(3, 3)
blinker.scaleMode = .nearest

let font = try Font(path: "/System/Library/Fonts/Geneva.ttf", ptSize: 28)
let canvas = try app.renderer.makeCanvas(width: 256, height: 256, format: .bgra8Unorm)
let canvasSize = SIMD2<Float>(256, 256)

let draw = Draw(textEngine: try app.renderer.makeTextEngine())
let cameraCanvas = Camera(viewportSize: canvasSize)
let camera = Camera(viewportSize: windowSize)
let startTime = Date()
var lastTime = startTime

// Input showcase: a sprite the player drives, plus a cursor dot.
var playerPos = windowSize / 2
let moveSpeed: Float = 320

// Audio showcase: a procedurally-generated decaying blip (no asset file needed).
func blipWav() -> Data {
    let sampleRate = 48_000
    let frames = sampleRate * 12 / 100  // 0.12s
    var bytes = [UInt8]()
    func u32(_ v: Int) { let x = UInt32(v); bytes += [UInt8(x & 0xff), UInt8((x >> 8) & 0xff), UInt8((x >> 16) & 0xff), UInt8((x >> 24) & 0xff)] }
    func u16(_ v: Int) { let x = UInt16(v); bytes += [UInt8(x & 0xff), UInt8((x >> 8) & 0xff)] }
    func ascii(_ s: String) { bytes += Array(s.utf8) }
    let dataSize = frames * 2
    ascii("RIFF"); u32(36 + dataSize); ascii("WAVE")
    ascii("fmt "); u32(16); u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
    ascii("data"); u32(dataSize)
    for i in 0..<frames {
        let tt = Double(i) / Double(sampleRate)
        let s = sin(2 * .pi * 660 * tt) * exp(-tt * 18) * 0.6  // decaying tone
        let v = UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32767))
        bytes.append(UInt8(v & 0xff)); bytes.append(UInt8((v >> 8) & 0xff))
    }
    return Data(bytes)
}
let blip = try app.audio?.makeSound(bytes: blipWav())

while app.isRunning {
    app.update()

    let now = Date()
    let t = Float(now.timeIntervalSince(startTime))
    let dt = now.timeIntervalSince(lastTime)
    lastTime = now

    // Move the player with WASD/arrows (digital) or the left stick (analog). +Y
    // is down, so "up" is -Y. Held state drives continuous movement.
    let keyboard = app.input.keyboard
    let gamepad = app.input.gamepad(0)
    var move = SIMD2<Float>(0, 0)
    if keyboard.down(.a) || keyboard.down(.left) { move.x -= 1 }
    if keyboard.down(.d) || keyboard.down(.right) { move.x += 1 }
    if keyboard.down(.w) || keyboard.down(.up) { move.y -= 1 }
    if keyboard.down(.s) || keyboard.down(.down) { move.y += 1 }
    move += gamepad.leftStick
    playerPos += move * moveSpeed * Float(dt)

    // Space fires the blip with a random pitch, panned by the mouse's x position.
    if keyboard.pressed(.space), let blip {
        let pan = app.input.mouse.position.x / windowSize.x * 2 - 1
        blip.play(pan: pan, pitch: Float.random(in: 0.8...1.4))
    }

    // Canvas pass: a spinning pink quad, in canvas-local coords. `with` scopes
    // the transform + tint and pops them automatically.
    draw.with(transform: .translation(x: canvasSize.x / 2, y: canvasSize.y / 2) * .rotation(angleRadians: t),
              color: Color(r: 1.0, g: 0.4, b: 0.6)) {
        draw.quad(rect: Rect(x: -90, y: -90, width: 180, height: 180), uv: unit, color: .one)
    }
    app.renderer.render(draw, to: canvas, clear: Color(r: 0.05, g: 0.10, b: 0.30), camera: cameraCanvas)

    // Main pass.
    draw.text("Hello, Bielik!", font: font, at: SIMD2<Float>(40, 40), color: .white)
    draw.circleFill(center: SIMD2(120, 150), radius: 50, color: Color(r: 0.4, g: 0.8, b: 1.0))
    draw.line(from: SIMD2(210, 110), to: SIMD2(360, 190),
              thickness: 8, color: Color(r: 1.0, g: 0.9, b: 0.3))

    // The looping animation: advance playback, then draw it with the sprite's own
    // `draw(at:)` sugar (queues into the ambient Draw).
    blinker.update(dt)
    blinker.draw(at: SIMD2(420, 110))
    draw.text("animated sheet", font: font, at: SIMD2(420, 210), color: .white)

    // Pixel-art showcase: one sprite upscaled three ways. The scale sweeps
    // through non-integer factors, so nearest visibly shimmers, linear stays
    // soft, and pixelArt stays crisp *and* stable — the whole point of
    // SDL_SCALEMODE_PIXELART.
    let upscale: Float = 2.75 + sin(t) * 0.75
    var demoSprite = player
    demoSprite.scale = SIMD2(upscale, upscale)
    let spriteW = Float(player.width) * upscale
    let spriteH = Float(player.height) * upscale
    let gap: Float = 70
    let baseline = windowSize.y - 70
    let startX = (windowSize.x - (spriteW * 3 + gap * 2)) / 2
    let modes: [(ScaleMode, String)] = [(.nearest, "nearest"), (.linear, "linear"), (.pixelArt, "pixelArt")]
    for (i, entry) in modes.enumerated() {
        let x = startX + Float(i) * (spriteW + gap)
        demoSprite.draw(at: SIMD2(x, baseline - spriteH), scaleMode: entry.0)
        draw.text(entry.1, font: font, at: SIMD2(x, baseline + 6), color: .white)
    }

    // The player-driven sprite and a hint.
    var controlled = player
    controlled.scale = SIMD2(2, 2)
    controlled.scaleMode = .nearest
    controlled.draw(at: playerPos)
    draw.text("WASD / arrows / left-stick to move · space: blip", font: font, at: SIMD2(40, 80), color: .white)

    // Mouse aim: a dot at the cursor in world space (via screenToWorld), larger
    // while the left button is held.
    let aim = camera.screenToWorld(app.input.mouse.position)
    let aiming = app.input.mouse.down(.left)
    draw.circleFill(center: aim, radius: aiming ? 18 : 10, color: Color(r: 1.0, g: 0.5, b: 0.2))

    // Composite the offscreen canvas top-right, upscaled with pixel-art sampling.
    draw.with(scaleMode: .pixelArt) {
        draw.canvas(canvas, at: SIMD2(windowSize.x - canvasSize.x - 40, 40))
    }

    app.drawOntoScreen(draw, clear: Color(r: 0.10, g: 0.12, b: 0.18), camera: camera)
}
app.destroy()
