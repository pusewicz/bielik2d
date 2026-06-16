/// The per-frame input snapshot, reached via `app.input`. The platform's event
/// pump calls `beginFrame()` once per frame and then drives the device mutators
/// as events arrive; game code only queries the devices.
public final class Input {
    public let keyboard = Keyboard()
    public let mouse = Mouse()

    // Connected gamepads, keyed by an opaque backend id, plus the connection
    // order that defines slot indices for `gamepad(_:)`.
    private var gamepadsByID: [Int: Gamepad] = [:]
    private var gamepadOrder: [Int] = []

    /// Backends in other modules (e.g. `Bielik2DWeb`) construct their own `Input`
    /// and feed it via the backend seam below; the native backend lives in this
    /// module and uses the same instance through `App`.
    public init() {}

    /// The gamepad in the given slot (0 = first connected), or a disconnected
    /// stand-in if the slot is empty — so callers never need a nil-check.
    public func gamepad(_ index: Int) -> Gamepad {
        guard index >= 0, index < gamepadOrder.count,
            let pad = gamepadsByID[gamepadOrder[index]]
        else { return .disconnected }
        return pad
    }

    @discardableResult
    func connectGamepad(id: Int) -> Gamepad {
        let pad = Gamepad(connected: true)
        gamepadsByID[id] = pad
        gamepadOrder.append(id)
        return pad
    }

    func disconnectGamepad(id: Int) {
        gamepadsByID[id] = nil
        gamepadOrder.removeAll { $0 == id }
    }

    func gamepad(byID id: Int) -> Gamepad? { gamepadsByID[id] }

    /// Advance every device to a new frame (snapshot "previous", reset deltas).
    func beginFrame() {
        keyboard.beginFrame()
        mouse.beginFrame()
        for pad in gamepadsByID.values { pad.beginFrame() }
    }

    // MARK: - Backend feed

    // The device mutators above are internal so game code can't forge input; the
    // native `SDL3Platform` lives in this module and calls them directly. Backends
    // in *other* modules (e.g. `Bielik2DWeb`) can't reach internals, so this small
    // public seam lets them push the same events through the same edge model.
    // Keep it backend-only in spirit — scene code has no reason to call it.

    /// Advance every device to a new frame. The backend's per-frame tick calls
    /// this before feeding the frame's events, exactly like the native poll loop.
    public func advanceFrame() { beginFrame() }

    /// Mark a key down (on `up → down`, skip auto-repeat before calling).
    public func feedKeyDown(_ key: Key) { keyboard.press(key) }
    /// Mark a key up.
    public func feedKeyUp(_ key: Key) { keyboard.release(key) }

    /// Move the mouse to `point` (window/pixel space the camera uses), with the
    /// motion `delta` since the last move.
    public func feedMouseMove(to point: SIMD2<Float>, delta: SIMD2<Float>) {
        mouse.moved(to: point, relative: delta)
    }
    /// Accumulate a scroll-wheel delta this frame.
    public func feedMouseWheel(_ amount: SIMD2<Float>) { mouse.scrolled(amount) }
    /// Mark a mouse button down.
    public func feedMouseDown(_ button: MouseButton) { mouse.press(button) }
    /// Mark a mouse button up.
    public func feedMouseUp(_ button: MouseButton) { mouse.release(button) }

    /// Register a connected gamepad in `slot` (idempotent).
    public func feedGamepadConnected(slot: Int) {
        if gamepad(byID: slot) == nil { connectGamepad(id: slot) }
    }
    /// Remove a gamepad slot.
    public func feedGamepadDisconnected(slot: Int) { disconnectGamepad(id: slot) }
    /// Mark a button down on the gamepad in `slot` (no-op if absent).
    public func feedGamepadButtonDown(slot: Int, _ button: GamepadButton) {
        gamepad(byID: slot)?.press(button)
    }
    /// Mark a button up on the gamepad in `slot` (no-op if absent).
    public func feedGamepadButtonUp(slot: Int, _ button: GamepadButton) {
        gamepad(byID: slot)?.release(button)
    }
    /// Set an analog axis (already normalized) on the gamepad in `slot`.
    public func feedGamepadAxis(slot: Int, _ axis: GamepadAxis, _ value: Float) {
        gamepad(byID: slot)?.setAxis(axis, value)
    }
    /// Whether a gamepad is registered in `slot`.
    public func hasGamepad(slot: Int) -> Bool { gamepad(byID: slot) != nil }
}
