#if os(WASI)
import Bielik2D
import JavaScriptKit

/// Browser counterpart of `SDL3Platform`. Owns the `<canvas>`, drives a
/// `requestAnimationFrame` tick, and owns the engine's `Input` — feeding it from
/// DOM `keydown`/`keyup`/`mousemove`/`mousedown`/`mouseup` listeners plus a
/// per-frame poll of `navigator.getGamepads()`.
///
/// Edge semantics match native: `advanceInput()` calls `input.advanceFrame()`
/// (snapshot "previous", reset deltas) at the top of the frame, exactly where
/// `SDL3Platform.pollEvents` calls `input.beginFrame()`, then drains the frame's
/// queued DOM events into `input` — so events that arrived since the last frame
/// are applied to `current` *after* `previous` was snapshotted, just like SDL
/// events apply after `beginFrame` in the native poll loop. This is the whole
/// reason `pressed`/`released` edges resolve the same way as native.
///
/// Critically, the DOM listeners must NOT mutate `input` directly: they fire
/// asynchronously between RAF ticks, so a `keydown` that mutated `current` before
/// `advanceFrame` ran would have `previous` snapshot the *already-pressed* state,
/// erasing the rising edge (`pressed` never true). Instead each listener appends a
/// small `PendingEvent` to `pendingEvents`, and `advanceInput()` drains them in
/// arrival order after the snapshot. Gamepads have no DOM events, so we poll them
/// once per tick after draining.
public final class WebPlatform {
    /// A DOM input event captured by a listener and replayed into `input` during
    /// the next `advanceInput()` drain — after the per-frame snapshot, so it lands
    /// on `current` (not `previous`) and the edge survives. Mirrors how SDL events
    /// queue and get pumped after `beginFrame` on native.
    private enum PendingEvent {
        case keyDown(Key)
        case keyUp(Key)
        case mouseMove(point: SIMD2<Float>, delta: SIMD2<Float>)
        case mouseDown(MouseButton)
        case mouseUp(MouseButton)
        case wheel(SIMD2<Float>)
    }

    /// Events captured by DOM listeners since the last frame, drained in arrival
    /// order by `advanceInput()`. Appended to on the JS event-loop turn the browser
    /// dispatches each listener; drained once per RAF frame. Single-threaded JS, so
    /// no locking needed.
    private var pendingEvents: [PendingEvent] = []

    public let canvas: JSObject
    /// The LOGICAL design size in points (e.g. 1280×720), matching native `App.size`.
    /// The camera and mouse both live in this space — the CSS stylesheet visually
    /// scales the framebuffer to fit the page, and DPR only inflates the backing
    /// store (`sizeInPixels`). This is the design size the demo passed to `create`.
    public private(set) var size: SIMD2<Int>
    /// The canvas backing store in physical pixels = `size × pixelDensity`. This is
    /// what the WebGPU swapchain renders into; the camera never uses it.
    public private(set) var sizeInPixels: SIMD2<Int>
    /// `devicePixelRatio` captured at `attach`. The backing store is `size × this`,
    /// so it's the engine's pixel density — what `App` seeds into the ambient
    /// Font/Draw densities so HiDPI text rasterizes at native resolution.
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
    private var wheelClosure: JSClosure?

    // The browser gamepad slots we've told `Input` about (index → connected). We
    // diff this against `navigator.getGamepads()` each frame to fire connect /
    // disconnect, since the DOM events are unreliable across browsers.
    private var knownGamepads: Set<Int> = []
    // Last canvas-relative mouse position in pixels, so we can compute a delta.
    private var lastMouse: SIMD2<Float>?

    private init(canvas: JSObject, size: SIMD2<Int>, sizeInPixels: SIMD2<Int>, pixelDensity: Float) {
        self.canvas = canvas
        self.size = size
        self.sizeInPixels = sizeInPixels
        self.pixelDensity = pixelDensity
        installKeyListeners()
        installMouseListeners()
    }

