/// The per-frame input snapshot, reached via `app.input`. The platform's event
/// pump calls `beginFrame()` once per frame and then drives the device mutators
/// as events arrive; game code only queries the devices.
public final class Input {
    public let keyboard = Keyboard()

    /// Advance every device to a new frame (snapshot "previous", reset deltas).
    func beginFrame() {
        keyboard.beginFrame()
    }
}
