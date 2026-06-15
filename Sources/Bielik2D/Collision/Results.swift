#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Penetration data for an overlapping pair. `normal` points from the query shape
/// (`self`) toward the other shape; separate by moving `self` by `-normal * depth`.
public struct Manifold: Equatable, Sendable {
    public var normal: SIMD2<Float>
    public var depth: Float
    public var contact: SIMD2<Float>
    public init(normal: SIMD2<Float>, depth: Float, contact: SIMD2<Float>) {
        self.normal = normal
        self.depth = depth
        self.contact = contact
    }
}

/// A ray hit. `t` is the distance along the ray (`0...length`); `point = origin + direction * t`;
/// `normal` is the surface normal at the hit, facing back toward the ray origin.
public struct Raycast: Equatable, Sendable {
    public var t: Float
    public var point: SIMD2<Float>
    public var normal: SIMD2<Float>
    public init(t: Float, point: SIMD2<Float>, normal: SIMD2<Float>) {
        self.t = t
        self.point = point
        self.normal = normal
    }
}
