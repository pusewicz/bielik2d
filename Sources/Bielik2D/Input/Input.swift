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
}
