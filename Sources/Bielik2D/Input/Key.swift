/// A keyboard key, named independently of any backend so game code never sees
/// SDL scancodes. The SDL mapping lives in `Key+SDL.swift`.
public enum Key: Hashable, Sendable, CaseIterable {
    // Letters
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z

    // Number row
    case digit0, digit1, digit2, digit3, digit4
    case digit5, digit6, digit7, digit8, digit9

    // Arrows
    case left, right, up, down

    // Whitespace & editing
    case space, enter, escape, tab, backspace, delete

    // Symbols used by the demo/benchmark
    case minus, equals

    // Keypad
    case keypadPlus, keypadMinus

    // Function row
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    // Modifiers
    case leftShift, rightShift
    case leftControl, rightControl
    case leftOption, rightOption
    case leftCommand, rightCommand
}

/// The set of modifier keys held this frame, derived from the keyboard state.
public struct KeyModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}
