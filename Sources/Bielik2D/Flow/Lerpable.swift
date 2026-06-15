#if canImport(simd)
import simd
#endif

/// A value that can be linearly blended — the payload a `Tween` animates. `t` is
/// the eased fraction (0 → `a`, 1 → `b`), not clamped, so easings that overshoot
/// (back, elastic) can push past the endpoints.
public protocol Lerpable {
    static func lerp(_ a: Self, _ b: Self, _ t: Float) -> Self
}

extension Float: Lerpable {
    public static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }
}

extension Double: Lerpable {
    public static func lerp(_ a: Double, _ b: Double, _ t: Float) -> Double {
        a + (b - a) * Double(t)
    }
}

extension SIMD2: Lerpable where Scalar == Float {
    public static func lerp(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ t: Float) -> SIMD2<Float> {
        a + (b - a) * t
    }
}

extension Color: Lerpable {
    public static func lerp(_ a: Color, _ b: Color, _ t: Float) -> Color {
        Color(
            r: Float.lerp(a.r, b.r, t),
            g: Float.lerp(a.g, b.g, t),
            b: Float.lerp(a.b, b.b, t),
            a: Float.lerp(a.a, b.a, t)
        )
    }
}

extension Rect: Lerpable {
    public static func lerp(_ a: Rect, _ b: Rect, _ t: Float) -> Rect {
        Rect(
            x: Float.lerp(a.x, b.x, t),
            y: Float.lerp(a.y, b.y, t),
            width: Float.lerp(a.width, b.width, t),
            height: Float.lerp(a.height, b.height, t)
        )
    }
}
