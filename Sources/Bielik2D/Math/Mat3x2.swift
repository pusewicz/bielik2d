import Foundation

/// A 2D affine transform stored column-major as:
///
///     | a c tx |
///     | b d ty |
///     | 0 0 1  |
public struct Mat3x2: Equatable, Sendable {
    public var a, b, c, d, tx, ty: Float

    public init(a: Float, b: Float, c: Float, d: Float, tx: Float, ty: Float) {
        self.a = a; self.b = b; self.c = c; self.d = d
        self.tx = tx; self.ty = ty
    }

    public static let identity = Mat3x2(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    public static func translation(x: Float, y: Float) -> Mat3x2 {
        Mat3x2(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y)
    }

    public static func rotation(angleRadians angle: Float) -> Mat3x2 {
        let c = cos(angle), s = sin(angle)
        return Mat3x2(a: c, b: s, c: -s, d: c, tx: 0, ty: 0)
    }

    public static func scale(_ sx: Float, _ sy: Float) -> Mat3x2 {
        Mat3x2(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0)
    }

    /// Composes two matrices so that `(lhs * rhs).transform(p)` == `lhs.transform(rhs.transform(p))`.
    public static func * (lhs: Mat3x2, rhs: Mat3x2) -> Mat3x2 {
        Mat3x2(
            a: lhs.a * rhs.a + lhs.c * rhs.b,
            b: lhs.b * rhs.a + lhs.d * rhs.b,
            c: lhs.a * rhs.c + lhs.c * rhs.d,
            d: lhs.b * rhs.c + lhs.d * rhs.d,
            tx: lhs.a * rhs.tx + lhs.c * rhs.ty + lhs.tx,
            ty: lhs.b * rhs.tx + lhs.d * rhs.ty + lhs.ty
        )
    }

    public func transform(_ p: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(a * p.x + c * p.y + tx, b * p.x + d * p.y + ty)
    }
}
