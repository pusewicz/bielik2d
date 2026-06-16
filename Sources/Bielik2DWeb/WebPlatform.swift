#if os(WASI)
import Bielik2D
import JavaScriptKit

/// Browser counterpart of `SDL3Platform`. Owns the `<canvas>`, drives a
/// `requestAnimationFrame` tick, and owns the engine's `Input` — feeding it from
/// DOM `keydown`/`keyup`/`mousemove`/`mousedown`/`mouseup` listeners plus a
/// per-frame poll of `navigator.getGamepads()`.
///
/// Edge semantics match native: the RAF tick calls `input.beginFrame()` (snapshot
/// "previous", reset deltas) at the top of the frame, exactly where
/// `SDL3Platform.pollEvents` does, so `pressed`/`released` resolve the same way.
/// Keyboard/mouse events stream in asynchronously between ticks and mutate `input`
/// directly — they sit on top of the frame's snapshot, just like SDL events do
/// after `beginFrame` in the native poll loop. Gamepads have no DOM events, so we
/// poll them once per tick right after `beginFrame`.
public final class WebPlatform {
    public let canvas: JSObject
    public private(set) var size: SIMD2<Int>
    /// `devicePixelRatio` captured at `attach`. The canvas `size` is CSS × this, so
    /// it's the engine's pixel density — what `App` seeds into the ambient Font/Draw
    /// densities so HiDPI text rasterizes at native resolution.
    public let pixelDensity: Float
    public private(set) var shouldQuit: Bool = false

    /// The engine input the web `App` exposes to scene code — same `Input` class
    /// core gives the native backend.
    public let input = Input()

    private var rafClosure: JSClosure?
    private var keyDownClosure: JSClosure?
    private var keyUpClosure: JSClosure?
    private var mouseMoveClosure: JSClosure?
    private var mouseDownClosure: JSClosure?
    private var mouseUpClosure: JSClosure?

    // The browser gamepad slots we've told `Input` about (index → connected). We
    // diff this against `navigator.getGamepads()` each frame to fire connect /
    // disconnect, since the DOM events are unreliable across browsers.
    private var knownGamepads: Set<Int> = []
    // Last canvas-relative mouse position in pixels, so we can compute a delta.
    private var lastMouse: SIMD2<Float>?

    private init(canvas: JSObject, size: SIMD2<Int>, pixelDensity: Float) {
        self.canvas = canvas
        self.size = size
        self.pixelDensity = pixelDensity
        installKeyListeners()
        installMouseListeners()
    }

    public static func attach(canvasID: String) throws -> WebPlatform {
        guard let document = JSObject.global.document.object else {
            throw WebPlatformError.canvasNotFound(canvasID)
        }
        guard let canvas = document.getElementById!(canvasID).object else {
            throw WebPlatformError.canvasNotFound(canvasID)
        }
        let dpr = JSObject.global.devicePixelRatio.number ?? 1.0
        let rectValue = canvas.getBoundingClientRect!()
        let rect = rectValue.object!
        let cssW = rect.width.number ?? 0
        let cssH = rect.height.number ?? 0
        let w = Int((cssW * dpr).rounded())
        let h = Int((cssH * dpr).rounded())
        canvas["width"] = JSValue.number(Double(w))
        canvas["height"] = JSValue.number(Double(h))
        return WebPlatform(canvas: canvas, size: SIMD2(w, h), pixelDensity: Float(dpr))
    }

