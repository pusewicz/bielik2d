#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The Robert Penner easing set, the full slice CF exposes as `cf_ease_*`. Each
/// case maps a normalised time `t` in 0...1 onto an eased 0...1 value via
/// `value(at:)`. Pure and stateless — `Tween` reads the curve, the value type's
/// `Lerpable.lerp` does the actual blending.
public enum Easing: Sendable {
    case linear
    case inQuad, outQuad, inOutQuad
    case inCubic, outCubic, inOutCubic
    case inQuart, outQuart, inOutQuart
    case inQuint, outQuint, inOutQuint
    case inSine, outSine, inOutSine
    case inExpo, outExpo, inOutExpo
    case inCirc, outCirc, inOutCirc
    case inBack, outBack, inOutBack
    case inElastic, outElastic, inOutElastic
    case inBounce, outBounce, inOutBounce

    public func value(at t: Float) -> Float {
        switch self {
        case .linear: return t

        case .inQuad: return t * t
        case .outQuad: return 1 - (1 - t) * (1 - t)
        case .inOutQuad:
            return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2

        case .inCubic: return t * t * t
        case .outCubic: return 1 - pow(1 - t, 3)
        case .inOutCubic:
            return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2

        case .inQuart: return t * t * t * t
        case .outQuart: return 1 - pow(1 - t, 4)
        case .inOutQuart:
            return t < 0.5 ? 8 * t * t * t * t : 1 - pow(-2 * t + 2, 4) / 2

        case .inQuint: return t * t * t * t * t
        case .outQuint: return 1 - pow(1 - t, 5)
        case .inOutQuint:
            return t < 0.5 ? 16 * t * t * t * t * t : 1 - pow(-2 * t + 2, 5) / 2

        case .inSine: return 1 - cos(t * .pi / 2)
        case .outSine: return sin(t * .pi / 2)
        case .inOutSine: return -(cos(.pi * t) - 1) / 2

        case .inExpo: return t == 0 ? 0 : pow(2, 10 * t - 10)
        case .outExpo: return t == 1 ? 1 : 1 - pow(2, -10 * t)
        case .inOutExpo:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            return t < 0.5 ? pow(2, 20 * t - 10) / 2 : (2 - pow(2, -20 * t + 10)) / 2

        case .inCirc: return 1 - sqrt(1 - t * t)
        case .outCirc: return sqrt(1 - pow(t - 1, 2))
        case .inOutCirc:
            return t < 0.5
                ? (1 - sqrt(1 - pow(2 * t, 2))) / 2
                : (sqrt(1 - pow(-2 * t + 2, 2)) + 1) / 2

        case .inBack:
            let c1: Float = 1.70158, c3 = c1 + 1
            return c3 * t * t * t - c1 * t * t
        case .outBack:
            let c1: Float = 1.70158, c3 = c1 + 1
            return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
        case .inOutBack:
            let c1: Float = 1.70158, c2 = c1 * 1.525
            return t < 0.5
                ? (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
                : (pow(2 * t - 2, 2) * ((c2 + 1) * (2 * t - 2) + c2) + 2) / 2

        case .inElastic:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            let c4 = (2 * Float.pi) / 3
            return -pow(2, 10 * t - 10) * sin((10 * t - 10.75) * c4)
        case .outElastic:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            let c4 = (2 * Float.pi) / 3
            return pow(2, -10 * t) * sin((10 * t - 0.75) * c4) + 1
        case .inOutElastic:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            let c5 = (2 * Float.pi) / 4.5
            return t < 0.5
                ? -(pow(2, 20 * t - 10) * sin((20 * t - 11.125) * c5)) / 2
                : (pow(2, -20 * t + 10) * sin((20 * t - 11.125) * c5)) / 2 + 1

        case .inBounce: return 1 - Easing.outBounceValue(1 - t)
        case .outBounce: return Easing.outBounceValue(t)
        case .inOutBounce:
            return t < 0.5
                ? (1 - Easing.outBounceValue(1 - 2 * t)) / 2
                : (1 + Easing.outBounceValue(2 * t - 1)) / 2
        }
    }

    private static func outBounceValue(_ t: Float) -> Float {
        let n1: Float = 7.5625, d1: Float = 2.75
        var t = t
        if t < 1 / d1 {
            return n1 * t * t
        } else if t < 2 / d1 {
            t -= 1.5 / d1
            return n1 * t * t + 0.75
        } else if t < 2.5 / d1 {
            t -= 2.25 / d1
            return n1 * t * t + 0.9375
        } else {
            t -= 2.625 / d1
            return n1 * t * t + 0.984375
        }
    }
}
