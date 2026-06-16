extension Key {
    /// The `KeyboardEvent.code` string this key maps to. `code` is layout-
    /// independent (physical key), the browser analogue of an SDL scancode, so the
    /// mapping mirrors `Key+SDL.swift`. Single source of truth; the reverse lookup
    /// is derived from it.
    ///
    /// `Key` is platform-neutral, so this lives unguarded in core — the web
    /// backend imports it, but it pulls in no browser symbols.
    var browserCode: String {
        switch self {
        case .a: "KeyA"
        case .b: "KeyB"
        case .c: "KeyC"
        case .d: "KeyD"
        case .e: "KeyE"
        case .f: "KeyF"
        case .g: "KeyG"
        case .h: "KeyH"
        case .i: "KeyI"
        case .j: "KeyJ"
        case .k: "KeyK"
        case .l: "KeyL"
        case .m: "KeyM"
        case .n: "KeyN"
        case .o: "KeyO"
        case .p: "KeyP"
        case .q: "KeyQ"
        case .r: "KeyR"
        case .s: "KeyS"
        case .t: "KeyT"
        case .u: "KeyU"
        case .v: "KeyV"
        case .w: "KeyW"
        case .x: "KeyX"
        case .y: "KeyY"
        case .z: "KeyZ"
        case .digit0: "Digit0"
        case .digit1: "Digit1"
        case .digit2: "Digit2"
        case .digit3: "Digit3"
        case .digit4: "Digit4"
        case .digit5: "Digit5"
        case .digit6: "Digit6"
        case .digit7: "Digit7"
        case .digit8: "Digit8"
        case .digit9: "Digit9"
        case .left: "ArrowLeft"
        case .right: "ArrowRight"
        case .up: "ArrowUp"
        case .down: "ArrowDown"
        case .space: "Space"
        case .enter: "Enter"
        case .escape: "Escape"
        case .tab: "Tab"
        case .backspace: "Backspace"
        case .delete: "Delete"
        case .minus: "Minus"
        case .equals: "Equal"
        case .keypadPlus: "NumpadAdd"
        case .keypadMinus: "NumpadSubtract"
        case .f1: "F1"
        case .f2: "F2"
        case .f3: "F3"
        case .f4: "F4"
        case .f5: "F5"
        case .f6: "F6"
        case .f7: "F7"
        case .f8: "F8"
        case .f9: "F9"
        case .f10: "F10"
        case .f11: "F11"
        case .f12: "F12"
        case .leftShift: "ShiftLeft"
        case .rightShift: "ShiftRight"
        case .leftControl: "ControlLeft"
        case .rightControl: "ControlRight"
        case .leftOption: "AltLeft"
        case .rightOption: "AltRight"
        case .leftCommand: "MetaLeft"
        case .rightCommand: "MetaRight"
        }
    }

    /// The key for a `KeyboardEvent.code` string, or nil if it isn't one
    /// Bielik2D names.
    public init?(browserCode: String) {
        guard let key = Key.byBrowserCode[browserCode] else { return nil }
        self = key
    }

    private static let byBrowserCode: [String: Key] = {
        var map: [String: Key] = [:]
        for key in Key.allCases { map[key.browserCode] = key }
        return map
    }()
}