    /// Drives `body` once per `requestAnimationFrame`. The closure receives
    /// the time delta in seconds since the previous frame.
    ///
    /// This schedules the loop only — it does NOT advance input. Per-frame input
    /// edges (`input.advanceFrame()`) and gamepad polling are the `App.update()`'s
    /// job now, so a frame advances input exactly once: `body` is the demo's
    /// `runFrame`, which calls `app.update()` (→ `advanceInput()`) at its top,
    /// before any scene code reads `pressed`/`released`. Mirrors native, where
    /// `App.update()` (not the loop) drives input.
    public func run(_ body: @escaping (Double) -> Void) {
        var lastTime: Double = 0
        let global = JSObject.global

        let tick = JSClosure { [weak self] args in
            guard let self else { return .undefined }
            let now = args.first?.number ?? 0
            let dt = lastTime == 0 ? 0 : (now - lastTime) / 1000.0
            lastTime = now
            body(dt)
            if !self.shouldQuit, let next = self.rafClosure {
                _ = global.requestAnimationFrame!(next)
            }
            return .undefined
        }
        self.rafClosure = tick
        _ = global.requestAnimationFrame!(tick)
    }

    /// Advance the per-frame input edges and poll the gamepads — the work the RAF
    /// tick used to do inline. Called once per frame by `App.update()` so input
    /// advances exactly once before scene code reads it. Snapshots "previous"
    /// (`input.advanceFrame()`), then pushes the current gamepad snapshot, exactly
    /// where `SDL3Platform.pollEvents` sits in the native frame.
    public func advanceInput() {
        input.advanceFrame()
        pollGamepads()
    }

    public func requestQuit() {
        shouldQuit = true
    }

    // MARK: - Keyboard