    /// Attach to the `#canvasID` element and size it for a FIXED LOGICAL design of
    /// `width × height` points (the size the demo lays out at, matching native).
    ///
    /// The backing store (`canvas.width`/`height`) is set to `width × DPR` by
    /// `height × DPR` so HiDPI renders crisp; the canvas's *CSS* box is left to the
    /// page's stylesheet (`web/index.html` gives the element a responsive `width` +
    /// `aspect-ratio`), which visually scales that framebuffer to fit the page. We
    /// deliberately do NOT size the backing store from `getBoundingClientRect`: that
    /// would make the render resolution follow the CSS box and break the fixed
    /// design layout on non-1.0 DPR or narrow windows.
    public static func attach(canvasID: String, width: Int, height: Int) throws -> WebPlatform {
        guard let document = JSObject.global.document.object else {
            throw WebPlatformError.canvasNotFound(canvasID)
        }
        guard let canvas = document.getElementById!(canvasID).object else {
            throw WebPlatformError.canvasNotFound(canvasID)
        }
        let dpr = JSObject.global.devicePixelRatio.number ?? 1.0
        let pixelW = Int((Double(width) * dpr).rounded())
        let pixelH = Int((Double(height) * dpr).rounded())
        canvas["width"] = JSValue.number(Double(pixelW))
        canvas["height"] = JSValue.number(Double(pixelH))
        return WebPlatform(
            canvas: canvas,
            size: SIMD2(width, height),
            sizeInPixels: SIMD2(pixelW, pixelH),
            pixelDensity: Float(dpr)
        )
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
    /// advances exactly once before scene code reads it.
    ///
    /// Order mirrors native `SDL3Platform.pollEvents` exactly:
    /// 1. `input.advanceFrame()` — snapshot "previous = current", reset deltas.
    /// 2. drain the queued DOM events in arrival order, feeding each into `input`
    ///    so they mutate `current` *after* the snapshot (preserving the edge).
    /// 3. `pollGamepads()` — the gamepad API has no events, so we read full state.
    public func advanceInput() {
        input.advanceFrame()
        drainPendingEvents()
        pollGamepads()
    }

    /// Replay every DOM event captured since the last frame into `input`, in the
    /// order the browser dispatched them, then clear the buffer. Runs after the
    /// frame snapshot, so a `keyDown` queued between ticks lands on `current` with
    /// `previous` already false → `pressed` true for one frame, matching native.
    private func drainPendingEvents() {
        for event in pendingEvents {
            switch event {
            case .keyDown(let key): input.feedKeyDown(key)
            case .keyUp(let key): input.feedKeyUp(key)
            case .mouseMove(let point, let delta): input.feedMouseMove(to: point, delta: delta)
            case .mouseDown(let button): input.feedMouseDown(button)
            case .mouseUp(let button): input.feedMouseUp(button)
            case .wheel(let amount): input.feedMouseWheel(amount)
            }
        }
        pendingEvents.removeAll(keepingCapacity: true)
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
                self.pendingEvents.append(.keyDown(key))
            }
            return .undefined
        }
        let onKeyUp = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if let code = event["code"].string, let key = Key(browserCode: code) {
                self.pendingEvents.append(.keyUp(key))
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
            let point = self.canvasLogical(event)
            // Delta in the engine's logical space; first move seeds with zero delta.
            // `lastMouse` is updated here at capture time so successive queued moves
            // carry the right incremental delta; `Mouse.moved` accumulates them.
            let delta = self.lastMouse.map { point - $0 } ?? .zero
            self.lastMouse = point
            self.pendingEvents.append(.mouseMove(point: point, delta: delta))
            return .undefined
        }
        let onDown = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if let button = Self.mouseButton(event["button"].number) {
                self.pendingEvents.append(.mouseDown(button))
            }
            return .undefined
        }
        let onUp = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if let button = Self.mouseButton(event["button"].number) {
                self.pendingEvents.append(.mouseUp(button))
            }
            return .undefined
        }
        // Wheel events carry pixel/line deltas; feed the Y delta as a scroll amount
        // the same way native pumps `SDL_EVENT_MOUSE_WHEEL`. `deltaX`/`deltaY` are
        // in the DOM's "down/right positive" convention, matching SDL's wheel sign.
        let onWheel = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            let dx = Float(event["deltaX"].number ?? 0)
            let dy = Float(event["deltaY"].number ?? 0)
            self.pendingEvents.append(.wheel(SIMD2(dx, dy)))
            return .undefined
        }
        self.mouseMoveClosure = onMove
        self.mouseDownClosure = onDown
        self.mouseUpClosure = onUp
        self.wheelClosure = onWheel
        _ = canvas.addEventListener!("mousemove", onMove)
        _ = canvas.addEventListener!("mousedown", onDown)
        _ = canvas.addEventListener!("mouseup", onUp)
        _ = canvas.addEventListener!("wheel", onWheel)
    }

    /// A `MouseEvent` page position translated into the engine's LOGICAL design
    /// space: canvas-relative (origin top-left, +Y down) then mapped from the CSS
    /// bounding-rect size onto the fixed design size (`size`). The camera viewport
    /// is also built from `size`, so the mouse lives in the same logical space and
    /// `Camera.screenToWorld` lands on the cursor at any DPR / CSS scale. The CSS
    /// box may be any size (the stylesheet scales it responsively); this division
    /// normalizes the pointer back into design points. (Native is already in
    /// logical points, so it needs no mapping.)
    private func canvasLogical(_ event: JSObject) -> SIMD2<Float> {
        let rect = canvas.getBoundingClientRect!().object!
        let left = rect.left.number ?? 0
        let top = rect.top.number ?? 0
        let rectW = rect.width.number ?? 0
        let rectH = rect.height.number ?? 0
        let clientX = event["clientX"].number ?? 0
        let clientY = event["clientY"].number ?? 0
        let scaleX = rectW > 0 ? Double(size.x) / rectW : 1
        let scaleY = rectH > 0 ? Double(size.y) / rectH : 1
        return SIMD2(Float((clientX - left) * scaleX), Float((clientY - top) * scaleY))
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
