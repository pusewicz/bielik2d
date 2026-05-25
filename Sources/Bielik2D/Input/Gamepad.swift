/// Per-frame state for one gamepad. Buttons use the same current/previous diff
/// as `Keyboard`; analog axes are stored raw (no deadzone — the caller applies
/// its own). A disconnected pad answers `false`/`zero` so game code needs no
/// nil-checks: `app.input.gamepad(0)` is always safe to query.
public final class Gamepad {
    public let isConnected: Bool

    private var current: Set<GamepadButton> = []
    private var previous: Set<GamepadButton> = []
    private var leftX: Float = 0, leftY: Float = 0
    private var rightX: Float = 0, rightY: Float = 0
    public private(set) var leftTrigger: Float = 0
    public private(set) var rightTrigger: Float = 0

    public var leftStick: SIMD2<Float> { SIMD2(leftX, leftY) }
    public var rightStick: SIMD2<Float> { SIMD2(rightX, rightY) }

    init(connected: Bool) { self.isConnected = connected }

    /// A stand-in for an empty slot — always disconnected, all queries false/zero.
    public static var disconnected: Gamepad { Gamepad(connected: false) }

    func beginFrame() { previous = current }
    func press(_ button: GamepadButton) { current.insert(button) }
    func release(_ button: GamepadButton) { current.remove(button) }

    func setAxis(_ axis: GamepadAxis, _ value: Float) {
        switch axis {
        case .leftX: leftX = value
        case .leftY: leftY = value
        case .rightX: rightX = value
        case .rightY: rightY = value
        case .leftTrigger: leftTrigger = value
        case .rightTrigger: rightTrigger = value
        }
    }

    /// True while the button is held.
    public func down(_ button: GamepadButton) -> Bool { current.contains(button) }

    /// True only on the frame the button transitioned up → down.
    public func pressed(_ button: GamepadButton) -> Bool {
        current.contains(button) && !previous.contains(button)
    }

    /// True only on the frame the button transitioned down → up.
    public func released(_ button: GamepadButton) -> Bool {
        !current.contains(button) && previous.contains(button)
    }

    /// Maps an SDL stick-axis integer (-32768…32767) to -1…1, clamped.
    public static func normalizedAxis(_ raw: Int16) -> Float {
        max(-1, Float(raw) / 32767)
    }

    /// Maps an SDL trigger integer (0…32767) to 0…1, clamped.
    public static func normalizedTrigger(_ raw: Int16) -> Float {
        max(0, Float(raw) / 32767)
    }
}