    private func installKeyListeners() {
        let onKeyDown = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            // Skip auto-repeat: a held key must not re-fire `pressed` each frame,
            // matching native (`!ev.key.repeat`).
            if event["repeat"].boolean == true { return .undefined }
            if let code = event["code"].string, let key = Key(browserCode: code) {
                self.input.feedKeyDown(key)
            }
            return .undefined
        }
        let onKeyUp = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if let code = event["code"].string, let key = Key(browserCode: code) {
                self.input.feedKeyUp(key)
            }
            return .undefined
        }
        self.keyDownClosure = onKeyDown
        self.keyUpClosure = onKeyUp
        _ = JSObject.global.addEventListener!("keydown", onKeyDown)
        _ = JSObject.global.addEventListener!("keyup", onKeyUp)
    }

    // MARK: - Mouse

    private func installMouseListeners() {
        let onMove = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            let point = self.canvasPixel(event)
            // Delta in the engine's pixel space; first move seeds with zero delta.
            let delta = self.lastMouse.map { point - $0 } ?? .zero
            self.lastMouse = point
            self.input.feedMouseMove(to: point, delta: delta)
            return .undefined
        }
        let onDown = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if let button = Self.mouseButton(event["button"].number) {
                self.input.feedMouseDown(button)
            }
            return .undefined
        }
        let onUp = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if let button = Self.mouseButton(event["button"].number) {
                self.input.feedMouseUp(button)
            }
            return .undefined
        }
        self.mouseMoveClosure = onMove
        self.mouseDownClosure = onDown
        self.mouseUpClosure = onUp
        _ = canvas.addEventListener!("mousemove", onMove)
        _ = canvas.addEventListener!("mousedown", onDown)
        _ = canvas.addEventListener!("mouseup", onUp)
    }

    /// A `MouseEvent` page position translated into the engine's pixel space:
    /// canvas-relative (origin top-left, +Y down) then scaled by devicePixelRatio.
    /// The web camera viewport is built from `size` (CSS × DPR = pixels), so the
    /// mouse must live in that same pixel space for `Camera.screenToWorld` to land
    /// on the cursor. (Native differs: there both the camera and SDL motion events
    /// are in logical points, so native needs no DPR scale.)
    private func canvasPixel(_ event: JSObject) -> SIMD2<Float> {
        let dpr = JSObject.global.devicePixelRatio.number ?? 1.0
        let rect = canvas.getBoundingClientRect!().object!
        let left = rect.left.number ?? 0
        let top = rect.top.number ?? 0
        let clientX = event["clientX"].number ?? 0
        let clientY = event["clientY"].number ?? 0
        return SIMD2(Float((clientX - left) * dpr), Float((clientY - top) * dpr))
    }

    /// Maps a `MouseEvent.button` index to a `MouseButton` (0 left, 1 middle,
    /// 2 right, 3 back/x1, 4 forward/x2), or nil for anything else.
    private static func mouseButton(_ index: Double?) -> MouseButton? {
        switch index {
        case 0: .left
        case 1: .middle
        case 2: .right
        case 3: .x1
        case 4: .x2
        default: nil
        }
    }

    // MARK: - Gamepad

    /// Polls `navigator.getGamepads()` and pushes the snapshot into `Input`. The
    /// Gamepad API has no per-press events, so each frame we read the full state
    /// and translate it through `press`/`release` against the device's diff. If no
    /// pad is connected the loop does nothing and `input.gamepad(0)` stays the
    /// disconnected stand-in — never crashes.
    private func pollGamepads() {
        guard let navigator = JSObject.global.navigator.object,
              let pads = navigator.getGamepads?().object
        else { return }

        var seen: Set<Int> = []
        let count = Int(pads.length.number ?? 0)
        for index in 0..<count {
            guard let pad = pads[index].object, pad.connected.boolean == true else { continue }
            seen.insert(index)
            if !knownGamepads.contains(index) {
                input.feedGamepadConnected(slot: index)
                knownGamepads.insert(index)
            }
            guard input.hasGamepad(slot: index) else { continue }
            applyButtons(pad, slot: index)
            applyAxes(pad, slot: index)
        }

        // Disconnect any slot we knew about that's gone this frame.
        for index in knownGamepads where !seen.contains(index) {
            input.feedGamepadDisconnected(slot: index)
        }
        knownGamepads = seen
    }

    /// The W3C "Standard Gamepad" button layout — the order Chrome/Firefox/Safari
    /// report for a mapped controller. The demo's InputScene only reads
    /// `leftStick`, but face buttons / shoulders / dpad are cheap to cover too.
    /// TODO: triggers (indices 6/7) are analog buttons here; we surface them as
    /// digital shoulder-ish presses only via `value > 0.5` below, and do not yet
    /// route their analog value into `leftTrigger`/`rightTrigger` (the Standard
    /// Gamepad exposes triggers as buttons, not axes). Wire those when a scene
    /// needs analog trigger pull.
    private static let standardButtons: [GamepadButton?] = [
        .south, .east, .west, .north,
        .leftShoulder, .rightShoulder,
        nil, nil,                 // 6/7: left/right trigger (analog button) — see TODO
        .back, .start,
        .leftStick, .rightStick,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .guide,                   // 16
    ]

    private func applyButtons(_ pad: JSObject, slot: Int) {
        guard let buttons = pad.buttons.object else { return }
        let count = Int(buttons.length.number ?? 0)
        for index in 0..<min(count, Self.standardButtons.count) {
            guard let mapped = Self.standardButtons[index],
                  let button = buttons[index].object
            else { continue }
            // `pressed` is the boolean GamepadButton flag; analog buttons (triggers)
            // also expose `value`, but the mapped entries here are all digital.
            if button.pressed.boolean == true {
                input.feedGamepadButtonDown(slot: slot, mapped)
            } else {
                input.feedGamepadButtonUp(slot: slot, mapped)
            }
        }
    }

    private func applyAxes(_ pad: JSObject, slot: Int) {
        guard let axes = pad.axes.object else { return }
        let count = Int(axes.length.number ?? 0)
        // Standard Gamepad axes: 0 leftX, 1 leftY, 2 rightX, 3 rightY. Already
        // normalized to -1…1 by the browser, so feed them straight through.
        let mapping: [(Int, GamepadAxis)] = [
            (0, .leftX), (1, .leftY), (2, .rightX), (3, .rightY),
        ]
        for (index, axis) in mapping where index < count {
            if let value = axes[index].number {
                input.feedGamepadAxis(slot: slot, axis, Float(value))
            }
        }
    }
}

public enum WebPlatformError: Error, CustomStringConvertible {
    case canvasNotFound(String)

    public var description: String {
        switch self {
        case .canvasNotFound(let id): "canvas element '#\(id)' not found in DOM"
        }
    }
}
#endif
