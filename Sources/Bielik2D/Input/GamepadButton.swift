/// A gamepad button, named independently of any backend. Face buttons follow
/// SDL's position-based naming (south/east/west/north) rather than ABXY so the
/// meaning is consistent across controller layouts.
public enum GamepadButton: Hashable, Sendable, CaseIterable {
    case south, east, west, north
    case back, guide, start
    case leftStick, rightStick
    case leftShoulder, rightShoulder
    case dpadUp, dpadDown, dpadLeft, dpadRight
}

/// A gamepad analog axis. Sticks range -1…1; triggers range 0…1.
public enum GamepadAxis: Hashable, Sendable {
    case leftX, leftY, rightX, rightY, leftTrigger, rightTrigger

    var isTrigger: Bool { self == .leftTrigger || self == .rightTrigger }
}
