#if canImport(CSDL3)
import CSDL3

extension Key {
    /// The SDL scancode this key maps to. Single source of truth for the mapping;
    /// the reverse lookup is derived from it.
    var scancode: SDL_Scancode {
        switch self {
        case .a: SDL_SCANCODE_A
        case .b: SDL_SCANCODE_B
        case .c: SDL_SCANCODE_C
        case .d: SDL_SCANCODE_D
        case .e: SDL_SCANCODE_E
        case .f: SDL_SCANCODE_F
        case .g: SDL_SCANCODE_G
        case .h: SDL_SCANCODE_H
        case .i: SDL_SCANCODE_I
        case .j: SDL_SCANCODE_J
        case .k: SDL_SCANCODE_K
        case .l: SDL_SCANCODE_L
        case .m: SDL_SCANCODE_M
        case .n: SDL_SCANCODE_N
        case .o: SDL_SCANCODE_O
        case .p: SDL_SCANCODE_P
        case .q: SDL_SCANCODE_Q
        case .r: SDL_SCANCODE_R
        case .s: SDL_SCANCODE_S
        case .t: SDL_SCANCODE_T
        case .u: SDL_SCANCODE_U
        case .v: SDL_SCANCODE_V
        case .w: SDL_SCANCODE_W
        case .x: SDL_SCANCODE_X
        case .y: SDL_SCANCODE_Y
        case .z: SDL_SCANCODE_Z
        case .digit0: SDL_SCANCODE_0
        case .digit1: SDL_SCANCODE_1
        case .digit2: SDL_SCANCODE_2
        case .digit3: SDL_SCANCODE_3
        case .digit4: SDL_SCANCODE_4
        case .digit5: SDL_SCANCODE_5
        case .digit6: SDL_SCANCODE_6
        case .digit7: SDL_SCANCODE_7
        case .digit8: SDL_SCANCODE_8
        case .digit9: SDL_SCANCODE_9
        case .left: SDL_SCANCODE_LEFT
        case .right: SDL_SCANCODE_RIGHT
        case .up: SDL_SCANCODE_UP
        case .down: SDL_SCANCODE_DOWN
        case .space: SDL_SCANCODE_SPACE
        case .enter: SDL_SCANCODE_RETURN
        case .escape: SDL_SCANCODE_ESCAPE
        case .tab: SDL_SCANCODE_TAB
        case .backspace: SDL_SCANCODE_BACKSPACE
        case .delete: SDL_SCANCODE_DELETE
        case .minus: SDL_SCANCODE_MINUS
        case .equals: SDL_SCANCODE_EQUALS
        case .keypadPlus: SDL_SCANCODE_KP_PLUS
        case .keypadMinus: SDL_SCANCODE_KP_MINUS
        case .f1: SDL_SCANCODE_F1
        case .f2: SDL_SCANCODE_F2
        case .f3: SDL_SCANCODE_F3
        case .f4: SDL_SCANCODE_F4
        case .f5: SDL_SCANCODE_F5
        case .f6: SDL_SCANCODE_F6
        case .f7: SDL_SCANCODE_F7
        case .f8: SDL_SCANCODE_F8
        case .f9: SDL_SCANCODE_F9
        case .f10: SDL_SCANCODE_F10
        case .f11: SDL_SCANCODE_F11
        case .f12: SDL_SCANCODE_F12
        case .leftShift: SDL_SCANCODE_LSHIFT
        case .rightShift: SDL_SCANCODE_RSHIFT
        case .leftControl: SDL_SCANCODE_LCTRL
        case .rightControl: SDL_SCANCODE_RCTRL
        case .leftOption: SDL_SCANCODE_LALT
        case .rightOption: SDL_SCANCODE_RALT
        case .leftCommand: SDL_SCANCODE_LGUI
        case .rightCommand: SDL_SCANCODE_RGUI
        }
    }

    /// The key for an SDL scancode, or nil if it isn't one Bielik2D names.
    init?(scancode: SDL_Scancode) {
        guard let key = Key.byScancode[scancode.rawValue] else { return nil }
        self = key
    }

    private static let byScancode: [UInt32: Key] = {
        var map: [UInt32: Key] = [:]
        for key in Key.allCases { map[key.scancode.rawValue] = key }
        return map
    }()
}
#endif
