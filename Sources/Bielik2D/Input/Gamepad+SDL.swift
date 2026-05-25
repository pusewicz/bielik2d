#if canImport(CSDL3)
import CSDL3

extension GamepadButton {
    /// Maps a raw SDL gamepad-button value (as carried in the event) to a button,
    /// or nil for ones Bielik2D doesn't name (touchpad, paddles, misc).
    init?(sdlRaw raw: Int32) {
        switch raw {
        case SDL_GAMEPAD_BUTTON_SOUTH.rawValue: self = .south
        case SDL_GAMEPAD_BUTTON_EAST.rawValue: self = .east
        case SDL_GAMEPAD_BUTTON_WEST.rawValue: self = .west
        case SDL_GAMEPAD_BUTTON_NORTH.rawValue: self = .north
        case SDL_GAMEPAD_BUTTON_BACK.rawValue: self = .back
        case SDL_GAMEPAD_BUTTON_GUIDE.rawValue: self = .guide
        case SDL_GAMEPAD_BUTTON_START.rawValue: self = .start
        case SDL_GAMEPAD_BUTTON_LEFT_STICK.rawValue: self = .leftStick
        case SDL_GAMEPAD_BUTTON_RIGHT_STICK.rawValue: self = .rightStick
        case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER.rawValue: self = .leftShoulder
        case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER.rawValue: self = .rightShoulder
        case SDL_GAMEPAD_BUTTON_DPAD_UP.rawValue: self = .dpadUp
        case SDL_GAMEPAD_BUTTON_DPAD_DOWN.rawValue: self = .dpadDown
        case SDL_GAMEPAD_BUTTON_DPAD_LEFT.rawValue: self = .dpadLeft
        case SDL_GAMEPAD_BUTTON_DPAD_RIGHT.rawValue: self = .dpadRight
        default: return nil
        }
    }
}

extension GamepadAxis {
    /// Maps a raw SDL gamepad-axis value (as carried in the event) to an axis.
    init?(sdlRaw raw: Int32) {
        switch raw {
        case SDL_GAMEPAD_AXIS_LEFTX.rawValue: self = .leftX
        case SDL_GAMEPAD_AXIS_LEFTY.rawValue: self = .leftY
        case SDL_GAMEPAD_AXIS_RIGHTX.rawValue: self = .rightX
        case SDL_GAMEPAD_AXIS_RIGHTY.rawValue: self = .rightY
        case SDL_GAMEPAD_AXIS_LEFT_TRIGGER.rawValue: self = .leftTrigger
        case SDL_GAMEPAD_AXIS_RIGHT_TRIGGER.rawValue: self = .rightTrigger
        default: return nil
        }
    }
}
#endif
